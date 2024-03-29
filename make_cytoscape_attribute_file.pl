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

make_cytoscape_attribute_file.pl

=head2 Example
 
 perl /home/sco/mnt/smoke/docker/ripper/make_cytoscape_attribute_file.pl \
 -outfile cyto.attrib -pnafasdir $(find . -type d -name 'FASTA') \
 -- ../out.txt ../distant.txt

Below are two lines taken from ripper_run.sh

 cyat=${pnadir}/cytoattrib.txt;
 $perlbin ${ripperdir}/make_cytoscape_attribute_file.pl \
 -outfile ${cyat} -- ${outfile} ${distfile}

=cut

# {{{ open the errfile
if($errfile) {
open(ERRH, ">", $errfile);
print(ERRH "$0", "\n");
close(STDERR);
open(STDERR, ">&ERRH"); 
}
# }}}

# {{{ Populate %conf if a configuration file. Commented out.
# my %conf;
# if(-s $conffile ) {
#   open(my $cnfh, "<", $conffile);
#   my $keyCnt = 0;
#   while(my $line = readline($cnfh)) {
#     chomp($line);
#     if($line=~m/^\s*\#/ or $line=~m/^\s*$/) {next;}
#     my @ll=split(/\s+/, $line, 2);
#     $conf{$ll[0]} = $ll[1];
#     $keyCnt += 1;
#   }
#   close($cnfh);
# #  linelistE("$keyCnt keys placed in conf.");
# }
# elsif($conffile ne "local.conf") {
# linelistE("Specified configuration file $conffile not found.");
# }
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

my %membership;

my @fasfiles = glob("$pnafasdir/*.faa");
for my $faa (@fasfiles) {
  my ($noex,$dir,$ext) = fileparse($faa, qr/\.[^.]*/);
  $noex =~ s/^p_//;
  open(FAA, "<", $faa);
  while(<FAA>) {
    my $line = $_; chomp($line);
    if($line =~ m/^>/) {
      $line =~ s/^>//;
      my @ll = split(/\|/, $line);
      my $id = $ll[1];
      $membership{$id} = $noex;
    }
  }
  close(FAA);
}

my @temp = uniqstr(values(%membership));
my @clusters = sort sorter @temp;
tablistE(@clusters);
my @colours = precolor(scalar(@clusters));
tablistE(@colours);
my %colours;
for my $dx (0..$#clusters) {
  $colours{$clusters[$dx]} = $colours[$dx];
}


my $headflag = 0;
for my $infile(@infiles) {
  open(my $ifh, "<", $infile);
  my $head = readline($ifh);
  chomp($head);
# linelist($head);
  my @head = split(/\t/, $head);
  ($head[0], $head[3]) = ($head[3], $head[0]);
  $head[0] =~ s/^fasta//i;
  push(@head, "Genus", "Network", "Color");
  unless($headflag) { tablist(@head); $headflag = 1; }
  while(my $line = readline($ifh)) {
    chomp($line);
    my @ll = split(/\t/, $line);
    ($ll[0], $ll[3]) = ($ll[3], $ll[0]);
    my $org = $ll[1];
    my @org = split(/\b/, $org, 2);
    my $genus = $org[0];
    my $clus = $membership{$ll[0]};
    push(@ll, $genus, $clus, $colours{$clus});
    tablist(@ll);
  }
  close($ifh);
}

tablistE(scalar(@clusters));

exit;

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


