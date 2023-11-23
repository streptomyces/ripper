#!/usr/bin/perl
use 5.14.0;
use utf8;
use Carp;
# use lib qw(/Users/nouser/perllib);
# use File::Basename;
use File::Temp qw(tempfile tempdir);
use File::Spec;
use File::Path qw(make_path);
use File::Copy;
# use Sco::Common qw(tablist tablistE linelistE);
use Bio::SeqIO;
# use Bio::Seq;
# use Bio::SeqFeature::Generic;
# use Digest::SHA qw(sha1_hex);

# use XML::Simple;
# use LWP::Simple;
# use Net::FTP;
use Bio::DB::EUtilities;

# {{{ Getopt::Long
use Getopt::Long;
my $outdir;
my $protlist;
my $conffile = qq(local.conf);
GetOptions (
"outdir:s" => \$outdir,
"protlist:s" => \$protlist,
"conffile:s" => \$conffile
);
# }}}

# {{{ ### POD ###

=head1 Name

mkcooc.pl

=head2 Examples

 perl -c mkcooc.pl

 rm -rf checkdir
 perl mkcooc.pl -outdir checkdir/WP_236176819.1 WP_236176819.1

 perl mkcooc.pl -outdir checkdir/WP_054914858.1 WP_054914858.1

=head2 Bad ones

RODEO fails to fetch nucleotide sequences for these.

 WP_236176819.1
 WP_253086584.1
 WP_253094575.1
 WP_268150430.1
 WP_273895298.1
 WP_275728677.1

=head2 Good ones

 WP_054914858.1
 WP_104571963.1
 WP_078479507.1
 WP_123752854.1

=cut

# }}} ###

my $apikey;
my $email = 'andrew.truman@jic.ac.uk';
if(exists $ENV{NCBI_API_KEY}) {
  $apikey = $ENV{NCBI_API_KEY};
}
say(STDERR $apikey);


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
if(exists($conf{apikey})) {
  $apikey = $conf{apikey};
}
if(exists($conf{email})) {
  $email = $conf{email};
}

# }}}

# {{{ gbkcache initialisation
my $gbkcache = qq(gbkcache);
if(exists($conf{gbkcache})) { $gbkcache = $conf{gbkcache}; }
# }}}

unless(-d $outdir) {
  unless(make_path($outdir)) {
    croak("Failed to make $outdir.");
  }
}

my %coocdone; # protein_id => gbkfilename
my $coocdonefn = File::Spec->catfile($gbkcache, "cooc.done");
if(-f $coocdonefn and -s $coocdonefn) {
  open(DONE, "<", $coocdonefn);
  while(<DONE>) {
    chomp($_);
    my @ll = split(/\s+/, $_);
    $coocdone{$ll[0]} = $ll[1];
  }
  close(DONE);
}


open(ACC, "<", $protlist);
my @protid = <ACC>;
close(ACC);
for my $protid (@protid) {
  chomp($protid);
  my $ofn = File::Spec->catfile($outdir, $protid . ".csv");
  my $gbkfn = File::Spec->catfile($gbkcache, $coocdone{$protid});
  if(exists($coocdone{$protid}) and -e $gbkfn and -e $ofn) {
    say(STDERR "$protid ($coocdone{$protid}) already exists");
    next;
  }
  else {
    process($protid);
  }
}

open(DONE, ">", $coocdonefn);
for my $protid (keys %coocdone) {
  say(DONE "$protid   $coocdone{$protid}");
}
close(DONE);



