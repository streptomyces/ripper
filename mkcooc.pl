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
use Bio::SeqIO;
use Bio::Seq;
use XML::LibXML;
use List::Util qw(first max maxstr min minstr reduce shuffle sum
    any all uniq uniqnum uniqstr);
use Bio::DB::EUtilities;

# {{{ Getopt::Long
use Getopt::Long;
my $outdir;
my $conffile = qq(local.conf);
my $verbose;
my $apikey;
my $email;
GetOptions (
"outdir:s" => \$outdir,
"conffile:s" => \$conffile,
"ncbiapikey|apikey:s" => \$apikey,
"email:s" => \$email,
"verbose" => \$verbose
);
# }}}

# {{{ ### POD ###

=head1 Name

mkcooc.pl

=head2 Do not call directly

This script is called by F<ripper_run.pl> and it produces output
to be used by other scripts. On its own the output produced by
this script does not amount to much. The examples below are for
use testing during development.

=head2 Examples

 perl -c mkcooc.pl

 perl mkcooc.pl -verbose -outdir ignore/one \
 -email govind.chandra@jic.ac.uk \
 -- MBW4496662.1

 perl mkcooc.pl -verbose -outdir ignore/one \
 -email govind.chandra@jic.ac.uk \
 -- WP_091117926.1

 perl mkcooc.pl -verbose -outdir ignore/WP_054914858.1 WP_054914858.1

 perl mkcooc.pl -verbose -outdir ignore/two
 -email govind.chandra@jic.ac.uk
 -- WP_236176819.1

 perl mkcooc.pl -verbose -outdir ignore/one \
 -email govind.chandra@jic.ac.uk \
 -- TFI52254.1

 perl mkcooc.pl -verbose -outdir ignore/two \
 -email govind.chandra@jic.ac.uk \
 -- WP_091117926.1

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

=head2 Thioamitide test list provided by Andy in Dec 2024.

 WP_020634200.1
 TFI52254.1
 WP_091117926.1
 WP_017595620.1
 WP_106236741.1
 WP_217209178.1
 WP_184984772.1
 BAN83919.1
 KPC82023.1
 WP_190061747.1

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

if($verbose) {
  my $verbosefn = File::Spec->catfile($outdir, "verbose.txt");
  open(VERB, ">", $verbosefn);
}

my $query = $protid . "[accn]";

# {{{ esearch to make @ids.
my %esarg = (
  -eutil => 'esearch',
  -db     => 'protein',
  -term   => $query,
  -retmax => 6
);
if($apikey) {
  $esarg{-api_key} = $apikey;
}
if($email) {
  $esarg{-email} = $email;
}
my $factory = Bio::DB::EUtilities->new(%esarg);
my @ids = $factory->get_ids;
say(STDERR ("$protid: ", join(" ", @ids)));
# }}}

# {{{ Get nucleotide ids and placein @ntids.

# We first try elink. If that does not give us any nucleotide
# identifiers we get the genpept file for the protein accession and
# see if there is a DBSOURCE in it. If there is one then we use this
# accession to get the nucleotide UID and place it in @ntids.

# # If we do something like below
# unless(@ids) {
#   push(@ids, $protid);
# }
# # We get the error below.
# # MSG: NCBI LinkSet error: protein: BLOB ID IS NOT IMPLEMENTED

my @ntids;
my %elarg = (
  -eutil => 'elink',
  -dbfrom     => 'protein',
  -db         => 'nuccore',
  -linkname   => 'protein_nuccore',
  -id         => \@ids
);
if($apikey) {
  $elarg{-api_key} = $apikey;
}
if($email) {
  $elarg{-email} = $email;
}
my $factory1 = Bio::DB::EUtilities->new(%elarg);
while (my $ds = $factory1->next_LinkSet) {
push(@ntids, $ds->get_ids);
}

my @by_ntlen;
if(@ntids) {
  my $noop = 1;
}
else {
  say(STDERR ("No nucleotide ids for $protid from elinks."));
  say(STDERR ("Trying the genpept file."));
  my $gpfn = efetch_genpept($protid);
  my @dbsids = dbsource($gpfn);
  if(@dbsids) {
    push(@ntids, @dbsids);
  }
  unlink($gpfn);
}
# }}}

# {{{ if @ntids we proceed else die().
if(scalar(@ntids) > 1) {
  if($verbose) {
    say(VERB (join(" ", uniqstr(@ntids))));
  }
  @by_ntlen = ntlen(uniqstr(@ntids));
  # for my $lr (@by_ntlen) { say(join("\t", @{$lr})); } # Debugging only
  my ($tmpfh, $tmpfn) = efetch_ntgbk($by_ntlen[0]->[0]);
  my $acc = mkcooc($tmpfh);
  if(-d $gbkcache) {
    copy($tmpfn, File::Spec->catfile($gbkcache, $acc . ".gbk"));
  }
  unlink($tmpfn);
}
elsif(scalar(@ntids) == 1) {
  if($verbose) {
    say(VERB (join(" ", uniqstr(@ntids))));
  }
  my ($tmpfh, $tmpfn) = efetch_ntgbk($ntids[0]);
  my $acc = mkcooc($tmpfh);
  if(-d $gbkcache) {
    copy($tmpfn, File::Spec->catfile($gbkcache, $acc . ".gbk"));
  }
  unlink($tmpfn);
}
else {
  die("Failed to get nucleotide genbank for $protid");
}
# }}}

