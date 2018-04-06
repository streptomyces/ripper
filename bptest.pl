#!/usr/bin/perl
use 5.14.0;
use utf8;
use Carp;
use lib qw(/home/sco /home/sco/perllib);
use File::Basename;
use Sco::Common qw(tablist linelist tablistE linelistE tabhash tabhashE tabvals
    tablistV tablistVE linelistV linelistVE tablistH linelistH
    tablistER tablistVER linelistER linelistVER tabhashER tabhashVER);
use File::Spec;
use Sco::NCBI;
use File::Temp qw(tempfile tempdir);
use Bio::SeqIO;
use File::Copy;
use Sco::Html;
use Sco::Genbank;
use Bio::SeqFeature::Generic;
use Data::Dumper;
my $seqio = Bio::SeqIO->new(-file => "vnzp.gbk");
my $seqobj = $seqio->next_seq();
my $binom = $seqobj->species()->binomial();
tablist("Species", $binom);
my $annoColl = $seqobj->annotation();

# print Dumper($annoColl);
# print Dumper($seqobj);


exit; 

