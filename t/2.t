use Test;
use File::Spec;

BEGIN { plan tests => 5 };
use File::Locate;
ok(1); 

my $locatedb = File::Spec->catfile("t", "locatedb.test");
my @files = locate "*", $locatedb;
ok(!locate "mp3", $locatedb); 
ok(locate "html", $locatedb);
ok($files[0], '/usr/local/apache/');
ok($files[-1], '/usr/local/apache/htdocs/manual/mod/mod_a');

