#!/usr/bin/perl
use 5.14.0;
use utf8;
use open ':encoding(UTF-8)'; # perldoc open.
# Above makes both input and output
# encodings to be UTF-8.
use Carp;
use File::Basename;
use File::Find;
use Getopt::Long;
use File::Spec;
use Cwd; # Exports getcwd.
use File::Copy;
use File::Path qw(make_path remove_tree);
use File::Temp qw(tempfile tempdir);
my $command = join(" ", $0, @ARGV);

# {{{ Getopt::Long
my $conffile = qq(local.conf);
my $outfile;
my $testCnt = 0;
my $skip = 0;
my $header = 0;
my $dryrun;

my $minPPlen  =                 20;
my $maxPPlen  =                120;
my $prodigalScoreThresh  =     7.5;
my $maxDistFromTE  =          8000;
my $fastaOutputLimit  =          3;
my $sameStrandReward  =          5;
my $flankLen  =              17500;
my $scan_signif_thresh =      0.05;
my $apikey;
my $email;


my $help;
GetOptions (
"outfile:s" => \$outfile,
"conffile:s" => \$conffile,
"testcnt:i" => \$testCnt,
"skip:i" => \$skip,
"header:i" => \$header,
"norun|dryrun|dry-run" => \$dryrun,
"help" => \$help,
"ncbiapikey|apikey:s" => \$apikey,
"email:s" => \$email,

"minPPlen|minpplen:i"  =>  \$minPPlen,
"maxPPlen|maxpplen:i"  =>  \$maxPPlen,
"prodigalScoreThresh|prodigalscorethresh:f"  => \$prodigalScoreThresh,
"maxDistFromTE|maxdistfromte:i"  => \$maxDistFromTE,
"fastaOutputLimit|fastaoutputlimit:i"  => \$fastaOutputLimit,
"sameStrandReward|samestrandreward:i"  => \$sameStrandReward,
"flankLen|flanklen:i"  => \$flankLen,
"scansignifthresh|scansignifthresh:f" => \$scan_signif_thresh
);
# }}}

# {{{ POD

=head1 Name

ripper_run.pl

=head2 Examples

 perl code/ripper_run.pl -- microtest.txt

=head2 Description


=cut

# }}}

if($help) {
exec("perldoc $0");
exit;
}

unless($apikey) {
  if($ENV{NCBI_API_KEY} =~ m/\w+/) {
    $apikey = $ENV{NCBI_API_KEY};
  }
}
unless($email) {
  if($ENV{NCBI_API_EMAIL} =~ m/\w+/) {
    $email = $ENV{NCBI_API_EMAIL};
  }
}


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
}
elsif($conffile ne "local.conf") {
linelistE("Specified configuration file $conffile not found.");
}
# }}}

# {{{ Temporary directory and template.
my $tempdir = qw(/tmp);
my $template="ripperunXXXXX";
if(exists($conf{template})) {
  $template = $conf{template};
}
# my($tmpfh, $tmpfn)=tempfile($template, DIR => $tempdir, SUFFIX => '.tmp');
# somewhere later you need to do this
# unlink($tmpfn);
# unlink(glob("$tmpfn*"));
# }}}

# {{{ Open outfile or STDOUT and select it.
my $ofh;
if($outfile) {
  open($ofh, ">", $outfile);
}
else {
  open($ofh, ">&STDOUT");
}
select($ofh);
# }}}

# populate @infiles
my @infiles = @ARGV;
my $infile = $infiles[0];
unless($infile) { $infile = "microtest.txt"; }
unless (-e $infile and -s $infile and -f $infile) {
croak("$infile does not exist or is empty.");
}

my $ripperdir =   qq(/home/work/ripper);
my $outfile   =   qq(/home/mnt/out.txt);
my $distfile  =   qq(/home/mnt/distant.txt);
my $outfaa    =   qq(/home/mnt/out.faa);
my $distfaa   =   qq(/home/mnt/distant.faa);
my $pnadir    =   qq(/home/mnt/pna);

my $coocoutdir = qq(/home/mnt/coocout);
my $ripoutdir = qq(/home/mnt/ripout);
my $orgnamegbkdir = qq(/home/mnt/orgnamegbk);

for my $hcd ($coocoutdir, $ripoutdir, "sqlite", "gbkcache", $orgnamegbkdir, $pnadir) {
  unless(-d $hcd) {
    make_path($hcd);
  }
}

my ($noex, $dir, $ext)= fileparse($infile, qr/\.[^.]*/);
my $bn = $noex . $ext;
open(my $ifh, "<", $infile) or croak("Could not open $infile");