# {{{ sub precolor
sub precolor {
  my $num = shift(@_);
  open(COLH, "<", $colourFile);
  my @cols;
  while(<COLH>) {
    my $line = $_; chomp($line);
    push(@cols, $line);
  }
  close(COLH);
  my $ncol = scalar(@cols);
  if($num <= $ncol) {
    return(@cols[0..($num-1)]);
  }
  else {
    my $times = int($num / $ncol);
    my $mod = $num % $ncol;
    my @retlist;
    for(1..$times) {
      push(@retlist, @cols);
    }
    if($mod) {
      push(@retlist, @cols[0..($mod-1)]);
    }
    return(@retlist);
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

# {{{ sub richcolors
sub richcolors {
  my $en = shift(@_);
  my @ex = (0);
  for(1..$en-1) {
    push(@ex, $ex[$#ex] + 1/($en-1)); 
  }
  my @reds = rgb(reds(@ex));
  my @greens = rgb(greens(@ex));
  my @blues = rgb(blues(@ex));
  my @colour = colour(\@reds, \@greens, \@blues);
  my @repicked = repick(@colour);
  return(@repicked);
}
# }}}

# {{{ All these subs work for the sub richcolors.

# {{{ sub rgb
sub rgb {
my @in = @_;
my @retlist;
for my $in (@in) {
my $sc255 = int(256 * $in);
if($sc255 > 255) { $sc255 = 255; } 
push(@retlist, sprintf("%02X", $sc255));
}
return(@retlist);
}
# }}}

# {{{ sub colour
sub colour {
my ($red, $gre, $blu) = @_;
my @col;
my @temp = @{$red};
for my $dx (0..$#temp) {
my $col = "#" . $red->[$dx] . $gre->[$dx] . $blu->[$dx];
push(@col, $col);
}
return(@col);
}
# }}}

# {{{ sub reds
sub reds {
  my @ex = @_;
  my @retlist;
  for my $ex (@ex) {
# r <- 1/(1 + exp(20 - 35 * x))
    my $ret = 1/(1 + exp(20 - 35 * $ex));
    push(@retlist, $ret);
  }
  return(@retlist);
}
# }}}

# {{{ sub greens
sub greens {
  my @ex = @_;
  my @retlist;
  for my $ex (@ex) {
    my $temp = (-0.8 + 6 * $ex - 5 * $ex**2);
    if($temp < 0) { $temp = 0; }
    if($temp > 1) { $temp = 1; }
# g <- pmin(pmax(0, -0.8 + 6 * x - 5 * x**2), 1);
    push(@retlist, $temp);
  }
  return(@retlist);
}
# }}}

# {{{ sub blues
sub blues {
  my @ex = @_;
  my @retlist;
  my @dnorm;
  for my $ex (@ex) {
    push(@dnorm, pdf($ex, 0.25, 0.15))
  }
  my $maxd = max(@dnorm);
  for my $temp (@dnorm) {
    push(@retlist, $temp / $maxd);
  }
# b <- dnorm(x, 0.25, 0.15)/max(dnorm(x, 0.25, 0.15))
  return(@retlist);
}
# }}}

# {{{ pdf, cdf

my $SQRT2PI = 2.506628274631;

sub pdf {
  my ( $x, $m, $s ) = ( 0, 0, 1 );
  $x = shift if @_;
  $m = shift if @_;
  $s = shift if @_;
  my $SQRT2PI = 2.506628274631;

  if( $s <= 0 ) {
    croak( "Can't evaluate Math::Gauss:pdf for \$s=$s not strictly positive" );
  }

  my $z = ($x-$m)/$s;

  return exp(-0.5*$z*$z)/($SQRT2PI*$s);
}

sub cdf {
  my ( $x, $m, $s ) = ( 0, 0, 1 );
  $x = shift if @_;
  $m = shift if @_;
  $s = shift if @_;

  # Abramowitz & Stegun, 26.2.17
  # absolute error less than 7.5e-8 for all x

  if( $s <= 0 ) {
    croak( "Can't evaluate Math::Gauss:cdf for \$s=$s not strictly positive" );
  }

  my $z = ($x-$m)/$s;

  my $t = 1.0/(1.0 + 0.2316419*abs($z));
  my $y = $t*(0.319381530
          + $t*(-0.356563782
            + $t*(1.781477937
              + $t*(-1.821255978
                + $t*1.330274429 ))));
  if( $z > 0 ) {
    return 1.0 - pdf( $z )*$y;
  } else {
    return pdf( $z )*$y;
  }
}
# }}}

# {{{ sub repick
sub repick {
  my @dx = @_;
  my $div = 3;
  my @rdx = ($dx[0],$dx[$#dx]);
  my $sectlen = int($#dx / $div);
  my $onedone = 0;
  while($sectlen >= 1) {
    my @pdx = pdx($sectlen, $#dx);
    if($sectlen == 1) {
      $onedone = 1;
# @pdx = reverse @pdx;
    }
    for my $temp (@dx[@pdx]) {
      unless( any {$_ eq $temp} @rdx ) {
        push(@rdx, $temp);
      }
    }
    if($onedone) { last; }
    $div += 2;
    $sectlen = int($#dx / $div);
  }
  return(@rdx);
}
# }}}

# {{{ sub pdx called by repick
sub pdx {
  my $sectlen = shift(@_);
  my $lastdx = shift(@_);
  my @pdx;
  my $sectmult = 1;
  while(1) {
    my $dx = $sectlen * $sectmult;
    $sectmult += 1;
    if($dx > $lastdx) { last; }
    else {
      push(@pdx, $dx);
    }
  }
  return(@pdx);
}
# }}}

# End of subs called by sub richcolors }}}
