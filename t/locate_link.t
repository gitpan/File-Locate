# Before `make install' is performed this script should be runable with
# `make test'. After `make install' it should work as `perl t/locate_link.t'

use strict;

######################### We start with some black magic to print on failure.

my $loaded;
BEGIN { $| = 1; print "1..5\n"; }
END {print "not ok 1\n" unless $loaded;}
use File::Locate;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use Cwd 'abs_path';
my $this_dir = abs_path('.');
my $test_include1 = $this_dir.'/t/test.h';
my $test_include2 = $this_dir.'/t/testdir1/test.h';
my $test_include3 = $this_dir.'/t/testdir3/test.h';

-d 't/testdir3'  or  mkdir 't/testdir3', 0777  or  die;
-l $test_include3  or  symlink $test_include1, $test_include3  or  die;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 2
my $includes = File::Locate->new(Path => ['.'],
				 Filter => '\.h$',
				 NoSoftlinks => 1);
print "not " unless defined($includes);
print "ok 2\n";

# 3
my $found = join(',', sort $includes->findInPath('test.h'));
print "not " unless $found eq $test_include1.','.$test_include2;
print "ok 3\n";

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 4
$includes = File::Locate->new(Path => ['.'],
			      Filter => '\.h$');
print "not " unless defined($includes);
print "ok 4\n";

# 5
$found = join(',', sort $includes->findInPath('test.h'));
print "not " unless
    $found eq $test_include1.','.$test_include2.','.$test_include3;
print "ok 5\n";
