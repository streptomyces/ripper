use 5.14.0;
use File::Find;
use File::Basename;
use File::Copy;

my %ffoptions = (
wanted => \&onfind,
no_chdir => 1
); 

my $dir;
if($ARGV[0]) { $dir = $ARGV[0]; }
else { $dir = "."; }
my $pat;
if($ARGV[1]) {
  $pat = $ARGV[1];
}

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
            # print(join("\t", @dl, $jdn, $dlen, $dl[1]), "---\n");
            print(join("\t", @dl, $dlen, $dl[1]), "    ---\n");
            copy($fp, "rodeohtml/" . $dl[1] . ".html");

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


