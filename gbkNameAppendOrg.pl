#!/usr/bin/perl
use 5.14.0;
use utf8;
use Carp;
use lib qw(/Users/nouser/perllib);
use File::Basename;
use Sco::Common qw(tablist linelist tablistE linelistE tabhash tabhashE tabvals
    tablistV tablistVE linelistV linelistVE tablistH linelistH
    tablistER tablistVER linelistER linelistVER tabhashER tabhashVER);
use File::Spec;
use File::Path qw(make_path remove_tree);
use File::Copy;

# {{{ Getopt::Long
use Getopt::Long;
my $conffile = qq(local.conf);
my $indir = qq(rideout);
my $errfile;
my $runfile;
my $testCnt = 0;
our $verbose;
my $skip = 0;
my $help;
GetOptions (
"conffile:s" => \$conffile,
"indir:s" => \$indir,
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

 perl changeme.pl -outfile out.txt -- inputfile1 inputfile2

Note that input files are always specified as non-option arguments.

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
  croak("$outdir does not exist and could not be made either");
}

# {{{ Cycle through all the infiles.
for my $infile (@infiles) {
my ($noex, $dir, $ext)= fileparse($infile, qr/\.[^.]*/);
my $bn = $noex . $ext;
# tablistE($infile, $bn, $noex, $ext);

open(my $ifh, "<$infile") or croak("Could not open $infile");
my $lineCnt = 0;
if($skip) {
for (1..$skip) { my $discard = readline($ifh); }
}
# local $/ = ""; # For reading multiline records separated by blank lines.
while(my $line = readline($ifh)) {
chomp($line);
if($line =~ m/^SOURCE/) {
  my @ll=split(/\s+/, $line, 2);
  my $org = $ll[1];
  $org =~ s/[().,]+/ /g;
  $org =~ s/ {2,}/ /g;
  $org =~ s/ /_/g;
  $org =~ s/\//_/g;
  my $newname = $org . "_" . $noex . ".gbk";
  my $newpath = File::Spec->catfile($outdir, $newname);
  linelist("Copying $infile to $newpath");
  copy($infile, $newpath);
  last;
}

$lineCnt += 1;
if($testCnt and $lineCnt >= $testCnt) { last; }
if($runfile and (not -e $runfile)) { last; }
}
close($ifh);
}
# }}}

exit;

# Multiple END blocks run in reverse order of definition.
END {
close(STDERR);
close(ERRH);
# $handle->disconnect();
}

