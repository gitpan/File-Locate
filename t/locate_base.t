# Before `make install' is performed this script should be runable with
# `make test'. After `make install' it should work as `perl t/locate_base.t'

use strict;

######################### We start with some black magic to print on failure.

my $loaded;
BEGIN { $| = 1; print "1..21\n"; }
END {print "not ok 1\n" unless $loaded;}
use File::Locate;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use Cwd 'abs_path';
my $this_dir = abs_path('.');
my $test_include1 = $this_dir.'/t/test.h';
my $test_include2 = $this_dir.'/t/testdir1/test.h';
my $test_include3 = $this_dir.'/t/testdir2/Test.h';
my $test_include4 = $this_dir.'/t/testdir3/test.h';

-e $test_include4  and  unlink $test_include4;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 2
my $all = File::Locate->new(Path => ['.']);
print "not " unless defined($all);
print "ok 2\n";

# 3
my $found = join(',', $all->findInPath('MANIFEST'));
print "$found: not " unless $found eq $this_dir.'/MANIFEST';
print "ok 3\n";

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 4
my $includes = File::Locate->new(Path => ['.'],
				 Filter => '\.h$');
print "not " unless defined($includes);
print "ok 4\n";

# 5
$found = join(',', $includes->findInPath('MANIFEST'));
print "not " unless $found eq '';
print "ok 5\n";

# 6
$found = join(',', $includes->findInPath('Test.h'));
print "not " unless $found eq $test_include3;
print "ok 6\n";

# 7
$found = join(',', sort $includes->findInPath('test.h'));
print "not " unless $found eq $test_include1.','.$test_include2;
print "ok 7\n";

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 8
$includes = File::Locate->new(Path => ['.'],
			      Filter => '\.h$',
			      Normalize => sub{lc @_});
print "not " unless defined($includes);
print "ok 8\n";

# 9
$found = join(',', sort $includes->findInPath('test.h'));
print "not " unless
    $found eq $test_include1.','.$test_include2.','.$test_include3;
print "ok 9\n";

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 10
$includes = File::Locate->new(Path => ['t!'],
			      Filter => '\.h$');
print "not " unless defined($includes);
print "ok 10\n";

# 11
$found = join(',', $includes->findInPath('test.h'));
print "not " unless $found eq $test_include1;
print "ok 11\n";

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 12
$includes = File::Locate->new(Path => ['t!', 't'],
			      Filter => '\.h$');
print "not " unless defined($includes);
print "ok 12\n";

# 13
$found = join(',', $includes->findInPath('test.h'));
print "not "
    unless $found eq $test_include1.','.$test_include1.','.$test_include2;
print "ok 13\n";

# 14
$found = $includes->findFirstInPath('MANIFEST');
print "not " if defined $found;
print "ok 14\n";

# 15
$found = $includes->findFirstInPath('test.h');
print "not " unless $found eq $test_include1;
print "ok 15\n";

# 16
$found = $includes->findBestInPath('test.h',
				   sub{ length($_[0]) <=> length($_[1]) });
print "not " unless $found eq $test_include1;
print "ok 16\n";

# 17
$found = join(',', $includes->findMatch('^T'));
print "not " unless $found eq $test_include3;
print "ok 17\n";

# 18
$found = join(',', $includes->findMatch('^t'));
print "not "
    unless $found eq $test_include1.','.$test_include1.','.$test_include2;
print "ok 18\n";

# 19
$found = $includes->findFirstMatch('^t');
print "not " unless $found eq $test_include1;
print "ok 19\n";

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 20
$includes = File::Locate->new(Path => ['.']);
print "not " unless defined($includes);
print "ok 20\n";

# 21
$found = $includes->findBestMatch('\.h$',
				  sub{ length($_[0]) <=> length($_[1]) });
print "not " unless $found eq $test_include1;
print "ok 21\n";
