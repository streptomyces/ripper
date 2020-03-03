#!/usr/bin/perl
use 5.14.0;
use utf8;
use Carp;
use File::Basename;
use File::Spec;
use DBI;
use Bio::SeqIO;
use Bio::Seq;

# {{{ Getopt::Long
use Getopt::Long;
my $conffile = qq(local.conf);
my $errfile;
my $runfile;
my $outfile;
my $distfile = qq(distant.txt);
my $outfaa = qq(out.faa);
my $distfaa = qq(distant.faa);
my $testCnt = 0;
our $verbose;
my $skip = 0;
my $help;
GetOptions (
"outfile=s" => \$outfile,
"faafile=s" => \$outfaa,
"distfaa=s" => \$distfaa,
"distfile=s" => \$distfile,
"conffile:s" => \$conffile,
"errfile:s" => \$errfile,
"runfile:s" => \$runfile,
"testcnt:i" => \$testCnt,
"skip:i" => \$skip,
"verbose" => \$verbose,
"help" => \$help
);
# }}}

if($help) {
exec("perldoc $0");
exit;
}

# {{{ open the errfile
if($errfile) {
open(ERRH, ">", $errfile);
print(ERRH "$0", "\n");
close(STDERR);
open(STDERR, ">&ERRH"); 
}
# }}}

# {{{ Populate %conf if a configuration file 
my %conf;
if(-s $conffile ) {
  open(my $cnfh, "<", $conffile);
  my $keyCnt = 0;
  while(my $line = readline($cnfh)) {
    chomp($line);
    if($line=~m/^\s*\#/ or $line=~m/^\s*$/) {next;}
    my @ll=split(/\s+/, $line, 2);
    $conf{$ll[0]} = $ll[1];
    $keyCnt += 1;
  }
  close($cnfh);
#  linelistE("$keyCnt keys placed in conf.");
}
elsif($conffile ne "local.conf") {
linelistE("Specified configuration file $conffile not found.");
}
# }}}

# {{{ Outdir and outfile business.
my $ofh;
if($outfile) {
  open($ofh, ">", $outfile);
}
else {
  open($ofh, ">&STDOUT");
}
select($ofh);
# }}}

my @infiles = @ARGV;

my $infile = shift(@ARGV);
open(my $ifh, "<", $infile);
my $head = readline($ifh);
chomp($head);
# linelist($head);
my @head = split(/\t/, $head);
($head[0], $head[3]) = ($head[3], $head[0]);
$head[0] =~ s/^fasta//i;
push(@head, "Genus");
tablist(@head);
while(my $line = readline($ifh)) {
chomp($line);
my @ll = split(/\t/, $line);
($ll[0], $ll[3]) = ($ll[3], $ll[0]);
my $org = $ll[1];
my @org = split(/\b/, $org, 2);
my $genus = $org[0];
push(@ll, $genus);
tablist(@ll);
}

close($ifh);



exit;

# Multiple END blocks run in reverse order of definition.
END {
close($ofh);
close(STDERR);
close(ERRH);
# $handle->disconnect();
}

# {{{ subroutines tablist, linelist, tabhash and their *E versions.
# The E versions are for printing to STDERR.
#

sub tablistH {
  my @in = @_;
  my $fh = shift(@in);
  print($fh join("\t", @in), "\n");
}

sub tablist {
  my @in = @_;
  print(join("\t", @in), "\n");
}

sub tablistE {
  my @in = @_;
  print(STDERR join("\t", @in), "\n");
}

sub linelist {
  my @in = @_;
  print(join("\n", @in), "\n");
}

sub linelistE {
  my @in = @_;
  print(STDERR join("\n", @in), "\n");
}

# }}}

