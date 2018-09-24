#!/usr/bin/perl
use 5.14.0;
use utf8;
use Carp;
# use lib qw(/Users/nouser/perllib);
use File::Basename;
use File::Temp qw(tempfile tempdir);
use File::Spec;
use File::Copy;
# use Sco::Common qw(tablist tablistE linelistE);
use Bio::SeqIO;
use Bio::Seq;
use Bio::SeqFeature::Generic;
use DBI;
use Digest::SHA qw(sha1_hex);

use XML::Simple;
use LWP::Simple;
use Net::FTP;


# {{{ Getopt::Long
use Getopt::Long;
my $maxDistFromTE = 8000; # From precursor peptide to the tailoring enzyme.
my $outdir = qq(ripout);
my $indir;
my $fofn;
my $outex; # extension for the output filename when it is derived on infilename.
my $conffile = qq(local.conf);
my $colorThreshScore = 20;
my $ppFeatAddLimit = 20;
my $errfile;
my $prodigalScoreThresh = 7.5;
my $prodigalshortbin = qq(prodigal-short);
my $flankLen = 17500;
my $allowedInGene = 20;
my $minPPlen = 20; # Minimum precursor peptide length.
my $maxPPlen = 120; # Maximum precursor peptide length.
my $sameStrandReward = 5;
my $fastaOutputLimit = 3;
my $runfile;
my $outfile;
my $testCnt = 0;
our $verbose;
my $skip = 0;
my $help;
GetOptions (
"outfile:s" => \$outfile,
"outdir:s" => \$outdir,
"indir:s" => \$indir,
"fofn:s" => \$fofn,
"extension:s" => \$outex,
"conffile:s" => \$conffile,
"errfile:s" => \$errfile,
"runfile:s" => \$runfile,
"testcnt:i" => \$testCnt,
"skip:i" => \$skip,
"allowedingene:i" => \$allowedInGene,
"verbose" => \$verbose,
"help" => \$help
);
# }}}

# {{{ POD Example

=head1 Name

ripper.pl

=head2 Example

 perl code/ripper.pl -outdir ripout

 export rwb=rodeowork
 export listfn=TfuA_Actino_Accessions_080217.txt
 export outdir=output_21_07_2017
 fp-rip () {
   listbn=$(basenameNoex.pl $listfn);
   ofn=${listbn}.csv
     for iline in $(tail -n 1 $listfn); do
       line=$(basenameNoex.pl $iline);
       incsv=$rwb"/"${line}"/outarch.csv"
       echo perl code/ripper.pl -outdir $outdir -- $incsv
     done
 }

 fp-rip | parallel

Below is a standalone test command.

 perl code/ripper.pl -outdir ripout -- rodout/main_co_occur.csv

=cut

# }}}

# {{{ POD Options and blurb

=head2 Blurb

RODEO outputs a file named *arch.csv.

 499497121,50841496,488474605,,rev,927480,927977,PF02481,1.3e-14,,,,,
 499497121,50841496,488487448,,fwd,928266,929873,PF13175,1e-23,PF13304,1.4e-20,,,
 499497121,50841496,488487449,,fwd,929874,931562,PF00580,6.3e-26,PF13245,7.7e-17,,,
 <more line here>
 499497121,50841496,695294193,,fwd,950727,951236,PF00155,0.00022,PF01803,0.21,,,
 499497121,50841496,488474066,,fwd,951486,951725,PF01610,9e-12,,,,,
 499497121,50841496,488487891,,rev,952257,954161,PF13304,6.3e-15,PF00005,2.6e-11,,,

The index 1 column is a genbank gid which we use to fetch the genbank file.

1. From the fetched genbank file we extract the region spanned by the output in
*arch.csv (column index 5 and 6 of the first and last lines).

2. Prodigal is run on the nucleotide sequence obtained in step 1.

3. Peptides less than 30 amino acids or more than 120 amino acids are discarded.

4. Results of Prodigal are sorted by the total score reported by Prodigal

5. The top 20 peptides (or as many as have a total prodigal score of more then 0)
are kept.

6. Peptides kept in step 5 are added to the annotation in the genbank file as
CDSs.

