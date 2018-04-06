#!/usr/bin/perl
use 5.14.0;
use utf8;
use Carp;
use lib qw(/Users/nouser/perllib);
use File::Basename;
use Sco::Common qw(tablist tablistE linelistE);
use File::Spec;
use DBI;

# {{{ Getopt::Long
use Getopt::Long;
my $conffile = qq(local.conf);
my $errfile;
my $runfile;
my $outfile;
my $testCnt = 0;
our $verbose;
my $skip = 0;
my $help;
GetOptions (
"outfile:s" => \$outfile,
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

 perl code/mergeRidePfam.pl -outfile rodeo_pfam.csv
 perl code/mergeRidePfam.pl -outfile rodeo_pfam_${dpf}.csv

No input files are needed. Queries tables F<ride> and F<pfamscan>
in the database F<andy>. The two tables are linked by
ride.fastaid and pfamscan.qname.

=cut

# }}}

# {{{ POD blurb

=head2 Blurb

Some kind of description here.

=cut

# }}}

# {{{ POD Options

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

=back

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
if($outfile) {
  open($ofh, ">", $outfile);
}
else {
  open($ofh, ">&STDOUT");
}
select($ofh);
# }}}


my $dbfile=$conf{sqlite3fn};
my $handle=DBI->connect("DBI:SQLite:dbname=$dbfile", '', '');


my @head = qw(Accession Organism PPSerial FastaID Sequence SameStrand
PP_TE_Distance Prodigalscore hname signif hdesc);
tablist(@head);
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

my $pr = pfs($fid);
if(ref($pr)) {
push(@rr, $pr->{hname}, $pr->{signif}, $pr->{hdesc});
}
else {
push(@rr, "none", "none", "none");
}
tablist(@rr);
}





exit;

# Multiple END blocks run in reverse order of definition.
END {
close($ofh);
close(STDERR);
close(ERRH);
# $handle->disconnect();
}


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