# {{{ Cycle through all the protein accessions in the input file.
# mkcooc.pl and ripper.pl are run for each accession.
my $lineCnt = 0;
while(my $line = readline($ifh)) {
  chomp($line);
  if($line =~ m/^\s*\#/ or $line =~ m/^\s*$/) {next;}
  my $cooExitCode; # Exit code of the system call to mkcooc.pl.
  $line =~ s/\r$//;
  my $acc = $line;
  my $cmd_cooc = File::Spec->catfile($ripperdir, "mkcooc.pl");
  my @args_cooc = ("-outdir");
  push(@args_cooc, File::Spec->catdir($coocoutdir, $acc));
  if($apikey) {
    push(@args_cooc, "-apikey", $apikey);
  }
  if($email) {
    push(@args_cooc, "-email", $email);
  }
  push(@args_cooc, $acc);
  spacelist($cmd_cooc, @args_cooc); linelist();
  unless($dryrun) {
    $cooExitCode = system($cmd_cooc, @args_cooc);
  }

  if($cooExitCode) {
    linelist("Failed to make main_co_occur.csv for $acc");
  }
  else {
    my $cmd_ripper = File::Spec->catfile($ripperdir, "ripper.pl");
    my @args_ripper = (
      "-minPPlen", $minPPlen,
      "-maxPPlen", $maxPPlen,
      "-prodigalScoreThresh", $prodigalScoreThresh,
      "-maxDistFromTE", $maxDistFromTE,
      "-fastaOutputLimit", $fastaOutputLimit,
      "-sameStrandReward", $sameStrandReward,
      "-flankLen", $flankLen
    );
    push(@args_ripper,"-outdir");
    push(@args_ripper, $ripoutdir,
      File::Spec->catfile($coocoutdir, $acc, "main_co_occur.csv"));
    spacelist($cmd_ripper, @args_ripper); linelist();
    unless($dryrun) {
      system($cmd_ripper, @args_ripper);
    }
  }
  $lineCnt += 1;
  if($testCnt and $lineCnt >= $testCnt) { last; }
}
close($ifh);
# }}}

# {{{ The postprocessing scripts. pfam_sqlite.pl, mergeRidePfam.pl, gbkNameAppendOrg.pl.
# pfam_sqlite.pl
my $cmd_pfam_sqlite = File::Spec->catfile($ripperdir, "pfam_sqlite.pl");
my @args_pfam_sqlite = ("-scansignifthresh", $scan_signif_thresh);
spacelist($cmd_pfam_sqlite, @args_pfam_sqlite); linelist();
unless($dryrun) {
  system($cmd_pfam_sqlite, @args_pfam_sqlite);
}

# mergeRidePfam.pl
my $cmd_merge_pfam = File::Spec->catfile($ripperdir, "mergeRidePfam.pl");
my @args_merge_pfam = ("-out", $outfile, "-faa", $outfaa, "-distfile",
  $distfile, "-distfaa", $distfaa);
spacelist($cmd_merge_pfam, @args_merge_pfam); linelist();
unless($dryrun) {
  system($cmd_merge_pfam, @args_merge_pfam);
}

# gbkNameAppendOrg.pl
my $cmd_gbkname_append = File::Spec->catfile($ripperdir, "gbkNameAppendOrg.pl");
my @args_gbkname_append = ("-indir", $ripoutdir);
spacelist($cmd_gbkname_append, @args_gbkname_append); linelist();
unless($dryrun) {
  system($cmd_gbkname_append, @args_gbkname_append);
}
# }}}

# {{{ Protein Network Analysis (PNA).
copy($outfaa, $pnadir);
copy($distfaa, $pnadir);

opendir(my $pdh, $pnadir);
while(readdir $pdh) {
  my $fent = $_;
  if($fent =~ m/^\./) { next; }
  my $path = File::Spec->catfile($pnadir, $fent);
  if(-d $path) {
    if($fent =~ m/GENENET.+/) {
      # remove_tree($path);
      say("remove_tree $path");
    }
  }
}
closedir($pdh);

my $before_pna_dir = getcwd();
chdir($pnadir);
my $cmd_egn = File::Spec->catfile($ripperdir, "egn_ni.pl");
my @args_egn = ("-task", "all");
spacelist($cmd_egn, @args_egn); linelist();
unless($dryrun) {
  system($cmd_egn, @args_egn);
}

my %ffoptions = (
wanted => \&onfind,
no_chdir => 1
); 

my $pnafasdir;
find(\%ffoptions, $pnadir);

my $cyat="cytoattrib.txt";
my $cmd_make_cyat = File::Spec->catfile($ripperdir, "make_cytoscape_attribute_file.pl");
my @args_make_cyat = ("-outfile", $cyat, "-pnafasdir", $pnafasdir, $outfile, $distfile);
spacelist($cmd_make_cyat, @args_make_cyat); linelist();
unless($dryrun) {
  system($cmd_make_cyat, @args_make_cyat);
}

# Collect EGN networks files.
my $cmd_collect_networks =
File::Spec->catfile($ripperdir, "collect_network_genbanks.pl");
spacelist($cmd_collect_networks); linelist();
unless($dryrun) {
  system($cmd_collect_networks);
}

chdir($before_pna_dir);

# }}}

exit;

# {{{ sub onfind
sub onfind {
  my $fp=$_;
# The full path is in $File::Find::name when no_chidir is unset.
  if(-d $fp and $fp =~ m/FASTA$/) {
    $pnafasdir = $fp;
  }
}
# }}}

# {{{ subs tablist and linelist (and their E and H versions).
# spacelist
sub spacelist {
  say(join(" ", @_));
}
sub spacelistE {
  say(STDERR (join(" ", @_)));
}
sub spacelistH {
  my $fh = shift(@_);
  say($fh (join(" ", @_)));
}
# tablist
sub tablist {
  say(join("\t", @_));
}
sub tablistE {
  say(STDERR (join("\t", @_)));
}
sub tablistH {
  my $fh = shift(@_);
  say($fh (join("\t", @_)));
}
# linelist
sub linelist {
  say(join("\n", @_));
}
sub linelistE {
  say(STDERR (join("\n", @_)));
}
sub linelistH {
  my $fh = shift(@_);
  say($fh (join("\n", @_)));
}
# }}}

# Multiple END blocks run in reverse order of definition.
END {
close($ofh);
# $handle->disconnect();
}

__END__