7. The top 3 peptides are coloured reddish brown, the next 9 are coloured green
and the remainder are coloured yellowish brown. For these features, the note
tag contains the output from Prodigal for each particular peptide.

=head2 Input files

These are F<outarch.csv> files resulting from running RODEO. This is a messy
operation and it is best done using F<rodeo.bash>. F<outarch.csv> files are
usually in a path similar to F<rodeowork/E<lt>accessionE<gt>/outarch.csv>.

=head2 Output

Output is gbk and faa files named as <accession>.gbk and <accession>.faa
written to $outdir. Some details about top scoring PPs are also written to the
table $conf{prepeptab} in the database I<andy>. This can be used to get a tsv
or csv file of results for viewing in a spreadsheet.

=head2 Subs, data structures and comments.

=cut


# }}}

if($help) {
exec("perldoc $0");
exit;
}

# {{{ Some file globals
my $template='rippXXXXX';
my $tempdir = qw(/tmp);
my $esearchURL='http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?';
my $efetchURL='http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?';
my $esummaryURL='http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?';
my $ftp=Net::FTP->new(Host => "ftp.ncbi.nih.gov", Passive => 1);
# }}}


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
if(exists($conf{minPPlen})) { $minPPlen = $conf{minPPlen}; }
if(exists($conf{maxPPlen})) { $maxPPlen = $conf{maxPPlen}; }
if(exists($conf{maxDistFromTE})) { $maxDistFromTE = $conf{maxDistFromTE}; }
if(exists($conf{prodigalScoreThresh})) {
  $prodigalScoreThresh = $conf{prodigalScoreThresh};
}
if(exists($conf{fastaOutputLimit})) {
  $fastaOutputLimit = $conf{fastaOutputLimit};
}
if(exists($conf{sameStrandReward})) {
  $sameStrandReward = $conf{sameStrandReward};
}
if(exists($conf{flankLen})) {
  $flankLen = $conf{flankLen};
}
if(exists($conf{"prodigalshortbin"})) {
  $prodigalshortbin = $conf{prodigalshortbin};
}


# }}}


# {{{ gbkcache and sqlite initialisation
my $gbkcache = qq(gbkcache);
if(exists($conf{gbkcache})) { $gbkcache = $conf{gbkcache}; }


my $dbfile=$conf{sqlite3fn};
my $handle=DBI->connect("DBI:SQLite:dbname=$dbfile", '', '');

my $create_table_str = <<"CTS";
create table if not exists $conf{prepeptab} (
acc       text,
species   text,
ppser     integer,
fastaid   text,
aaseq     text,
ppstrand  integer,
testrand  integer,
pptedist  integer,
score     float,
unique(acc, ppser)
);
CTS
# $handle->do("drop table if exists $conf{prepeptab}");
$handle->do($create_table_str);
# }}}

