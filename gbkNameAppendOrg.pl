#!/usr/bin/perl
use 5.14.0;
use utf8;
use Carp;
use File::Basename;
use File::Spec;
use File::Path qw(make_path remove_tree);
use File::Copy;

# {{{ Getopt::Long
use Getopt::Long;
my $conffile = qq(local.conf);
my $indir = qq(ripout);
my $errfile;
our $verbose;
my $skip = 0;
my $help;
GetOptions (
"conffile:s" => \$conffile,
"indir:s" => \$indir,
"errfile:s" => \$errfile,
"skip:i" => \$skip,
"verbose" => \$verbose,
"help" => \$help
);
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
#  linelistE("$keyCnt keys placed in conf.");
}
elsif($conffile ne "local.conf") {
linelistE("Specified configuration file $conffile not found.");
}
# }}}

my @infiles = glob($indir . "/*gbk");
my $outdir = $conf{orgnamegbkdir};
make_path($outdir);
unless( -d $outdir) {
  croak("$outdir does not exist and could not be made");
}

# {{{ Cycle through all the infiles.
for my $infile (@infiles) {
  my ($noex, $dir, $ext)= fileparse($infile, qr/\.[^.]*/);
  my $bn = $noex . $ext;
  open(my $ifh, "<$infile") or croak("Could not open $infile");
  my $org;
  while(my $line = readline($ifh)) {
    chomp($line);
    if($line =~ m/^SOURCE/) {
      my @ll=split(/\s+/, $line, 2);
      $org = $ll[1];
      $org =~ s/[().,]+/ /g;
      $org =~ s/ {2,}/ /g;
      $org =~ s/ /_/g;
      $org =~ s/\//_/g;
      last;
    }
  }
  close($ifh);
  unless($org) { $org = "no_org_name"; }
  my $newname = $org . "_" . $noex . ".gbk";
  my $newpath = File::Spec->catfile($outdir, $newname);
  linelist("Copying $infile to $newpath");
  copy($infile, $newpath);
}
# }}}

exit;

# Multiple END blocks run in reverse order of definition.
END {
close(STDERR);
close(ERRH);
# $handle->disconnect();
}

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

