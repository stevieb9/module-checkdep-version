package Module::CheckDep::Version;

use 5.006;
use strict;
use warnings;
use version;

our $VERSION = '0.02';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(check_deps);

use MetaCPAN::Client;

my $mc = MetaCPAN::Client->new;

sub check_deps {
    my ($author, %args) = @_;

    die "check_deps() requires an \"AUTHOR\" param\n" if ! $author;

    my $module = $args{module};
    my $all = $args{all};
    my $custom_handler = $args{handler};
    my $return = $args{return};

    my $author_modules = _author_modules($author);

    my %needs_attention;

    for my $dist (keys %{ $author_modules }){
        next if $module && ($module ne $dist);

        $dist =~ s/::/-/g;

        my $release = $mc->release($dist);
        my $deps = $release->{data}{dependency};

        for my $dep (@$deps){
            my $dep_mod = $dep->{module};
            my $dep_ver = $dep->{version};

            next if $dep_mod eq 'perl';

            $dep_ver .= '.00' if $dep_ver !~ /\./;

            next if ! $all && ! $author_modules->{$dep_mod};

            my $cur_ver;

            if ($author_modules->{$dep_mod}){
                $cur_ver = $author_modules->{$dep_mod};
            }
            else {
                my $dep_mod_normalized = $dep_mod;
                $dep_mod_normalized =~ s/::/-/g;
                my $dep_dist;

                my $dist_found_ok = eval {
                    $dep_dist = $mc->release($dep_mod_normalized);
                    1;
                };

                next if ! $dist_found_ok;
                $cur_ver = $dep_dist->{data}{version};
            }

            $dep_ver = version->parse($dep_ver);
            $cur_ver = version->parse($cur_ver);

            if ($dep_ver != $cur_ver){
                $needs_attention{$dist}{$dep_mod}{cur_ver} = $cur_ver;
                $needs_attention{$dist}{$dep_mod}{dep_ver} = $dep_ver;
            }
        }
    }

    if (defined $custom_handler){
       $custom_handler->(\%needs_attention);
    }
    else {
        _display(\%needs_attention) if ! $return;
    }

    return \%needs_attention;
}
sub _author_modules {
    my ($author) = @_;

    my $query = {
        all => [
            { author => $author },
            { status => 'latest' },
        ],
    };

    my $limit = { 
        '_source' => [
            qw(distribution version)
        ] 
    };

    my $releases = $mc->release($query, $limit);

    my %rel_info;

    while (my $rel = $releases->next){
        my $dist = $rel->distribution;
        $dist =~ s/-/::/g;
        $rel_info{$dist} = $rel->version;
    }

    return \%rel_info;
}
sub _display {
    my $dists = shift;

    for my $dist (keys %$dists){
        print "$dist:\n";
        for (keys %{ $dists->{$dist} }){
            print "\t$_:\n" .
                  "\t\t$dists->{$dist}{$_}{dep_ver} -> " .
                  "$dists->{$dist}{$_}{cur_ver}\n";
        }
        print "\n";
    }
}
sub __placeholder {} # vim folds

1;
__END__

=head1 NAME

Module::CheckDep::Version - List prereqs that need a version bump for an
author's distributions

=head1 SYNOPSIS

    use Module::CheckDep::Version qw(check_deps);

    # list only the author's own prereqs that are behind

    check_deps('STEVEB');
    
    # list all prereqs that are behind by all authors

    check_deps('STEVEB', all => 1);

    # check only a single distribution

    check_deps('STEVEB', module => 'RPi::WiringPi');

    # return the data within a hash reference instead of printing

    check_deps('STEVEB', return => 1);

    # send in your own custom function to manage the data

    check_deps('STEVEB', handler => \&my_handler);

    sub my_handler {
        # this is the actual code from the default
        # handler

        my $dists = shift;
        
        for my $dist (keys %$dists){
            print "$dist:\n";
            for my $dep (keys %{ $dists->{$dist} }){
                print "\t$_:\n" .
                      "\t\t$dists->{$dist}{$dep}{dep_ver} -> " .
                      "$dists->{$dist}{$dep}{cur_ver}\n";
            }
            print "\n";
        }
    }

=head1 DESCRIPTION

This module retrieves all [http://cpan.org|CPAN] distributions for a single
author, extracts out all of the dependencies for each distribution, then lists
all dependencies that have updated versions so you're aware which prerequisite
distributions are behind in version than what is currently being required.

Can list only the prerequisites that are written by the same author, or
optionally all prerequisite distributions by all authors.

=head1 EXPORT_OK

We export only a single function upon request: C<check_deps()>.

=head1 FUNCTIONS

=head2 check_deps($author, [%args])

Fetches a list of a CPAN author's distributions using L<MetaCPAN::Client>,
extracts out the list of each distribution's prerequisite distributions,
compares the required version listed against the currently available version
and either returns or prints to the screen a list of each dependency that
requires a version bump.

Parameters:

    $author

Mandatory, String: A valid CPAN author's user name.

    module => 'Some::Module'

Optional, String. The name of a valid CPAN distribution by the author
specified. We'll only look up the results for this single distribution if this
param is sent in.

    all => 1

Optional, Bool. By default, we'll only list prerequisites by the same
C<$author>. Setting this to true will list prereq version bumps required for
all listed prerequisite distributions. Defaults to off/false.

    return => 1

Optional, Bool. By default we print results to C<STDOUT>. Set this to true to
have the data in hash reference form returned to you instead. Default is
off/false.

    handler => \&function

Optional, code reference. You can send in a reference to a function you create
to handle the data. See L</SYNOPSIS> for an example of the format of the
single hash reference we pass into your function.

=head1 AUTHOR

Steve Bertrand, C<< <steveb at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2017 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.
