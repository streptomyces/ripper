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
my $conffile = qq(local.conf);
GetOptions (
"outdir:s" => \$outdir,
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

my $protid = $ARGV[0];



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

# {{{ gbkcache initialisation
my $gbkcache = qq(gbkcache);
if(exists($conf{gbkcache})) { $gbkcache = $conf{gbkcache}; }
# }}}




unless(-d $outdir) {
  unless(make_path($outdir)) {
    croak("Failed to make $outdir.");
  }
}
my $ofn = File::Spec->catfile($outdir, "main_co_occur.csv");
open(my $ofh, ">", $ofn) or croak("Failed to open $ofn for writing.");

# say($protid);
my $query = $protid . "[accn]";

# {{{ esearch to make @ids.
my $factory = Bio::DB::EUtilities->new(-eutil => 'esearch',
                                       -db     => 'protein',
                                       -term   => $query,
                                       -email  => 'govind.chandra@gmail.com',
                                       -retmax => 3
                                     );
my @ids = $factory->get_ids;
# }}}

# {{{ elink to get @ntids.
my $factory1 = Bio::DB::EUtilities->new(-eutil => 'elink',
                                       -email  => 'govind.chandra@gmail.com',
                                       -db     => 'nucleotide',
                                       -dbfrom => 'protein',
                                       -id     => \@ids
                                     );
my @ntids;
while (my $ds = $factory1->next_LinkSet) {
#    print "   Link name: ",$ds->get_link_name,"\n";
#    print "Protein IDs: ",join(',',$ds->get_submitted_ids),"\n";
#    print "    Nuc IDs: ",join(',',$ds->get_ids),"\n";

push(@ntids, $ds->get_ids);
}
# }}}

# {{{ efetch to get one nucleotide genbank file.
my $factory2 = Bio::DB::EUtilities->new(-eutil => 'efetch',
                                       -db      => 'nucleotide',
                                       -rettype => 'gbwithparts',
                                       -email   => 'govind.chandra@gmail.com',
                                       -id      => [$ntids[0]]
                                     );

my $template = "coocXXXXXX";
my($tmpfh, $tmpfn)=tempfile($template, DIR => '.', SUFFIX => '.gbk');

# dump <HTTP::Response> content to a file (not retained in memory)
$factory2->get_Response(-file => $tmpfn);
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
# }}}

if(-d $gbkcache) {
copy($tmpfn, File::Spec->catfile($gbkcache, $acc . ".gbk"));
}
unlink($tmpfn);
close($ofh);
exit;

