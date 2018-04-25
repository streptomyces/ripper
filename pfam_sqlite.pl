#!/usr/bin/perl
use 5.14.0;
use utf8;
use Carp;
use File::Basename;
use File::Spec;
use DBI;
use File::Copy;
use Bio::SeqIO;
use Bio::Seq;
use Bio::SearchIO;
use File::Temp qw(tempfile tempdir);

my $tempdir = qw(/tmp);
my $template="PfamXXXXX";

# {{{ Getopt::Long
use Getopt::Long;
my $outdir;
my $indir;
my $fofn;
my $outex; # extension for the output filename when it is derived on infilename.
my $conffile = qq(local.conf);
my $errfile;
my $hmmscanbin = qq(hmmscan);
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
"verbose" => \$verbose,
"help" => \$help
);
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
if(exists($conf{hmmscanbin})) {
  $hmmscanbin = $conf{hmmscanbin};
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

my $hmmdb = File::Spec->catfile($conf{hmmdir}, $conf{hmmdb});

my $dbfile=$conf{sqlite3fn};
my $handle=DBI->connect("DBI:SQLite:dbname=$dbfile", '', '');
my $create_table_str = <<"CTS";
create table if not exists $conf{pfamrestab} (
qname text,
qlen integer,
hname text,
hlen integer,
qstart integer,
qend integer,
qcov float,
hstart integer,
hend integer,
hcov float,
fracid float,
signif float,
hdesc text,
unique(qname, qstart, qend, hname)
);
CTS
unless($handle->do($create_table_str)) {
croak($create_table_str);
}

my $qstr="select fastaid, aaseq from $conf{prepeptab}";
my $stmt=$handle->prepare($qstr);
$stmt->execute();

while(my $hr=$stmt->fetchrow_hashref()) {
my $id=$hr->{fastaid};
my $aaseq=$hr->{aaseq};

my $hmmoutfn = scan(aaseq => $aaseq, hmmdb => $hmmdb, name => $id);

# linelist($hmmoutfn);
my $copyFlag = 0;
my @hr = hspHashes($hmmoutfn);
for my $hr (@hr) {
  if(ref($hr) and $hr->{signif} <= 0.05) {
    my $acc = $hr->{hname};
    my $bacc = $acc; $bacc =~ s/\.\d+$//;
    my $hcov = sprintf("%.3f", $hr->{alnlen}/$pfl{$bacc});

    my $instr = qq/insert or replace into $conf{pfamrestab}/;
    $instr .= qq/ (qname, qlen, hname, hlen, qstart, qend, qcov, hstart, hend,/;
    $instr .= qq/ hcov, fracid, signif, hdesc)/;
    $instr .= qq/ values(/;
    $instr .= $handle->quote($hr->{qname}) . ", " ;
    $instr .= $hr->{qlen} . ", ";
    $instr .= $handle->quote($hr->{hname}) . ", " ;
    $instr .= $pfl{$bacc} . ", ";
    $instr .= $hr->{qstart} . ", ";
    $instr .= $hr->{qend} . ", ";
    $instr .= $hr->{qcov} . ", ";
    $instr .= $hr->{hstart} . ", ";
    $instr .= $hr->{hend} . ", ";
    $instr .= $hcov . ", ";
    $instr .= $hr->{fracid} . ", ";
    $instr .= $hr->{signif} .", ";
    $instr .= $handle->quote($hr->{hdesc});  
    $instr .= qq/)/;
    # linelist($instr);
    unless($handle->do($instr)) {
      linelistE($instr);
    }
  }
}
    if($copyFlag) {
    copy($hmmoutfn, "scan.result");
    }
unlink($hmmoutfn);
}

exit;

# Multiple END blocks run in reverse order of definition.
END {
close($ofh);
close(STDERR);
close(ERRH);
$handle->disconnect();
}

# {{{ sub pflens
sub pflens {
  my $pfamhmmdatfn = File::Spec->catfile($conf{hmmdir}, $conf{pfamhmmdatfn});
  open(PFT, "<", $pfamhmmdatfn) or croak "Failed to open $pfamhmmdatfn";
  my %rethash;
  local $/ = "\n//\n";
    while(<PFT>) {
      my $record = $_;
      chomp($record);
      my @lines = split(/\n/, $record);
      my %hmmrec;
      for my $line (@lines) {
        chomp($line);
        $line =~ s/^#=GF\s+//;
        my @ll = split(/\s+/, $line);
        $hmmrec{$ll[0]} = $ll[1];
      }
      if(exists($hmmrec{AC}) and exists($hmmrec{ML})) {
        my $acc = $hmmrec{AC};
        $acc =~ s/\.\d+$//;
        $rethash{$acc} = $hmmrec{ML};
      }
    }
  close(PFT);
  return(%rethash);
}
# }}}

# {{{ sub scan (%(aaseq, hmmdb, name));
# aaseq can be Bio::Seq or Fasta filename or AA sequence.
#
sub scan {
#  my $self = shift(@_);
  my %args = @_;
  my $aaseq = $args{aaseq};
  my $hmmdb;
  if(exists($args{hmmdb})) {
    $hmmdb = $args{hmmdb};
  }
  else {
    $hmmdb = "/Users/sco/blast_databases/pfam/Pfam-A.hmm";
  }
  my $aafile;
  my $deleteQuery = 1;
  if(ref($aaseq)) {
    my($fh, $fn)=tempfile($template, DIR => $tempdir, SUFFIX => ".faa");
    my $seqio = Bio::SeqIO->new(-fh => $fh, -format => 'fasta');
    $seqio->write_seq($aaseq);
    close($fh);
    $aafile = $fn;
  }
  elsif(-s $aaseq) {
    $aafile = $aaseq;
    $deleteQuery = 0;
  }
  elsif(exists($args{name}) and exists($args{aaseq})) {
    my $outobj = Bio::Seq->new(-seq => $args{aaseq});
    $outobj->display_id($args{name});
    my($fh, $fn)=tempfile($template, DIR => $tempdir, SUFFIX => ".faa");
    my $seqio = Bio::SeqIO->new(-fh => $fh, -format => 'fasta');
    $seqio->write_seq($outobj);
    close($fh);
    $aafile = $fn;
  }
  else {
    croak("$aaseq could not be resolved to a filename or Bio::Seq object and no name is provided");
  }
    my($fh, $fn)=tempfile($template, DIR => $tempdir, SUFFIX => ".hmmscan");
    close($fh);
    my $xstr = qq($hmmscanbin --acc -o $fn $hmmdb $aafile);
    qx($xstr);
    if($deleteQuery) { unlink($aafile); }
    return($fn);
}
# }}}

# {{{ hspHashes (hmmsearchOutputFile, format)
# returns(list of hashes(qname, hname, qlen, hlen, signif, bit hdesc, qcover, hcover, hstrand) );
sub hspHashes {
#  my $self = shift(@_);
  my $filename=shift(@_);
  my $format = 'hmmer';
  my $temp = shift(@_);
  if($temp) { $format = $temp; }
#print(STDERR "in topHit $filename\n");
  my $searchio = new Bio::SearchIO( -format => $format,
      -file   => $filename );
  my @retlist;
  while( my $result = $searchio->next_result() ) {
    unless($result) { return();}
    my $qname=$result->query_name();
    my $qdesc=$result->query_description();
    my $qlen=$result->query_length();
    while (my $hit = $result->next_hit()) {
      while (my $hsp = $hit->next_hsp()) {
        my $hname=$hit->name();
        my $hlen=$hit->length();
        my $frac_id = sprintf("%.3f", $hsp->frac_identical());
        my $frac_conserved = sprintf("%.3f", $hsp->frac_conserved());
        my $hdesc=$hit->description();
        my $signif=$hsp->significance();
        my $laq=$hsp->length('query');
        # my $lah=$hsp->length('hit');
        my $qcov = sprintf("%.3f", $laq/$qlen);
        my $hcov = 0;
        #if($hlen) {
        #$hcov = sprintf("%.3f", $lah/$hlen);
        #}
        my $qstart = $hsp->start('query');
        my $qend = $hsp->end('query');
        my $hstart = $hsp->start('hit');
        my $hend = $hsp->end('hit');
        my $hframe = $hsp->frame('hit');
        my $bitScore = $hsp->bits();
        my $strand = $hsp->strand('hit');
        my %rethash = (qname => $qname, hname => $hname, qlen => $qlen, hlen => $hlen,
            signif => $signif, bit => $bitScore, qdesc => $qdesc, hdesc => $hdesc,
            hstrand => $strand, qstart => $qstart, hframe => $hframe,
            qend => $qend, hstart => $hstart, hend => $hend, alnlen => $laq,
            fracid => $frac_id, fracsim => $frac_conserved, qcov => $qcov,
            hcov => $hcov);
        push(@retlist, {%rethash});
      }
    }
    push(@retlist, "\/\/");
  }
  return(@retlist);
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

