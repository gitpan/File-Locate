use Test;
use File::Spec;

BEGIN { plan tests => 175 };
use File::Locate;

ok(1); 

my $locatedb = File::Spec->catfile("t", "locatedb.test");
my @files = locate "*", $locatedb;
ok (@files, 173);
locate "*", $locatedb, sub { ok(shift @files, $_[0]) };
