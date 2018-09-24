use 5.14.0;
use File::Find;
use File::Basename;
use File::Copy;
use File::Spec;

# {{{ Getopt::Long
use Getopt::Long;
my $dir = qq(/home/mnt/rodout);
my $destdir = qq(/home/mnt/rodeohtml);
my $conffile = qq(local.conf);
my $pat = '\.html$';
GetOptions (
"indir|dir=s" => \$dir,
"outdir|destdir=s" => \$destdir,
"pattern|regex:s" => \$pat
);
# }}}



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

if(exists($conf{rodeohtmldir})) {
$destdir = $conf{rodeohtmldir};
}

# Above, value in the configuration file overwrites the value supplied
# on the command line. This is _not_ what is usually done. I am doing
# this here because this is what is written in the README.md file.

my %ffoptions = (
wanted => \&onfind,
no_chdir => 1
); 

my @files;

find(\%ffoptions, $dir);

my @sorted = sort {$a->[1] <=> $b->[1]} @files;

for my $flr (@sorted) {
  print(join("\t", @{$flr}), "\n");
}


# {{{ sub onfind
sub onfind {
  my $fp=$_;
# If the no_chdir option is set then this is the full path. Otherwise,
# this is just the filename.
# The full path is in $File::Find::name when no_chidir is unset.
  if(-d $fp) {return;}  # skip directories.
  else {
# do something here #
    my ($noex, $dir, $ext)= fileparse($fp, qr/\.[^.]*/);
    my $fn = $noex . $ext;
    if($pat) {
      if($fn =~ /$pat/) {
        my @stat = stat($fn);
        my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
            $atime,$mtime,$ctime,$blksize,$blocks) = stat($fp);
            print("$dir\n");
            my @dl = split(/\//, $dir);
            my $dlen = scalar(@dl);
            # my $jdn = pop(@dl);
            # print(join("\t", @dl, $jdn, $dlen, $dl[$#dl]), "---\n");
            print(join("\t", @dl, $dlen, $dl[$#dl]), "    ---\n");
            copy($fp, File::Spec->catfile($destdir, $dl[$#dl] . ".html"));

        # push(@files, [$fp, $size]);
      }
    }
    else {
      my @stat = stat($fn);
      my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
          $atime,$mtime,$ctime,$blksize,$blocks) = stat($fp);
      push(@files, [$fp, $size]);
    }
  }
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