sub process {
  my $protid = shift(@_);
  my $ofn = File::Spec->catfile($outdir, $protid . ".csv");
  open(my $ofh, ">", $ofn) or croak("Failed to open $ofn for writing.");

  # say($protid);
  my $query = $protid . "[accn]";
  say(STDERR $query);

  # {{{ esearch to make @ids.
  my %esarg = (
    -eutil => 'esearch',
    -db     => 'protein',
    -term   => $query,
    -retmax => 3
  );
  if($apikey) {
    $esarg{-api_key} = $apikey;
  }
  if($email) {
    $esarg{-email} = $email;
  }
  my $factory = Bio::DB::EUtilities->new(%esarg);
  my @ids = $factory->get_ids;
  unless(@ids) {
    say(STDERR "$protid not found by esearch.");
    return(0);
  }
  # say(STDERR @ids); # These are numeric UIDs. Usually only one in the list.
  # }}}

  # {{{ elink to get @ntids.
  my %elarg = (
    -eutil => 'elink',
    -db     => 'nucleotide',
    -dbfrom => 'protein',
    -id     => \@ids
  );
  if($apikey) {
    $elarg{-api_key} = $apikey;
  }
  if($email) {
    $elarg{-email} = $email;
  }
  my $factory1 = Bio::DB::EUtilities->new(%elarg);
  my @ntids;
  while (my $ds = $factory1->next_LinkSet) {
    push(@ntids, $ds->get_ids);
  }
  # say(STDERR "@ntids"); # These are numeric UIDs. Usually more than one in the list.
  # }}}

  # {{{ efetch to get one nucleotide genbank file.
  # We cycle through @ntids only till we get one genbank file.
  my $template = "coocXXXXXX";
  my $ntgbkflag = 0; # Whether we got a usable genbank file or not.
  my($tmpfh, $tmpfn)=tempfile($template, DIR => '.', SUFFIX => '.gbk');
  for my $ntid (@ntids) {
  my %efarg = (
    -eutil => 'efetch',
    -db      => 'nucleotide',
    -rettype => 'gbwithparts',
    -id      => [$ntids[0]]
  );
  if($email) {
    $efarg{-email} = $email;
  }
  my $factory2 = Bio::DB::EUtilities->new(%efarg);
  my $response = $factory2->get_Response();
  # <HTTP::Response> content to $tmpfh if is_success().
  if($response->is_success()) {
    print($tmpfh ($response->content()));
    $ntgbkflag = 1;
    last;
  }
  }
  unless($ntgbkflag) {
    unlink($tmpfn);
    return(0);
  }
  # }}}

  seek($tmpfh, 0, 0); # jump to beginning of $tmpfh before SeqIO.
  my $seqio=Bio::SeqIO->new(-fh => $tmpfh);

  my $seqobj=$seqio->next_seq();
  my $binom = $seqobj->species()->binomial();
  # say $binom;
  my $acc = $seqobj->accession();

  # @region is list of 11 features in which the
  # TE is in the middle of the list.
  my @region;
  $region[4] = undef;

  my $match_seen = 0;
  my $cdsCnt = 0;

  # {{{ for my $feat ($seqobj->all_SeqFeatures())
  for my $feat ($seqobj->all_SeqFeatures()) {
    if($feat->primary_tag() eq 'source') {
      if($feat->has_tag("organism")) {
        ($binom) = $feat->get_tag_values("organism");
      }
    }
    if($feat->primary_tag() eq 'CDS') {
      unless($feat->has_tag("protein_id")) { next; }
      my ($gprotid) = $feat->get_tag_values("protein_id");
      if($gprotid eq $protid) {
        $match_seen = 1;
      }
      if(not $match_seen) {
        my $discard = shift(@region);
        push(@region, $feat);
      }
      if($match_seen) {
        push(@region, $feat);
        if(scalar(@region) >= 11) {
          last;
        }
      }
    }
  }
  # }}}

  # {{{ for my $feat (@region). Print out main_co_occur.csv.
  my @header = qw(query organism accession protid
  start end strand product);
  say($ofh (join(",", @header)));
  if($match_seen) {
    for my $feat (@region) {
      unless(ref($feat)) { next; }
      my $start = $feat->start();
      my $end = $feat->end();
      my ($gprotid) = $feat->get_tag_values("protein_id");
      my $strand = $feat->strand() == -1 ? "-" : "+";
      my @anno;
      if($feat->has_tag("gene")) {
        my @temp = $feat->get_tag_values("gene");
        my $temp = join(" ", @temp);
        push(@anno, $temp);
      }
      if($feat->has_tag("product")) {
        my @temp = $feat->get_tag_values("product");
        my $temp = join(" ", @temp);
        push(@anno, $temp);
      }
      my $anno = join(";", @anno);
      say($ofh ("$protid,$binom,$acc,$gprotid,$start,$end,$strand,$anno"));
      #last;
    }
  }
  # }}}

  if(-d $gbkcache) {
    copy($tmpfn, File::Spec->catfile($gbkcache, $acc . ".gbk"));
    $coocdone{$protid} = $acc . ".gbk";
  }
  unlink($tmpfn);
  close($ofh);
  return(1);
}


exit;


