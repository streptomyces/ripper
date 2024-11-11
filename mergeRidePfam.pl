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
my $outfile = qq(out.txt);
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

# {{{ ### POD ###

=head1 Name

mergeRidePfam.pl

=head1 Description

There are two tables in sqlite/ripp.sqlite3.

=over 2

=item 1. ripper $conf{prepeptab}

which is populated by ripper.pl and contains the detected precursor peptides.

=item 2. pfamscan $conf{pfamrestab}

which is populated by pfam_sqlite.pl and  contains the results of hmmscan for
the precursor peptides in the table ripper above.

=back

This script brings together information from both the tables
writes the output text and fasta files. These are usually
F<out.txt>, F<out.faa>, F<distant.txt> and, F<distant.faa>.

=cut

# }}} ###

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
open(my $dfh, ">", $distfile);
# }}}


my $dbfile=$conf{sqlite3fn};
my $handle=DBI->connect("DBI:SQLite:dbname=$dbfile", '', '');
open(my $faafh, ">", $outfaa);
my $seqout = Bio::SeqIO->new(-fh => $faafh, -format => 'fasta');
open(my $distfh, ">", $distfaa);
my $seqdist = Bio::SeqIO->new(-fh => $distfh, -format => 'fasta');

my @head = qw(Accession Organism PPSerial FastaID Sequence SameStrand
PP_TE_Distance Prodigalscore hname signif hdesc);
tablist(@head);
tablistH($dfh, @head);
my $qstr = qq/select * from $conf{prepeptab} order by species/;
my $stmt = $handle->prepare($qstr);
$stmt->execute();
while(my $hr = $stmt->fetchrow_hashref()) {
  my $fid = $hr->{fastaid};
  my $samestrand = "no";
  if($hr->{ppstrand} == $hr->{testrand}) {
    $samestrand = "yes";
  }
  my @rr;
  push(@rr, $hr->{acc}, $hr->{species}, $hr->{ppser}, $hr->{fastaid},
    $hr->{aaseq}, $samestrand, $hr->{pptedist},
    $hr->{score});

  # pfs() queries the $conf{pfamrestab} (pfamscan) table and returns
  # a hashref.
  my $pr = pfs($fid);
  if(ref($pr)) {
    push(@rr, $pr->{hname}, $pr->{signif}, $pr->{hdesc});
  }
  else {
    push(@rr, "none", "none", "none");
  }


  if($fid =~ m/_9\d{3,}$/) {
    if($rr[-3] ne "none") {
      tablistH($dfh, @rr);
    }
  }
  else {
    tablist(@rr);
  }


  my $outobj = Bio::Seq->new(-seq => $hr->{aaseq});
  $outobj->display_id("RiPP|" . $fid);
  if($fid =~ m/_9\d{3,}$/) {
    if($rr[-3] ne "none") {
      $seqdist->write_seq($outobj);
    }
  }
  else {
    $seqout->write_seq($outobj);
  }
}


exit;

# Multiple END blocks run in reverse order of definition.
END {
close($faafh);
close($distfh);
close($dfh);
close($ofh);
close(STDERR);
close(ERRH);
# $handle->disconnect();
}


# {{{ sub pfs
sub pfs {
  my $fid = shift(@_);
  my $cntstr = qq/select count(*) from $conf{pfamrestab} where qname = '$fid'/;
  my ($count) = $handle->selectrow_array($cntstr);
  if($count) {
    my $qstr = qq/select * from $conf{pfamrestab} where qname = '$fid'/;
    my $stmt = $handle->prepare($qstr);
    $stmt->execute();
    my $hr = $stmt->fetchrow_hashref();
    return($hr);
  }
  else { return 0; }
}
# }}}

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

