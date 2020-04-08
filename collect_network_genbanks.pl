#!/usr/bin/perl
use 5.14.0;
use utf8;
use Carp;
use File::Basename;
use File::Spec;
use DBI;
use Bio::SeqIO;
use Bio::Seq;
use List::Util qw(reduce any all none notall first
  max maxstr min minstr product sum sum0
  pairs unpairs pairkeys pairvalues pairfirst pairgrep pairmap
  shuffle uniq uniqnum uniqstr
  );
use File::Find;
use File::Copy;

# {{{ Getopt::Long
use Getopt::Long;
# my $conffile = qq(local.conf); # %conf is not used.
my $errfile;
my $outfile;
my $pnafasdir;
my $colourFile = qq(/home/work/ripper/colours.txt);
our $verbose;
my $help;
GetOptions (
"outfile=s" => \$outfile,
# "conffile:s" => \$conffile,
"errfile:s" => \$errfile,
"verbose" => \$verbose,
"colourfile:s" => \$colourFile,
"pnafasdir:s" => \$pnafasdir,
"help" => \$help
);
# }}}

if($help) {
exec("perldoc $0");
exit;
}

=head1 Name

collect_network_genbanks.pl

=head2 Example
 
 perl /home/sco/mnt/smoke/docker/ripper/collect_network_genbanks.pl


=cut

# {{{ open the errfile
if($errfile) {
open(ERRH, ">", $errfile);
print(ERRH "$0", "\n");
close(STDERR);
open(STDERR, ">&ERRH"); 
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

my %ffoptions = (
wanted => \&onfind,
no_chdir => 1
); 

my %netgbks;

find(\%ffoptions, ".");

for my $key (keys %netgbks) {
  my @netlist = @{$netgbks{$key}};
  tablist($key, @netlist);
  my $outdir = "../Network" . $key;
  unless(-d $outdir) { mkdir $outdir; }
  my $ogbkpath = "../orgnamegbk";
  opendir(OGBK, $ogbkpath);
  my @ogbks = readdir(OGBK);
  for my $ngbk (@netlist) {
    for my $ogbk (@ogbks) {
      if($ogbk =~ m/$ngbk/) {
        copy(File::Spec->catfile($ogbkpath, $ogbk), $outdir);
      }
    }
  }
}



exit;

sub onfind {
  my $fp = $_;
  if(-d $fp) { return; }
  else {
    my ($noex, $dir, $ext)= fileparse($fp, qr/\.[^.]*/);
    my $bn = $noex . $ext;
    if($ext =~ /faa$/ and $noex =~ m/p_cc\d+/) {
      my ($netnum) = $noex =~ m/p_cc(\d+)/;
      my @gbks = gbknames($fp);
      $netgbks{$netnum} = \@gbks;
    }
  }
}


sub gbknames {
  my $ifn = shift(@_);
  my @retlist;
  my $seqio = Bio::SeqIO->new(-file => $ifn, -format => 'fasta');
  while(my $seqobj = $seqio->next_seq()) {
    my $id = $seqobj->display_id();
    my @id = split(/\|/, $id);
    my $gbk = $id[1];
    $gbk =~ s/_\d+$//;
    unless ( any {$_ eq $gbk} @retlist ) {
      push(@retlist, $gbk);
    }
  }
  return(@retlist);
}




# Multiple END blocks run in reverse order of definition.
END {
close($ofh);
close(STDERR);
close(ERRH);
# $handle->disconnect();
}

# {{{ sub sorter
sub sorter {
  my $alpha = $a;
  my $beta = $b;
  my ($astr) = $alpha =~ m/^(\D+)/;
  my ($bstr) = $beta =~ m/^(\D+)/;
  my ($anum) = $alpha =~ m/(\d+)$/;
  my ($bnum) = $beta =~ m/(\d+)$/;
  # tablistE($astr, $bstr, $anum, $bnum);
  if($astr eq $bstr) {
    return($anum <=> $bnum);
  }
  else {
    return(lc($astr) cmp lc($bstr));
  }
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


