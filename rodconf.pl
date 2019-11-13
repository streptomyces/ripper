#!/usr/bin/perl
use 5.14.0;
if($ARGV[0] !~ m/\D/) {
unshift(@ARGV, "confs/default.conf");
}
my $cnf = $ARGV[0];

open(my $cnh, "<", $cnf);
my @lines;
while(my $line = readline($cnh)) {
chomp($line);
push(@lines, $line);
}
close($cnh);
if($ARGV[1] and $ARGV[2]) {
  my $fetch = $ARGV[1];
  my $fetchdist = $ARGV[2];
  open(my $cnw, ">", $cnf);
  my $oldfh = select($cnw);
  for my $line (@lines) {
    if($line =~ m/^int FETCH_N/) {
      my $newline = replace($line, $fetch);
      print("$newline\n");
    }
    elsif($line =~ m/^int FETCH_DISTANCE/) {
      my $newline = replace($line, $fetchdist);
      print("$newline\n");
    }
    else {
      print("$line\n");
    }
  }
  close($cnw);
  select($oldfh);
}
else {
print("### Current values ###\n");
for my $line (@lines) {
  if($line =~ m/^int FETCH_N|^int FETCH_DISTANCE/) {
    print("$line\n");
  }
}
print <<"EOT";

Change rodeo2 configuration for number of CDS to fetch
and the distance allowed to fetch them from. Both numbers
need to be specified even if you wish to change only one
of the values.

Usage:

 rodconf.pl <number to fetch> <distance to fetch from>

Examples:

 rodconf.pl 15 500

 rodconf.pl 8 200

EOT
}
exit;


sub replace {
  my $line = shift(@_);
  my $val = shift(@_);
  my @ll = split(/\s+/, $line);
  $ll[2] = $val;
  my $retline = join(" ", @ll);
  return($retline);
}
     


