use 5.00503;
use ExtUtils::MakeMaker;

my $LOCATE_DB;
my @data = `strings \`which locate\``;
if (! $?) {
    chomp @data;
    ($LOCATE_DB) = grep { m!^(/.*)! and 
                          $1 !~ /\.so\.(?:\d+)?$/ and 
                          -e $1 } @data;
}

$LOCATE_DB = do {
    print "Enter the location of your locate-db file [$LOCATE_DB]: ";
    chomp (my $input = <STDIN>);
    $input = $input ne '' ? $input : $LOCATE_DB;
};

WriteMakefile(
    'NAME'		    => 'File::Locate',
    'VERSION_FROM'	=> 'Locate.pm', 
    'PREREQ_PM'		=> {}, 
    ($] >= 5.005 ?    
      (ABSTRACT_FROM => 'Locate.pm', # retrieve abstract from module
       AUTHOR     => 'Tassilo von Parseval ' .
                      '<tassilo.von.parseval@rwth-aachen.de>') : ()),
    'LIBS'		=> [''], 
    'DEFINE'		=> "-DLOCATE_DB=\\\"$LOCATE_DB\\\"", 
    'INC'		=> '-I.', 
);

if  (eval {require ExtUtils::Constant; 1}) {
  # If you edit these definitions to change the constants used by this module,
  # you will need to use the generated const-c.inc and const-xs.inc
  # files to replace their "fallback" counterparts before distributing your
  # changes.
  my @names = (qw());
  ExtUtils::Constant::WriteConstants(
                                     NAME         => 'File::Locate',
                                     NAMES        => \@names,
                                     DEFAULT_TYPE => 'IV',
                                     C_FILE       => 'const-c.inc',
                                     XS_FILE      => 'const-xs.inc',
                                  );

}
else {
  use File::Copy;
  use File::Spec;
  foreach my $file ('const-c.inc', 'const-xs.inc') {
    my $fallback = File::Spec->catfile('fallback', $file);
    copy ($fallback, $file) or die "Can't copy $fallback to $file: $!";
  }
}