# {{{ populate @infiles
my @infiles;
if(-e $fofn and -s $fofn) {
open(FH, "<", $fofn);
while(my $line = readline(FH)) {
chomp($line);
if($line=~m/^\s*\#/ or $line=~m/^\s*$/) {next;}
my $fn;
if($indir) {
$fn = File::Spec->catfile($indir, $line);
}
else {
$fn = $line;
}

push(@infiles, $fn);
}
close(FH);
}
else {
@infiles = @ARGV;
}

# }}}

# {{{ out file handle
my $ofh;
if($outfile) {
  unless(-d $outdir) {
    mkdir($outdir) or croak("Failed to make $outdir\n");
  }
  my $outpath = File::Spec->catfile($outdir, $outfile);
  open($ofh, ">", $outfile);
}
else {
  open($ofh, ">&STDOUT");
}
#}}}

# Cycle through all the infiles.
for my $infile (@infiles) {
my ($noex, $dir, $ext)= fileparse($infile, qr/\.[^.]*/);
my $bn = $noex . $ext;

=head3 Genbank and fasta file names.

These are derived from $taildir which is the immediate
directory containing the input file (outarch.csv). The
way this has been designed, $taildir is a protein
accession number.

=cut

my @temp = split(/\//, $dir);
my $taildir = pop(@temp);
if($outdir) {
  unless(-d $outdir) {
    if(mkdir($outdir)) {
    }
    else {
      croak("Failed to make $outdir");
    }
  }
}


=pod

Make a genbank filename and a fasta filename. The are the
filenames output is written to.

=cut

my ($ofn, $fastafn);
if($outdir) {
$ofn = File::Spec->catfile($outdir, $taildir . ".gbk"); 
$fastafn = File::Spec->catfile($outdir, $taildir . ".faa"); 
}
else {
$ofn = $taildir . ".gbk"; 
$fastafn = $taildir . ".faa"; 
}

linelistE("Genbank output is $ofn. Fasta output is $fastafn");


open(my $ifh, "<$infile") or croak("Could not open $infile"); # main_co_occur.csv
$skip = 1; # There is a header.
if($skip) {
for (1..$skip) { my $discard = readline($ifh); }
}
my @coords;
my $gbkgi; # Column index 2 of outarch.csv. Value is the same in all rows.
my $teProtAcc; # We remove ".1", ".2" from the end of this one.
my $teProtId; # This is the $teProtAcc without the removal mentioned above.
my $teNdx; # Index for the tailoring enzyme.
my $lineCnt = 0;

# read lines in the input file to assign to the variables above
while(my $line = readline($ifh)) {
chomp($line);
if($line=~m/^\s*\#/ or $line=~m/^\s*$/
  or $line=~m/^query/ ) {next;}
#Query,Genus/Species,Nucleotide_acc,Protein_acc,start,end,dir,PfamID1,Name1,Description1,E-value1,PfamID2,Name2,D
#POF95626.1,Pseudomonas putida,MINE01000015.1,POF95618.1,459205,459898,+,PF12146,Hydrolase_4,"Serine aminopeptida

my @ll=split(",", $line);
$teProtAcc = $ll[0];
$teProtId = $teProtAcc; # In case we need to look in the genbank file.
$teProtAcc =~ s/\.[^.]*$//;
$gbkgi = $ll[2];
my $strand = $ll[6] =~ m/^-/ ? -1 : 1;

my $start = $ll[4];
my $end = $ll[5];

# For strand -1 the order in the file is end, start
# Hence the if block below.
if($strand == -1) {
$start = $ll[5];
$end = $ll[4];
}
push(@coords, [$start, $end, $strand]);

=head3 Getting the index for the tailoring enzyme used in the RODEO search.

This relies on the fact that in outarch.csv, column 0 and
column 3 will be the same for this protein.

=cut

if($ll[0] eq $ll[3]) {
$teNdx = $lineCnt;
# tablistE(@ll);
linelistE("TE Line: $line");
tablistE("TE Line:", $start, $end, $strand);
}
$lineCnt += 1;
}
close($ifh);
unless($lineCnt) {
  croak("Only a header line in $infile.\nStopping"); # main_co_occur.csv
}

# TEcoordsByProtId (gbkfile => filename, protid => proteinid);
unless(defined($teNdx)) {
  linelistE("\$teNdx is undefined. Looking into the downloaded genbank file.\n");
  my($gbkfh, $gbkfn)=tempfile($template, DIR => $tempdir, SUFFIX => '.gbk');
  my $gbkstored = File::Spec->catfile($gbkcache, ($gbkgi . ".gbk"));
  if(-e $gbkstored) {
    copy($gbkstored, $gbkfn);
    linelistE("$gbkstored copied to $gbkfn");
  }
  else {
    fetchGbk(uid => $gbkgi, outfile => $gbkfn);
    if(-d $gbkcache) {
      copy($gbkfn, $gbkstored);
    }
  }
  my $cr = TEcoordsByProtId(gbkfile => $gbkfn, protid => $teProtId);
  if(ref($cr)) {
    push(@coords, $cr);
    $teNdx = $#coords;
    tablistE("Found TE ($teProtId) in $gbkstored: ", @{$cr}, $teNdx);
  }
  else {
    linelistE("No $teProtId found in $gbkstored. Stopping.");
    unlink($gbkfn);
    exit();
  }
}

=head3 Coordinates to be extracted from the Genbank file.

These are $flankLen left and right of the middle of the TE.

=cut

tablistE("TE index is $teNdx");
my $cr = $coords[$teNdx]; # coords ref.
my $start = $cr->[0];
my $end = $cr->[1];
my $teStart = $cr->[0]; # The tailoring enzyme start.
my $teEnd = $cr->[1]; # The tailoring enzyme end.
my $teStrand = $cr->[2]; # The tailoring enzyme strand as 1 or -1.

my $midpos = int(($start + $end)/2);
my $minpos = $midpos - ($flankLen - 1);
my $maxpos = $minpos + ($flankLen * 2 - 1);

my($gbkfh, $gbkfn)=tempfile($template, DIR => $tempdir, SUFFIX => '.gbk');
close($gbkfh);

my $gbkstored = File::Spec->catfile($gbkcache, ($gbkgi . ".gbk"));

if(-e $gbkstored) {
  copy($gbkstored, $gbkfn);
  linelistE("$gbkstored copied to $gbkfn");
}
else {
  fetchGbk(uid => $gbkgi, outfile => $gbkfn);
  if(-d $gbkcache) {
    copy($gbkfn, $gbkstored);
  }
}

tablistE($minpos, $maxpos);

my($subfh, $subfn)=tempfile($template, DIR => $tempdir, SUFFIX => '.fna');
my($tefh, $tefn)=tempfile($template, DIR => $tempdir, SUFFIX => '.fna');
my $teout=Bio::SeqIO->new(-fh => $tefh, -format => 'fasta');

my $seqio=Bio::SeqIO->new(-file => $gbkfn);
my $seqout=Bio::SeqIO->new(-fh => $subfh, -format => 'fasta');
my $seqobj=$seqio->next_seq();
my $species = $seqobj->species();
my @classification = $species->classification();
my $seqlen = $seqobj->length();

# Below, adjustments to keep $minpos and $maxpos
# sensible in terms of the downloaded genbank file.
if($seqlen <= $flankLen * 2) {
  $minpos = 1; $maxpos = $seqlen;
}
elsif($minpos < 1) {
  $minpos = 1;
  $maxpos = $minpos + ($flankLen * 2 - 1);
}
elsif($maxpos > $seqlen) {
  $maxpos = $seqlen;
  $minpos = $maxpos - ($flankLen * 2 - 1);
}

# The output sequence object.
my $subseq = $seqobj->subseq($minpos, $maxpos);
my $teNtseq = $seqobj->subseq($teStart, $teEnd);

=head2 Locate TE on the sub genbank file

We need the nt sequence of the TE to locate it on the
sub gbk. Function I<locateTE()> is called for this.
It, in turn, uses I<blastn>.

=cut

my $teobj = Bio::Seq->new(-seq => $teNtseq);
$teobj->display_id("teNt");
$teobj->description("Tailoring enzyme");
$teout->write_seq($teobj);
close($tefh);

my $subobj = Bio::Seq->new(-seq => $subseq);
# $subobj->display_id("subseq");
$subobj->description("$gbkgi $minpos $maxpos");
$seqout->write_seq($subobj);
close($subfh);

# The sub called below uses blastn to locate the TE on the sub-genbank.
my ($teSubStart, $teSubEnd) = locateTE(tefn => $tefn, subfn => $subfn);

  tablistE($gbkfn, $minpos, $maxpos);

my $subgbk = subgenbank(infile => $gbkfn, start => $minpos, end => $maxpos);
my $subgbkFT = subgenbank(infile => $gbkfn, start => $minpos, end => $maxpos);
my @subft = $subgbk->remove_SeqFeatures();

=head3 @recoord

List of listrefs. [start, end, strand] of each CDS feature in @subft.

Coordinates stored in @recoord are used for checking the overlap
of prodigal findings with existing annotated features. Features which
have sizes in the range of the size of precursor peptides are not pushed
into @recoord. This is to allow for the situation where the precursor
peptide might be already annotated in the genbank file.

=cut

my @recoord; # start, end and strand of sequence features.
for my $subft (@subft) {
  if($subft->primary_tag() eq 'CDS') {
    my $st = $subft->start();
    my $en = $subft->end();
    my $str = $subft->strand();
    my $protlen = ((($en - $st) + 1) - 3) / 3;
    unless ($protlen >= $minPPlen and $protlen <= $maxPPlen) {
      push(@recoord, [$st, $en, $str]);
    }
    # if($st == $teSubStart and $en == $teSubEnd)
    if(abs($st - $teSubStart) <= 2 and
      abs($en - $teSubEnd) <= 2) {
      $subft->add_tag_value("color", "0 255 0");
    }
  }
  if($subft->primary_tag() ne 'gene') {
    $subgbk->add_SeqFeature($subft);
  }
}

=head3 Prodigal

Run Prodigal and parse the output file to populate @prdl
with listrefs for each line in the prodigal output.

Columns in the output of Prodigal are

 0. Start position
 1. End position
 2. Strand as + or -
 3. Prodigal score

There are more columns but these are the ones we are
concerned with.

=cut

# Below, run prodigal on the subsequence fasta file.
my($prdfh, $prdfn)=tempfile($template, DIR => $tempdir, SUFFIX => '.prodigal');
close($prdfh);
my $xstr = qq($prodigalshortbin -p meta -f gff -i $subfn -s $prdfn);
my $discard = qx($xstr); # Only interested in the output in file $prdfn.

# Read prodigal output and populate @prdl.
open(PRD, "<", $prdfn);
my @prdl;
while(my $line = readline(PRD)) {
if($line=~m/^\s*\#/ or $line=~m/^\s*$/ or $line !~ m/^\d/) {next;}
chomp($line);
my @ll=split(/\t/, $line);
push(@prdl, [@ll]);
}
close(PRD);

# Same strand reward
# For loop below applies the same strand reward to all
# prodigal output records.

for my $lr (@prdl) {
  my $prdStrand = $lr->[2] eq '+' ? 1 : -1;
  if($prdStrand == $teStrand) {
    $lr->[3] += $sameStrandReward;
  }
  $lr->[2] = $prdStrand;
  my $shadig = sha1_hex(join("_", $lr->[0], $lr->[1], $lr->[2]));
  push(@{$lr}, $shadig);
}


# Then we sort the prodigal output records by score.
# This gives us @sprdl.

my @sprdl = sort {$b->[3] <=> $a->[3]} @prdl;


# Loop through the sorted (by score) prodigal output
# Columns in the output of Prodigal are
# 
#  0. Start position
#  1. End position
#  2. Strand as + or -
#  3. Prodigal score

my $prdlCnt = 0;
my $ppFastaOutputCnt = 1; # Init to one because of later sql insertion.
my $allFastaOutputCnt = 9001; # Init to one because of later sql insertion.
my @terpos; # To hold the positions of the last nucleotide of genes.
my $seqout1;

SPRDL: for my $lr (@sprdl) { # @sprdl: sorted (by score) prodigal results.
my @ll = @{$lr}; 
my ($start, $end, $strand) = @ll[0,1,2];
my $score = $ll[3];
my $peplen = (($end - $start) + 1) / 3; $peplen -= 1;
# my $strand = $temp eq '+' ? 1 : -1;
splice(@ll, 2, 1, $strand);
my $terpos;
if($strand == 1) { $terpos = $end; }
elsif($strand == -1) { $terpos = $start; }

# Proceed only for a range of peptide lengths. Otherwise look at
# the next prodigal record.
# 
# $ll[3] is the total prodigal score.
unless ($peplen >= $minPPlen and $peplen <= $maxPPlen) { next SPRDL; }

# If an end position ($terpos) has been seen before, skip it.
if(grep {$_ == $terpos} @terpos) { next SPRDL; }

else {
# Test for overlap with an annotated gene.
# Basically we check for overlap with coordinates in @recoord. 
my $inGene = 0; #flag
OUTER: for my $pos ($start, $end) {
  for my $cr (@recoord) {
    if($pos >= ($cr->[0] + $allowedInGene)
      and $pos <= ($cr->[1] - $allowedInGene)) {
      $inGene = 1; last OUTER;
    }
  }
}

=pod

We also test if a prodigal record lies totally within
a feature in the sequence object.

=cut

unless($inGene) {
  for my $cr (@recoord) {
    if($start <= $cr->[0] and $end >= $cr->[1]) {
      $inGene = 1;
      last;
    }
  }
}

if($inGene) { next SPRDL; }

my @prodHead = qw(
Beg End Std Total CodPot StrtSc Codon RBSMot
Spacer RBSScr UpsScr TypeScr GCCont ShaHex
);

my $dx = 0;
my @prodStr; # String containing information coming from prodigal.
for my $phead (@prodHead) {
  push(@prodStr, "$phead: $ll[$dx]"); 
  $dx += 1;
}
my $prodStr = join("; ", @prodStr);
my $distFromTE = distTE([$start, $end], [$teSubStart, $teSubEnd]);

=pod

$prft. Bio::SeqFeature for prodigal record.
A feature is created and added regardless of the distance
from TE or the prodigal score. Color is however decided
by prodigal rank, distance from TE and prodigal score.

=cut


# $prft. Bio::SeqFeature for prodigal record.
my $color = prdcol($prdlCnt, $distFromTE, $score);
my $prft = Bio::SeqFeature::Generic->new(
-primary => 'CDS',
-start => $start,
-end => $end,
-strand => $strand,
-tag => {
  'color' => $color,
  'note' => $prodStr
}
);

# $teSubStart: Start of the TE in the subsequence.
# $teSubEnd: End of the TE in the subsequence.
# $teStrand: Strand of the TE.
# filename, organism, PPsequence, PPstrand, TEstrand.
$subgbkFT->add_SeqFeature($prft);
my $aaseq = aaseq($prft);
$aaseq =~ s/\*$//;
$aaseq =~ s/^[VL]/M/;
$aaseq =~ s/^[vl]/m/;

if($prdlCnt < $ppFeatAddLimit) {
$subgbk->add_SeqFeature($prft);
$prft->add_tag_value("translation", $aaseq);
}

$prdlCnt += 1;


# $ppFeatAddLimit
# Prodigal features are added upto 20 features. More than that
# are added only if their prodigal score > 0.
# if($score <= 0 and $prdlCnt >= $ppFeatAddLimit) { last; }


=pod

If within specified distance of the TE and score > 0 and count < 20
insert a record in SQL table $conf{prepeptab}.
Also write the peptide sequences to the fasta filename $fastafn
derived from $taildir. See B<Genbank and fasta file names> above.

=cut

# if within specified range of the TE, insert a record in SQL
# table $conf{prepeptab}.
if($distFromTE <= $maxDistFromTE and $prdlCnt <= $ppFeatAddLimit) {
  unless(ref($seqout1)) {
    $seqout1=Bio::SeqIO->new(-file => ">$fastafn");
  }
  my $strandReward = "0";
  if($strand == $teStrand) {
    $strandReward = 1;
  }
  if($ppFastaOutputCnt <= $fastaOutputLimit or ($score >= $prodigalScoreThresh)) {
    my $aaobj = Bio::Seq->new(-seq => $aaseq);
    my $fastaid = $teProtAcc . "_" . $ppFastaOutputCnt;
    $aaobj->display_id($fastaid);
    $aaobj->description("SameStrand: $strandReward; " . $prodStr);
    $seqout1->write_seq($aaobj);
    my $spbinom = $species->binomial("FULL");
    $spbinom =~ s/'//g;
    insertSQL($teProtAcc, $spbinom, $ppFastaOutputCnt, $fastaid, $aaseq,
        $strand, $teStrand, $distFromTE, $score);
    $ppFastaOutputCnt += 1;
  }
}
# The else below is only to use a different series of fastaid postfix,
# $allFastaOutputCnt. And in this case we don't care about how many have
# already been reported.
else {
  unless(ref($seqout1)) {
    $seqout1=Bio::SeqIO->new(-file => ">$fastafn");
  }
  my $strandReward = "0";
  if($strand == $teStrand) {
    $strandReward = 1;
  }
  my $aaobj = Bio::Seq->new(-seq => $aaseq);
  my $fastaid = $teProtAcc . "_" . $allFastaOutputCnt;
  $aaobj->display_id($fastaid);
  $aaobj->description("SameStrand: $strandReward; " . $prodStr);
  $seqout1->write_seq($aaobj);
  my $spbinom = $species->binomial("FULL");
  $spbinom =~ s/'//g;
  insertSQL($teProtAcc, $spbinom, $allFastaOutputCnt, $fastaid, $aaseq,
      $strand, $teStrand, $distFromTE, $score);
  $allFastaOutputCnt += 1;
}
  push(@terpos, $terpos);
} # End of else for the if which skips done terpos.

} # end of SPRDL: for my $lr (@sprdl)

=pod

At this point we have gone through all the output from Prodigal.

=cut


=head3 Write the genbank output file.

Below, the $subgbk object is written out to $ofn which is derived
from $taildir. See B<Genbank and fasta file names> above.

=cut

my $subout = Bio::SeqIO->new(-file => ">$ofn", -format => "genbank");
$subgbk->display_id($teProtAcc . "_cluster");
$subgbk->accession_number($teProtAcc . "_cluster");
$subgbk->species($species);
$subout->write_seq($subgbk);

#copy($gbkfn, $gbkgi . ".gbk");
#copy($subfn, "sub.fna");
#copy($prdfn, $gbkgi . ".prodigal");

unlink($gbkfn, $subfn, $prdfn, $tefn);
}

close($ofh);
exit;

# Multiple END blocks run in reverse order of definition.
END {
close(STDERR);
close(ERRH);
$handle->disconnect();
}


# {{{ sub insertSQL {
sub insertSQL {
  my ($teProtAcc, $spbinom, $ppFastaOutputCnt, $fastaid, $aaseq,
      $strand, $teStrand, $distFromTE, $score) = @_;
  my $instr = qq/insert or replace into $conf{prepeptab} values(/;
      $instr .= $handle->quote($teProtAcc) . ", ";
      $instr .= $handle->quote($spbinom) . ", ";
      $instr .= $ppFastaOutputCnt . ", ";
      $instr .= $handle->quote($fastaid) . ", ";
      $instr .= $handle->quote($aaseq) . ", ";
      $instr .= $strand . ", ";
      $instr .= $teStrand . ", ";
      $instr .= $distFromTE . ", ";
      $instr .= $score . ")";
      unless($handle->do($instr)) {
      linelistE($instr);
      }
}
# }}}

# {{{ sub distTE.

=head3 sub distTE

Gets two pairs of numbers

prodigal peptide start and end

TE start and end

Returns the minimum distance between the two.

=cut


sub distTE {
  my $prse = shift(@_);
  my $tese = shift(@_);
  my $mindist = 99999999;
  for my $prpos (@{$prse}) {
    for my $tepos (@{$tese}) {
      my $dist = abs($prpos - $tepos);
      $mindist = $mindist < $dist ? $mindist : $dist; 
    }
  }
  return($mindist);
}
# }}}

# {{{ sub prodigal2aa listref, fastafilename. Not used.

sub prodigal2aa {
  my $lr = shift(@_);
  my $subfn = shift(@_);

  my $seqio = Bio::SeqIO->new(-file => $subfn, -format => "fasta");
  my $seqobj = $seqio->next_seq();

  my ($start, $end, $strand) = @{$lr}[0, 1, 2];

  my $cds;
  if($strand == 1) {
    $cds = $seqobj->trunc($start, $end);
  }
  else {
    $cds = $seqobj->trunc($start, $end)->revcom();
  }
  my $aaobj = $cds->translate();
  $aaobj->display_id($start);
  $aaobj->description("$end, $strand");
  return($aaobj);
}
# }}}

# {{{ sub seqobj2print $aaobj. Not used.
sub seqobj2print {
  my $aaobj = shift(@_);
  my $memvar;
 open(my $memh, ">", \$memvar)
     or die "Can't open memory file: $!";
 my $bout=Bio::SeqIO->new(-fh => $memh, -format => 'fasta');
  $bout->write_seq($aaobj);
  close($memh);
  return($memvar);
}
# }}}

# {{{ sub aaseq
sub aaseq {
my $ft = shift(@_);
my $fseq = $ft->spliced_seq(-nosort => 1);
my $aaobj = $fseq->translate();
return($aaobj->seq());
}
# }}}

# {{{ sub prdcol

=head3 sub prdcol

The colour in which a precursor peptide feature will get rendered
in Artemis gets decided here.

=cut


sub prdcol {
my $prdlCnt = shift(@_);
my $dte = shift(@_);
my $score = shift(@_);
if($dte <= $maxDistFromTE and $score >= $colorThreshScore) {
return("255 0 160");
}
elsif($prdlCnt < 3) {
return("255 0 0");
}
elsif($prdlCnt < 12) {
return("255 110 110");
}
else {
return("255 188 188");
}
}
# }}}

# {{{ sub locateTE

=head3 sub locateTE

The TE nucleotide sequence fasta file

The sub sequence fasta file.

Uses blastn to determine and return the start and end of the TE in
the subsequence.

=cut

sub locateTE {
my %args = @_;
my $tefn = $args{tefn};
my $subfn = $args{subfn};
my($blnh, $blnf)=tempfile($template, DIR => $tempdir, SUFFIX => '.fna');
close($blnh);
my $xstr = qq(blastn -query $tefn -subject $subfn -task megablast);
$xstr .= qq( -out $blnf -outfmt 6 -dust no);
qx($xstr);
open(my $bloh, "<", $blnf);
my $line = readline($bloh); chomp($line); 
linelistE($line);
close($bloh);
unlink($blnf);
my @ll = split(/\t/, $line);
my($ts, $te) = @ll[8,9];
my $start = $ts < $te ? $ts : $te;
my $end = $ts < $te ? $te : $ts;
return($start, $end);
}
# }}}

# {{{ sub fetchGbk hash(uid, outfile) returns(Bio::Seq object) ### for nucleotide genbanks only
# if outfile is specified we get a file, otherwise we get a Bio::Seq object.
sub fetchGbk {
my %args = @_;
my $uid = $args{uid};
my $outfile = $args{outfile};
my $efetch= $efetchURL;
$efetch .= 'db=nucleotide&';
$efetch .= "id=$uid\&";
$efetch .= "retmode=text\&";
$efetch .= "rettype=gbwithparts";
my ($fh, $filename)=tempfile($template, DIR => $tempdir, SUFFIX => '.gbk');
select($fh);
getprint($efetch);
select(STDOUT);
close($fh);
if($outfile) {
if(copy($filename, $outfile)) {
  unlink($filename);
  return(1);
}
else {
  carp("Copy of $filename to $outfile failed");
  unlink($filename);
  return(0);
}
}
else {
my $seqio = Bio::SeqIO->new(-file  => $filename);
my $seqobj = $seqio->next_seq();
unlink($filename);
return($seqobj);
}

}
# }}}

# {{{ sub subgenbank. hash(infile, start, end). Returns a Bio::Seq.
# optional keys: outformat
sub subgenbank {
  my %args = @_;
  my $ingbk = $args{infile};
  my $start = $args{start};
  my $end = $args{end};

  my $seqio = Bio::SeqIO->new(-file => $ingbk);
  my $seqobj=$seqio->next_seq();
  my $inlen = $seqobj->length();
  if($end > $inlen) { $end = $inlen; }
  my $subseqstr = $seqobj->subseq($start, $end);

  my $outobj = Bio::Seq->new(-seq => $subseqstr);

  my @ft = $seqobj->get_all_SeqFeatures();
  my @oft;
  for my $ft (@ft) {
    my @temp = $ft->location()->each_Location();
    my $nloc = scalar(@temp);
    if($nloc == 1 and $ft->start() >= $start and $ft->end() <= $end) {
      push(@oft, $ft);
    }
  }

  for my $ft (@oft) {
    my $fst = $ft->start();
    my $fend = $ft->end();
    my $adj = $start - 1;
    $ft->start($fst - $adj);
    $ft->end($fend - $adj);
    $outobj->add_SeqFeature($ft);
  }

  return($outobj);

}
# }}}

# {{{ sub TEcoordsByProtId (gbkfile => filename, protid => proteinid);
sub TEcoordsByProtId {
  my %args = @_;
  my $ingbk = $args{gbkfile};
  my $protid = $args{protid};
  my $seqio = Bio::SeqIO->new(-file => $ingbk);
  my $seqobj=$seqio->next_seq();
  for my $ft ($seqobj->get_all_SeqFeatures()) {
    if($ft->has_tag("protein_id")) {
      my (@temp) = $ft->get_tag_values("protein_id");
      if(grep {$_ eq $protid} @temp) {
        my $start = $ft->start();
        my $end = $ft->end();
        my $strand = $ft->strand();
        return([$start, $end, $strand]);
      }
    }
  }
return();
}
# }}}



# {{{ subroutines tablist, linelist, tabhash and their *E versions.
# The E versions are for printing to STDERR.

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

__END__


