package File::Locate;

use 5.00503;
use strict;
use Carp;

require Exporter;
require DynaLoader;
use AutoLoader;
use vars qw($VERSION @ISA @EXPORT);
@ISA = qw(Exporter DynaLoader);

@EXPORT = qw(locate);

$VERSION = '0.01';

bootstrap File::Locate $VERSION;

1;
__END__

=head1 NAME

File::Locate - Search the locate-database from Perl

=head1 SYNOPSIS

    use File::Locate;

    print join "\n", locate "mp3", "/usr/var/locatedb";

    # or only test of something is in the database

    if (locate("mp3", "/usr/var/locatedb")) {
        print "yep...sort of mp3 there";
    }

=head1 ABSTRACT

    Search the locate-database from Perl

=head1 DESCRIPTION

File::Locate provides the C<locate()> function that scans the locate database for a given substring. It is almost a literal copy of C<locate(1L)> written in fast C (or rather: fast C copied).

=head1 FUNCTIONS

=over 4

=item * B<locate(I<$substring>, [ I<$database>, I<$coderef> ])>

Scans a locate-db file for a given I<$substring>. I<$substring> may contain globbing-characters. C<locate()> can take two additional parameters. A string is taken to be the I<$database> that should be searched:

    print locate "*.mp3", "/usr/var/locatedb";

If you omit I<$database>, C<locate()> first inspects the environment variable $LOCATE_PATH. If it is set, it uses this value. Otherwise it will use the default locate-db file that was compiled into the module. If this one is bogus, it will give up in which case you have to pass I<$database>.

I<$coderef> can be a reference to a subroutine that is called for each found entry with the entry being passed on to this subroutine. This will print each found entry as it appears (that is, no large list has to be built first):

    locate "*.mp3", "/usr/var/locatedb", sub { print $_[0], "\n" };

    # or
     
    sub dump {
        print $_[0], "\n";
    }
    locate "*.mp3", "/usr/var/locatedb", \&dump;

The order in which the second and third parameter appear is up to you. C<locate()> distinguishes on the type: a string is I<$database> and a CODE-reference always the I<$coderef>.

In list context it returns all entries found. In scalar context, it returns a true or a false value depending on whether any matching entry has been found. It is a short-cut performance-wise in that it immediately returns after anything has been found.

If I<$coderef> is provided, the function never returns anything regardless of context.

=back

=head2 EXPORT

C<locate()> is exported by default. If you don't want that, then pull in the module like that:

    use File::Locate ();

You have to call the function fully qualified in this case: C<File::Locate::locate()>.

=head1 SEE ALSO

The manpages of your locate(1L) program if available.

=head1 AUTHOR

Tassilo von Parseval <tassilo.von.parseval@rwth-aachen.de>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Tassilo von Parseval

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2, or (at your option) any later version.

=cut