exit;

### subs begin ###

# {{{ sub mkcooc
sub mkcooc {
  my $tmpfh = shift(@_);
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
  return($acc);
}
# }}}

# {{{ sub dbsource
sub dbsource {
  my $gpfn = shift(@_);
  say(STDERR ("In dbsource: $gpfn"));
  open(my $ifh, "<", $gpfn) or croak("Failed to open $gpfn.");
  while(my $line = readline($ifh)) {
    chomp($line);
    if($line =~ /^DBSOURCE/) {
      my @ll = split(/\s+/, $line);
      my $dbs_accn = pop(@ll);
      # my @ids = accn2uid($dbs_accn);
      say(STDERR ("In dbsource. Found $dbs_accn."));
      return($dbs_accn);
    }
  }
  return();
}
# }}}

# # {{{ sub accn2uid. No longer used. Commented out.
# # Used to be called from inside dbsource();
# sub accn2uid {
#   my $accn = shift(@_);
#   $accn =~ s/\.\d+$//;
#   say(STDERR ("In accn2uid: $accn"));
#   my $query = $accn . "[ACCN]";
#   say(STDERR ("In accn2uid: $query"));
#   my %esarg = (
#     -eutil => 'efetch',
#     -db     => 'nuccore',
#     -term   => $accn,
#     -format => 'uid'
#   );
#   if($apikey) {
#     $esarg{-api_key} = $apikey;
#   }
#   if($email) {
#     $esarg{-email} = $email;
#   }
#   my $factory = Bio::DB::EUtilities->new(%esarg);
#   my @ids = $factory->get_ids;
#   return(@ids);
# }
# # }}}

# {{{ sub efetch_genpept
sub efetch_genpept {
  my $protid = shift(@_);
my %efarg = (
  -eutil => 'efetch',
  -db      => 'protein',
  -rettype => 'genpept',
  -id      => $protid
);
if($apikey) {
  $efarg{-api_key} = $apikey;
}
if($email) {
  $efarg{-email} = $email;
}
my $factory = Bio::DB::EUtilities->new(%efarg);

my $template = "genpeptXXXXXX";
my($tmpfh, $tmpfn)=tempfile($template, DIR => $outdir, SUFFIX => '.gp');
close($tmpfh);
# dump <HTTP::Response> content to a file (not retained in memory)
$factory->get_Response(-file => $tmpfn);
return($tmpfn);
}
# }}}

# {{{ sub efetch_ntgbk
sub efetch_ntgbk {
  my $ntid = shift(@_);
  say(STDERR "Fetching $ntid");
  my %efarg = (
    -eutil => 'efetch',
    -db      => 'nuccore',
    -rettype => 'gbwithparts',
    -id      => $ntid
  );
  if($apikey) {
    $efarg{-api_key} = $apikey;
  }
  if($email) {
    $efarg{-email} = $email;
  }
  my $factory = Bio::DB::EUtilities->new(%efarg);

  my $template = "coocXXXXXX";
  my($tmpfh, $tmpfn)=tempfile($template, DIR => '.', SUFFIX => '.gbk');
  # dump <HTTP::Response> content to a file (not retained in memory)
  $factory->get_Response(-file => $tmpfn);
  return($tmpfh, $tmpfn);
}
# }}}

# {{{ sub ntlen
sub ntlen {
  my @ntids = @_;
  my @retlist;
  for my $ntid (@ntids) {
    my %efarg = (
      -eutil => 'esummary',
      -db      => 'nuccore',
      -rettype => 'docsum',
      -id      => $ntid
    );
    if($email) {
      $efarg{-email} = $email;
    }
    if($apikey) {
      $efarg{-api_key} = $apikey;
    }
    my $factory = Bio::DB::EUtilities->new(%efarg);
    # <HTTP::Response>
    my $response = $factory->get_Response();
    my $xml = $response->content();
    my $dom = XML::LibXML->load_xml(string => $xml);
    my @items = $dom->getElementsByTagName("Item");
    for my $item (@items) {
      my @attributes = $item->attributes();
      if(any {$_ =~ m/Name="Length"/} @attributes) { 
        # say(join("\t", @attributes));
        my $ntlen = $item->textContent();
        push(@retlist, [$ntid, $ntlen]);
      }
    }
  }
  my @sorted = sort sorter (@retlist);
  return(@sorted);
}
# }}}

# {{{ sub sorter 
sub sorter {
  return($b->[1] <=> $a->[1]);
}
# }}}

# Multiple END blocks run in reverse order of definition.
END {
close($ofh);
if($verbose) {
  close(VERB);
}
}

