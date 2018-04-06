#!/usr/bin/perl
use 5.14.0;
use utf8;
use Carp;
use lib qw(/home/sco /home/sco/perllib);
use File::Basename;
use Sco::Common qw(tablist linelist tablistE linelistE tabhash tabhashE tabvals
    tablistV tablistVE linelistV linelistVE tablistH linelistH
    tablistER tablistVER linelistER linelistVER tabhashER tabhashVER csvsplit);
use File::Spec;
use DBI;
use Sco::Hmmer;
use File::Copy;


# {{{ Getopt::Long
use Getopt::Long;
my $outdir;
my $indir;
my $fofn;
my $outex; # extension for the output filename when it is derived on infilename.
my $conffile = qq(local.conf);
my $pfamtable = qq(/home/sco/blast_databases/pfam/pfam.table);
my $restab = qq(pfamscan);
my $errfile;
my $runfile;
my $ridetable = qq(ride);
my $outfile;
my $testCnt = 0;
our $verbose;
my $skip = 0;
my $help;
GetOptions (
"outfile:s" => \$outfile,
"outdir:s" => \$outdir,
"indir:s" => \$indir,
"ridetable:s" => \$ridetable,
"restable:s" => \$restab,
"fofn:s" => \$fofn,
"extension:s" => \$outex,
"conffile:s" => \$conffile,
"errfile:s" => \$errfile,
"runfile:s" => \$runfile,
"testcnt:i" => \$testCnt,
"skip:i" => \$skip,
"verbose" => \$verbose,
"help" => \$help
);
# }}}

# {{{ POD Example

=head1 Name

Change me.

=head2 Example

 perl code/pfam.pl

Provided you are in the right directory, no arguments are needed.
relies on a couple of hardcoded defaults.

 my $pfamtable = qq(/home/sco/blast_databases/pfam/pfam.table);
 my $restab = qq(pfamscan); # The table to which output is written.

# }}}

# {{{ POD Options and blurb

=head2 Options

=over 2

=item -help

Displays help and exits. All other arguments are ignored.

=item -outfile

If specified, output is written to this file. Otherwise it
is written to STDOUT. This is affected by the -outdir option
described below.

=item -outdir

The directory in which output files will be placed. If this is
specified without -outfile then the output filenames are derived
from input filenames and placed in this directory.

If this directory does not exist then an attempt is made to make
it. Failure to make this directory is a fatal error (croak is called).

If -outdir is specified with -outfile then the outfile is placed
in this directory.

=item -extension

By default this ($outex) is undefined. This is the extension to use
when output filenames are derived from input filenames. 

=back

=head2 Blurb

Uses F<Sco::Common> for a variety of printing functions.

If neither -outfile nor -outdir are specified then the output
is to STDOUT.

=cut


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
  linelistE("$keyCnt keys placed in conf.");
}
elsif($conffile ne "local.conf") {
linelistE("Specified configuration file $conffile not found.");
}
# }}}

# {{{ Outdir and outfile business.
my $ofh;
my $idofn = 0;    # Flag for input filename derived output filenames. 
if($outfile) {
  my $ofn;
  if($outdir) {
    unless(-d $outdir) {
      unless(mkdir($outdir)) {
        croak("Failed to make $outdir. Exiting.");
      }
    }
    $ofn = File::Spec->catfile($outdir, $outfile);
  }
  else {
    $ofn = $outfile;
  }
  open($ofh, ">", $ofn);
}
elsif($outdir) {
linelistE("Output filenames will be derived from input");
linelistE("filenames and placed in $outdir");
    unless(-d $outdir) {
      unless(mkdir($outdir)) {
        croak("Failed to make $outdir. Exiting.");
      }
    }
$idofn = 1;
}
else {
  open($ofh, ">&STDOUT");
}
select($ofh);
# }}}

my %pfl = pflens();
my $hmmer = Sco::Hmmer->new();

my @infiles = @ARGV;

my $infile = shift(@infiles);
open(my $ifh, "<", $infile);
if($skip) {
  for(1..$skip) {
    my $discard = readline($ifh);
  }
}
my $lineCnt = 0;
LINE: while(my $line = readline($ifh)) {
  my $outflag = 0;
  chomp($line);
  my @ll = split(/\t/, $line);
  if($ll[0] =~ m/^#/) {
    tablist(@ll);
    next;
  }
  my $id = $ll[3];
  my $aaseq = $ll[4];

  my $hmmoutfn = $hmmer->scan(aaseq => $aaseq, name => $id);
  my @hr = $hmmer->hspHashes($hmmoutfn);
  for my $hr (@hr) {
    if(ref($hr) and $hr->{signif} <= 0.05) {
      my $acc = $hr->{hname};
      my $bacc = $acc; $bacc =~ s/\.\d+$//;
      my $hcov = sprintf("%.3f", $hr->{alnlen}/$pfl{$bacc});

      push(@ll, $bacc,  sprintf("%.3e", $hr->{signif}), $hr->{hdesc});
      tablist(@ll);
      $outflag = 1;
      next(LINE);
      unlink($hmmoutfn);
    }
  }
  if($outflag == 0) {
    push(@ll, "None", "None", "None");
    tablist(@ll);
  }
  if(-e $hmmoutfn) {
    unlink($hmmoutfn);
  }
  $lineCnt += 1;
  if($testCnt and $lineCnt >= $testCnt) {
    last;
  }
}

exit;

# Multiple END blocks run in reverse order of definition.
END {
close($ofh);
close(STDERR);
close(ERRH);
$ifh->disconnect();
}

sub pflens {
  open(PFT, "<", $pfamtable);
  my %rethash;
  while(<PFT>) {
    my $line = $_;
    chomp($line);
    my @ll = split(/\t/, $line);
    $rethash{$ll[1]} = $ll[2];
  }
  close(PFT);
  return(%rethash);
}


__END__


create table pfamscan (
qname text,
qlen integer,
hname text,
hlen integer,
qcov float,
hcov float,
fracid float,
signif float,
hdesc text
-- unique(qname, hname)
);
