#!/usr/bin/perl
use 5.14.0;
use utf8;
my $ifn = $ARGV[0];
open(IN, "<", $ifn);
while(<IN>) {
my $line = $_;
chomp($line);
$line =~ s/\r$//;
unless($line =~ m/^\s*#/) {
print("$line\n");
}
}

