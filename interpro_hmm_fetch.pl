#!/usr/bin/perl
use 5.14.0;
use utf8;
use open ':encoding(UTF-8)'; # perldoc open.
# Above makes both input and output
# encodings to be UTF-8.
use Carp;
use File::Basename;
use Getopt::Long;
use File::Spec;
use File::Temp qw(tempfile tempdir);
my $command = join(" ", $0, @ARGV);
use LWP::UserAgent;

# {{{ Getopt::Long
my $conffile = qq(local.conf);
my $outfile;
my $testCnt = 0;
my $skip = 0;
my $header = 0;
my $help;
GetOptions (
"outfile:s" => \$outfile,
"conffile:s" => \$conffile,
"testcnt:i" => \$testCnt,
"skip:i" => \$skip,
"header:i" => \$header,
"help" => \$help
);
# }}}

# {{{ POD

=head1 Name

changeme

=head2 Examples

 perl code/changeme

=head2 Description



=cut

# }}}

if($help) {
exec("perldoc $0");
exit;
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
my $tempdir = qw(/mnt/volatile);
my $template="replacemeXXXXX";
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
# }}}



# populate @infiles
my @infiles = @ARGV;

my $ua = LWP::UserAgent->new(); # LWP UserAgent.

# {{{ Cycle through all the infiles.
for my $infile (@infiles) {
  my ($noex, $dir, $ext)= fileparse($infile, qr/\.[^.]*/);
  my $bn = $noex . $ext;

# {{{ $ifh.
  my $ifh;
  open($ifh, "<", $infile) or croak("Could not open $infile");
# }}}

# {{{ skip and header
  my $lineCnt = 0;
  if($skip) {
    for (1..$skip) { my $discard = readline($ifh); }
  }
  if($header) {
    for (1..$header) {
      my $hl = readline($ifh);
      chomp($hl);
      my @hl = split(/\t/, $hl);
      tablist(@hl);
    }
  }
# }}}

  # https://www.ebi.ac.uk/interpro/wwwapi//entry/ncbifam/NF038372?annotation=hmm
# {{{ Cycle through all the lines.
  while(my $line = readline($ifh)) {
    chomp($line);
    if($line =~ m/^\s*\#/ or $line =~ m/^\s*$/) {next;}
    my @ll=split(/\t/, $line);
    my $acc = $ll[0];
    my $database = $ll[-1];
    my $database = lc($database);
    my $url = qq(https://www.ebi.ac.uk/interpro/wwwapi//entry/);
    $url .= $database . "/" . $acc . '?annotation=hmm';
    # say($url);
    my $req = HTTP::Request->new(GET => $url);
    my $tempdir = qw(/tmp);
    my $template="interproXXXXX";
    my($tmpfh, $tmpfn)=tempfile($template, DIR => $tempdir, SUFFIX => '.gz');
    close($tmpfh);
    my $res = $ua->request($req, $tmpfn);
    if($res->is_success()) {
      my $noop = 1;
      open(my $zfh, "-|", "gunzip -c $tmpfn") or croak("Could not open $tmpfn");
      while(<$zfh>) {
        print($ofh ($_));
      }
      close($zfh);
      unlink($tmpfn);
    }
    else {
      linelistE("Failed: " . $acc);
    }
    $lineCnt += 1;
    if($testCnt and $lineCnt >= $testCnt) { last; }
  }
  close($ifh);
# }}}
}
# }}} End of cycling through all the infiles.

exit;

# {{{ subs tablist and linelist (and their E and H versions).
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

Opening pipes:

If MODE is |- , the filename is interpreted as a command
to which output is to be piped, and if MODE is -| , the
filename is interpreted as a command that pipes output to us.



