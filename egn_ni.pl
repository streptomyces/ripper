#!/usr/bin/perl

#Copyright (C) 2013 Sebastien Halary

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>

use 5.14.0;
use Carp;
use POSIX qw(floor ceil);
use Scalar::Util qw(looks_like_number);
use File::Basename;
use File::Spec;

# {{{ Getopt::Long
use Getopt::Long;
my $ecp = qq(10,40,40,14,5,50); # edge calculation parameters.
my $task;
my $progind;
my $help;
GetOptions (
"task:s" => \$task,
"progress" => \$progind,
"ecp|edgecalc:s" => \$ecp,
"help" => \$help
);
# }}}

# {{{ POD

=head1 Name

egn.1.0.plus.pl

=head2 Examples

Tasks should be run in the following order

 perl code/egn.1.0.plus.pl -task check
 perl code/egn.1.0.plus.pl -task blast
 perl code/egn.1.0.plus.pl -task edge
 perl code/egn.1.0.plus.pl -task net
 
Or

 perl code/egn.1.0.plus.pl -task all

The above commands assume that the data (.faa file) is in the
current directory and this script is in the subdirectory named
C<code> in the current directory. Please modify the command
according to your data and script locations. I<EGN> recommends
that data be in the current directory.

Below, to enable I<EGN> progress messages

 perl code/egn.1.0.plus.pl -progress -task all

=head2 Description

I<EGN> modified for non-interactive use.

Data is fasta files in the current directory. Intermediate files
are also written in the current directory. The result files are
written in a directory named C<GENENET_*>.
For example, C<GENENET_10.40.40.0.0>

=head2 Options

=over 2

=item -task

Required. Alternatives are C<check, blast, edge, net> and C<all>.
Unless C<all> is being used, these tasks should be carried out
in the order C<check, blast, edge, net> because earlier tasks
produce output files which as input for later tasks. If C<all> is
used then all the tasks are carried out in the proper order.

=item -progress

This is a boolean option (disabled by default) which allows
I<EGN> progress messages to be printed. If this is not specified
then I<EGN> progress messages are suppressed.

=item -ecp or -edgecalc

String. This string has to consist of 6 comma separated integers
without any spaces. For example, the default is shown below.

 -ecp 10,40,40,14,5,50

The 6 numbers are described by I<EGN> as below.

 1. E-value threshold
 2. Hit identity threshold
 3. Hit covers at least [0-100]% of the shortest sequence
 4. Minimal hit length in nucleic acids (/ by 3 for amino-acids)
 5. Best-reciprocity: sequences in top [0-100]% of the best E-value
 6. Hit covers at least [0-100%] of both sequences

=back

=head2 Dev notes (ignore)

Only C<genetw()> has been modified. C<genomnetw()> has not been modified.
C<blat()> has also been left untouched because I don't have I<blat> on
my machine.

Below is a list of calls determined by C<mapcalls.pl>. Numbers may not be
correct, especially from C<MAIN>.

 MAIN               genetw                 4
 MAIN               genomnetw              2
 MAIN               checkFiles             3
 MAIN               blast                  3
 MAIN               blat                   1
 MAIN               quickPrepTables        3
 MAIN               slowPrepTables         1
 MAIN               linelistE              5
 pilot              printTitle             1
 pilot              pilot                  2
 checkFiles         _findExactSample       1
 checkFiles         _findAttributes        1
 checkFiles         printTable             2
 getConfig          createConfig           1
 blast              getConfig              1
 blast              getNSeq                4
 blat               getConfig              1
 blat               splitFastaFile         2
 submenu            printTitle             1
 quickPrepTables    getConfig              1
 quickPrepTables    getNLine               1
 slowPrepTables     getConfig              1
 slowPrepTables     submenu                1
 slowPrepTables     getNLine               3
 simpleLink         _sl                    1
 genomeSimpleLink   _sl                    1
 _sl                _sl                    1
 genetw             printTitle             1
 genetw             simpleLink             1
 genetw             getNGroup              1
 genetw             _rsd                   3
 genomnetw          submenu                2
 genomnetw          printTitle             1
 genomnetw          simpleLink             1
 genomnetw          genomeSimpleLink       1

=cut

# }}}

unless($task) {
exec("perldoc $0");
exit;
}


my @edgeCalcParams = split(/,|;/, $ecp);
unless(scalar(@edgeCalcParams) == 6) {
  my $parnum = scalar(@edgeCalcParams);
  my $croakmsg = qq/Exactly 6 edges calculation parameters are required./;
  $croakmsg = qq/You have provided $parnum./;
  croak($croakmsg);
}

# Need to know the directory in which the script lives because
# configuration files are looked for in the same directory.
my($noex, $execdir, $ext) = fileparse($0, qr/\.[^.]*/);
my $configfile = File::Spec->catfile($execdir, $noex . ".config");

# {{{ $MENU
my $MENU=([
    "EGN Main Menu",
    'Create the input files' =>  \&checkFiles,
        'Similarity search in sequences' => [
        "Local alignment software\n",
        'BLAST' => \&blast,
        'BLAT' => \&blat,
        'Back to Main menu' => undef,
    ],
        'Prepare Edges File' => [
                "Optimization for Edges File\n",
                "Quicker (requires a maximum of RAM)" => \&quickPrepTables,
                "Slower (less RAM, but more free disc space)" => \&slowPrepTables,
        'Back to Main menu' => undef,
        ],
        'Networks' => [
                "Network type\n",
                'Gene network' => \&genetw,
                'Genome network' => \&genomnetw,
                'Quit' => -1
        ],
    'Exit' => -1,
]);
# }}}

if($task =~ m/^ch/i) {
unlink(glob("seq*"));
unlink(glob("proteic*"));
checkFiles();
}
elsif($task =~ m/^bl|^se|^simi/i) {
unlink(glob("*.log"));
# unlink("align.pp.out"); # Not needed. blast() does unlink *.out.
blast();
}
elsif($task =~ m/^ed/i) {
  print(join("\t", @edgeCalcParams), "\n");
  quickPrepTables();
}
elsif($task =~ m/^net/i) {
  genetw();
}
elsif($task =~ m/^all/i) {
  linelistE("1. Checking");
  checkFiles();
  linelistE("2. Similarity searching");
  blast();
  linelistE("3. Calculating edges");
  quickPrepTables();
  linelistE("4. Making network");
  genetw();
  linelistE("Done.");
}

sub linelistPE {
  if($progind) {
    print(STDERR join("\n", @_), "\n");
  }
}
sub linelistE {
    print(STDERR join("\n", @_), "\n");
}


# {{{ sub pilot
sub pilot {
    my $tableRef = shift;
        my @copytab=@{$tableRef};
        my $title = shift(@copytab);

        my (@name, @action);
    ($name[@name], $action[@action]) = splice @copytab, 0, 2
      while @copytab;

        while(1){
                print `clear`;
                printTitle($title);
                print "\n";
                print map "$_. $name[$_ - 1]\n", 1 .. @name;
                print "\n";
                print '> ';

                chomp(my $choice = readline *STDIN);

                if ($choice and $choice > 0 and $choice <= @action) {
                        
                        $choice-=1;
                        my $do_action = $action[$choice];
                
                        pilot($MENU) unless defined $do_action;

                        if($do_action==-1){exit(0)}

                        if('CODE' eq ref $action[$choice]){
                                $do_action->() ;
                        }
                        pilot($action[$choice]) if 'ARRAY' eq ref $action[$choice];

                } else {
                        print "Invalid choice: $choice\n";
                }
   }
}
# }}}

# caracteres acceptes pour les identifiants: alphanumerique,_ et .
# caracteres acceptes pour les samples : tous
# caracteres acceptes pour les attributs : tous sauf #
# {{{ sub checkFiles
sub checkFiles {
  my @fastas;
  my %resume;
  my $dbflag=0;
  my $nucFiles;
  opendir(DIR,".");
  my @files = readdir(DIR);
  @fastas = grep(/\.fna$/,@files);
  $nucFiles = @fastas;
  @fastas = (@fastas, grep(/\.faa$/,@files));
  $dbflag=1 if grep(/\.db(n|p)/,@files);
  closedir(DIR);

  die "Input files should be renamed .fna or .faa\n" if(!@fastas);
#       printTable("File", "Sequences", "Samples", "Attributes");
#for(@fastas){print $_."\n";}

  my $gi;
  my $id;my $c=0;
  my (%gi2id,%sample,%attr,%seq);
  for my $i (1..@fastas){
    my $file=$fastas[$i-1];
    my $type = 'p';
    $type = 'n' if($i<=$nucFiles);
    my (%nattr,%nsamp);
    open(IN,$file) or die "problem openning $file!\n";
    while(my $line=<IN>){
      if($line=~/^>/){
        if($line=~/>([A-Z])+\|((\w|\.)+)(\||\s|\[)/i){
          $gi=$2;
          $c++;
          $id=$type.$c;
          $gi2id{$id}=$gi;                                
          my $samp=_findExactSample($line);
          $nsamp{$samp}++;                                
          push(@{$sample{$samp}},$id);
          my @attributes=_findAttributes($line);
          $nattr{scalar(@attributes)}++;
          push(@{$attr{$_}},$id) for(@attributes);
          $seq{$file}->{$id}='';
        }
        else{
          chomp($line);
          die(
              "\nWrong format for sequence \"$line\" header in $file!
              The correct header format must consist in:                                             
              >tag|seqID|additional information [sample] #attribute1 #attribute2 #...

              - tag must be a word ([a-z] or _). Typically gi, emb,ref, or lcl.
              - SeqID may contain [a-z], [0-9], \".\" and \"_\".
              - additional information may contain any character except \"\#\", \"[\" and \"]\".
              - sample may contain any character except \"\#\", \"[\" and \"]\" but have to be surrounded by \"[\" and \"]\".
              - attributes may contain any character except \"\#\", \"[\" and \"]\" but have to be preceded by a \"\#\".
              additional informations, sample and attributes are optionnal.\n\n"); 
        }
      }
      else{
        chomp($line);
        if($line!~m/^([A-Z]|-|\*|\s)*$/i){
          $line=~s/[A-Z]|-|\*|\s//ig;
          my %c;                                  
          $c{chop($line)}++ while($line);
          my $label=join(",",sort keys %c);
          die "Wrong character(s) ($label) in sequence $gi ($file):\n";
        }
        $seq{$file}->{$id}.=$line;

      }
    }
#determiner le nombre d'attributs par fichier
    my @attrange = sort { return $a <=> $b } keys %nattr;
    my $abstrattr;
    if(scalar(@attrange)==1){$abstrattr=$attrange[0];}
    else{ $abstrattr = $attrange[0]."-".$attrange[$#attrange];}
#IMPRIMER       FILE|NB_HEADER|NB_SAMPLE|NB_ATTRIBUTES_PAR_SEQUENCES[]
    push(@{$resume{$file}},(my $a= keys %{$seq{$file}}),(my $b= keys %nsamp), $abstrattr);

  }

  if($progind) {
    print "\n";
    printTable("File", "Sequences", "Samples", "Attributes");
    foreach my $key(keys %resume){
      printTable($key,$resume{$key}[0],$resume{$key}[1],$resume{$key}[2]);
    }
  }

#User's checking point  
  my $choice='Y';
  while($choice !~/Y|N/i){
    print "\nWould you like to proceed with this data? (y/n)\n>";   
    chomp($choice = readline *STDIN);
    return(undef) unless ($choice=~/Y/i);
  }       

#print the input files
##files 1: dbn,dbp      
#file 2: id,gi,length => en se servant du tableau @gi2id
#file 3: sample->id list, attribute-n -> id list
#       #### => On dumpe les fichiers fastas dans 1 fichier dbn et 1 fichier dbd
  open(FNA,">nucleic.dbn");
  open(FAA,">proteic.dbp");
  open(INF,">seq.info");
  open(EMPTY,">empty.log");

  for my $i (1..@fastas){
    my $outhandle = *FAA;
    if($i<=$nucFiles){
      $outhandle = *FNA;
    }

    foreach my $id (keys %{$seq{$fastas[$i-1]}}){
      my $sequence=$seq{$fastas[$i-1]}->{$id};
      if(length($sequence)==0){
        print EMPTY "id: ".$gi2id{$id}." file: $fastas[$i-1]\n";
      }
      else{
        print $outhandle ">$id\n".$sequence."\n";
        print INF $id."\t".$gi2id{$id}."\t".length($sequence)."\t\n";
      }
    }
  }
  close(FNA);
  close(FAA);
  close(INF);
  close(EMPTY);
  if(-z "empty.log"){unlink "empty.log";}
  else{
    print "\nWarning: Empty sequences were detected and reported in empty.log\n";
  }
  if(-z "nucleic.dbn"){unlink "nucleic.dbn";}
  if(-z "proteic.dbp"){unlink "proteic.dbp";}

  open(ATT,">seq.att");
  print ATT "#SAMPLE\n";
  foreach my $sample (keys %sample){
    print ATT $sample."|#|".join(',',@{$sample{$sample}})."\n";             
  }
  print ATT "#ATTRIB\n" if(keys %attr);
  foreach my $att (keys %attr){           
    print ATT ($att,"|#|",join(',',@{$attr{$att}}),"\n");
  }
  close(ATT);

  if($progind) {
  print "\nData file(s) created.\n";
  }
# <STDIN>;
  return 0;
}
# }}}

# {{{ sub printTable
sub printTable {
        my ($file,$nseq,$nsample,$natt)=@_;
    format TABLE =
+---------------------------------------------------------------------+
| @|||||||||||||||||||||||||| | @|||||||||| | @||||||||| | @||||||||| |
$file,$nseq,$nsample,$natt
+---------------------------------------------------------------------+
.
        $~ = 'TABLE';
    write();
}
# }}}

# {{{ sub printTitle
sub printTitle {
        my $title=shift;
    format TITLE =
 #################################
 # @|||||||||||||||||||||||||||| #
$title
 #################################
.
        $~ = 'TITLE';
    write();
}
# }}}

# {{{ sub _findExactSample
sub _findExactSample {

        my $string=shift;
        my $char='';
        my $sample='';
        my $score=1;
        my $l=1;
        
        if($string=~/\[/ && $string=~/\]/){
                while($char ne "\]"){
                        $char=chop($string);
                }
                while($score!=0){
                        $char=chop($string);
                        $sample=$char.$sample;
                        if($char eq "\]"){
                                $score++;
                        }
                        if($char eq "\["){
                                $score--;
                        }
                }
                $sample=~s/\[//;
        }
        return $sample;
}
# }}}

# {{{ sub _findAttributes
sub _findAttributes {
        chomp(my $string=shift);
        my @attributes=split(/\s*#\s*/,$string);
        shift(@attributes);
        return @attributes;
}
# }}}

# {{{ sub getConfig
sub getConfig {
        my $prog=shift;
        my %options;
        createConfig($configfile) if(! -e $configfile);
        open(CFG,"<", $configfile) or
        die ("unable to find $configfile: $!\n");
        while((my $line=<CFG>)!~m/begin $prog;/i){}
        while((my $line=<CFG>)!~m/end $prog;/i){
                if($line!~m/^(#|\s)/){
                        chomp($line);
                        my @tmp=split(/\s*=\s*/,$line);
                        if($tmp[1]!~m/def/){
                                $options{$tmp[0]}=$tmp[1];
                        }
                }
        }
        return %options;
}
# }}}

# {{{ sub createConfig
sub createConfig {
        my $path=shift;
        open(CFG,">$path") or warn ("unable to create $path: $!");
        print CFG "#############################################################################################\n";
        print CFG "#                                                                                           #\n";
        print CFG "#        This file contains options of alignement tools available in EGN                    #\n";
        print CFG "#        It was written from documentation of:                                              #\n";
        print CFG "#        -BLAST  Altschul, S.F., Gish, W., Miller, W., Myers, E.W. & Lipman, D.J. (1990)    #\n";
        print CFG "#            \"Basic local alignment search tool.\" J. Mol. Biol. 215:403-410               #\n";
        print CFG "#        -BLAT   BLAT--the BLAST-like alignment tool. Kent WJ.                              #\n";
        print CFG "#                Genome Res. 2002 Apr;12(4):656-64.                                         #\n";
        print CFG "#                                                                                           #\n";
        print CFG "#    -Please verify that your PATH is properly configured for each of them                  #\n";
        print CFG "#    -Edit these values to modify their usage in EGN                                        #\n";
        print CFG "#                                                                                           #\n";
        print CFG "#############################################################################################\n\n";

        print CFG "#################################\n";
        print CFG "#        BLAST+ options         #\n";
        print CFG "#################################\n";
        print CFG "begin BLAST;\n\n";

        print CFG "#Expectation value (E) threshold for saving hits Default = 10\n";
        print CFG "-evalue=1e-05\n\n";

        print CFG "#Number of threads (CPUs) to use in the BLAST search. default = 1\n";
        print CFG "-num_threads=4\n\n";

        print CFG "#Cost to open a gap (-1 invokes default behavior) [Integer]    default = -1\n";
        print CFG "-gapopen=def\n\n";

        print CFG "#Cost to extend a gap (-1 invokes default behavior) [Integer]    default = -1\n";
        print CFG "-gapextend=def\n\n";

        print CFG "#Number of database sequences to show one-line descriptions for (V) [Integer]   default = 500\n";
        print CFG "-num_descriptions=def\n\n";

        print CFG "end BLAST;\n";
        print CFG "#\n\n";

        print CFG "#####################################\n";
        print CFG "#            BLAT options           #\n";
        print CFG "#####################################\n";
        print CFG "begin BLAT;\n\n";

        print CFG "#external file of over-occurring 11-mers\n";
        print CFG "#-ooc=BLATPath/11.ooc\n\n";

        print CFG "#If set to 1 this allows one mismatch in tile and still triggers an alignments.  Default is 0.   \n"; 
        print CFG "-oneOff=def   \n\n";

        print CFG "#-minScore=N sets minimum score. This is the matches minus the mismatches minus some sort of gap penalty.  Default is 30\n";
        print CFG "-minScore=def\n\n";

        print CFG "#-maxGap=N   sets the size of maximum gap between tiles in a clump.  Usually set from 0 to 3.  Default is 2. Only relevant for minMatch > 1.\n";
        print CFG "-maxGap=def\n\n";

        print CFG "#Number of threads (this option is not a legacy blat parameter) default=1 \n";
        print CFG "-num_threads=2\n\n";

        print CFG "end BLAT;\n";

        close(CFG);
}
# }}}

# {{{ sub blast
sub blast {
        my $choice='Y';
        my %options=getConfig("BLAST"); # call getConfig
        my $dbsoft="makeblastdb";
        my ($nucFile,$protFile);
        my $nfile=0;
        unlink glob "*.out";

#         #Parameters display
#         printTitle "BLAST parameters:";
#         foreach (sort keys %options){
#                 print "\t$_ = $options{$_}\n";
#         }
#         print "\t-Other parameters are setup to default values\n";
#                 while($choice!~/y|q/i){ 
#                 print "\n\tAre these parameters correct (y) ? \n\tElse you can edit them in:\n\t$execdir/egn.plus.config (q):  ";
#                 $choice=readline *STDIN;
#         }
#
#         exit(0) if ($choice=~/q/i);
#         print `clear`;


# {{{ if(-e ($nucFile="nucleic.dbn"))
if(-e ($nucFile="nucleic.dbn")) {
  $nfile++;
  print "\n#Nucleic BLAST database creation using $dbsoft...\n";
  open(my $oldout, ">&STDOUT")     or die "Can't dup STDERR: $!";
  open(STDOUT,">$dbsoft.log");
  die($!) if(system($dbsoft,"-in",$nucFile,"-dbtype","nucl"));
  open(STDOUT, ">&", $oldout) or die "Can't dup \$oldout: $!";
  print "done.\n\n";

  print "#BLASTN... ";
  my @command= ("blastn","-task","blastn","-query",$nucFile,"-db",$nucFile, "-outfmt",6, %options);

#Output configuration
  open(my $olderr, ">&STDERR")     or die "Can't dup STDERR: $!";
  open(STDERR,">blastn.log");
  open(OUT,">align.nn.out");
  select STDOUT; $| = 1;

  defined(my $pid = open(TO_KID, "-|",@command)) or die "can't fork: $!";
  if($pid){
    my $prevQ='';
    my $count=1;
    my $nq=ceil((getNSeq($nucFile))/100); # call getNSeq
    my $percent=0;

    while(<TO_KID>){
      if($_=~/^(\w+)\t/){
        if($1 ne $prevQ){
          if(($count++ % $nq)==0){
            $percent++;
            print $percent."%";
            print "\b" x length($percent."%");
          }
          $prevQ=$1;
        }
      }
      print OUT $_;
    }
    print "100%\ndone.\n";
  }

  wait();
  open(STDERR, ">&", $olderr) or die "Can't dup \$olderr: $!";
  close(OUT);
}
# }}}

# {{{ if(-e ($protFile="proteic.dbp"))
if(-e ($protFile="proteic.dbp")) {
  $nfile++;
  if($progind) {
  print "\n#Proteic BLAST database creation using $dbsoft...\n";
  }

  open(my $oldout, ">&STDOUT")     or die "Can't dup STDERR: $!";
  open(STDOUT,">$dbsoft.log");
  die($!) if(system($dbsoft,"-in",$protFile,"-dbtype","prot"));
  open(STDOUT, ">&", $oldout) or die "Can't dup \$oldout: $!";
  if($progind) {
  print "done.\n\n";
  }

  if($progind) {
  print "\n#BLASTP... ";
  }
  my @command=("blastp","-task","blastp","-query",$protFile,"-db",$protFile,"-outfmt",6, %options);       

#Output configuration
  open(my $olderr, ">&STDERR")     or die "Can't dup STDERR: $!";
  open(STDERR,">blastp.log");
  open(OUT,">align.pp.out");
  select STDOUT; $| = 1;

  defined(my $pid = open(TO_KID, "-|",@command)) or die "can't fork: $!";
  if($pid){
    my $prevQ='';
    my $count=1;
    my $nq=ceil(getNSeq($protFile)/100); # call getNSeq 
    my $percent=0;

    while(<TO_KID>){
      if($_=~/^(\w+)\t/){
        if($1 ne $prevQ){
          if(($count++ % $nq)==0){
            $percent++;
            if($progind) {
            print $percent."%";
            print "\b" x length($percent."%");
            }
          }
          $prevQ=$1;
        }
      }
      print OUT $_;
    }
    if($progind) {
    print "100%\ndone.\n";
    }
  }

  wait();
  open(STDERR, ">&", $olderr) or die "Can't dup \$olderr: $!";
  close(OUT);
}
# }}}
        
        if(!$nfile) {
                print "\n\tNo datafiles detected.\n\tYou must create data files before processing alignments.\n";
                print "\nPress a key to continue...";
                <STDIN>;
                return;
        }

# {{{ elsif($nfile==2) 
elsif($nfile==2) {
  print "\n#BLASTX...";

  my @command=("blastx","-query",$nucFile,"-db",$protFile,"-outfmt",6, %options);         
#Output configuration
  open(my $olderr, ">&STDERR")     or die "Can't dup STDERR: $!";
  open(STDERR,">blastnp.log");
  open(OUT,">align.np.out");
  select STDOUT; $| = 1;

  defined(my $pid = open(TO_KID, "-|",@command)) or die "can't fork: $!";
  if($pid){
    my $prevQ='';
    my $count=1;
    my $nq=ceil(getNSeq($nucFile)/100); # call getNSeq
    my $percent=0;

    while(<TO_KID>){
      if($_=~/^(\w+)\t/){
        if($1 ne $prevQ){
          if(($count++ % $nq)==0){
            $percent++;
            print $percent."%";
            print "\b" x length($percent."%");
          }
          $prevQ=$1;
        }
      }
      print OUT $_;
    }
    print "100%\ndone.\n";
  }
  wait();

  print "\n#TBLASTN...";
#/usr/bin/blastn -task blastn -db seqs.fna -query seqs.fna -num_threads 4 -outfmt 6
  @command=("tblastn","-query",$protFile,"-db",$nucFile,"-outfmt",6, %options);           
  defined($pid = open(TO_KID, "-|",@command)) or die "can't fork: $!";
  if($pid){
    my $prevQ='';
    my $count=1;
    my $nq=(getNSeq($protFile))/100; # call getNSeq
    my $percent=0;

    while(<TO_KID>){
      if($_=~/^(\w+)\t/){
        if($1 ne $prevQ){
          if(($count++ % $nq)==0){
            $percent++;
            print $percent."%";
            print "\b" x length($percent."%");
          }
          $prevQ=$1;
        }
      }
      print OUT $_;
    }
    print "100%\ndone.\n";
  }

  wait();
  open(STDERR, ">&", $olderr) or die "Can't dup \$olderr: $!";
  close(OUT);
}
# }}}
        unlink glob ("*dbn.* *dbp.*"); # Possibly bad glob specification.
        if($progind) {
          print "\nAll alignments processed\n";
        }

}
# }}} # end of sub blast

# {{{ sub getNLine
sub getNLine {
        my $file=shift; 
        my $nseq=0;
        my $buffer=0;
        open(FILE, $file) or die "Can't open `$file': $!";
    while (sysread FILE, $buffer, 4096) {
           $nseq += ($buffer =~ tr/\n//);
    }
        close FILE;
        return $nseq;
}
# }}}

#fonction pour compter les lignes super vite:
# {{{ sub getNSeq
sub getNSeq {
        my $file=shift; 
        my $nseq=0;
        my $buffer=0;
        open(FILE, $file) or die "Can't open `$file': $!";
    while (sysread FILE, $buffer, 4096) {
           $nseq += ($buffer =~ tr/>//);
    }
        close FILE;
        return $nseq;
}
# }}}

#fonction pour compter les lignes super vite:
# {{{ sub getNGroup
sub getNGroup {
        my $file=shift; 
        my $ngp=0;
        my $buffer=0;
        open(FILE, $file) or die "Can't open `$file': $!";
    while (sysread FILE, $buffer, 4096) {
           $ngp += ($buffer =~ tr{/}{});
    }
        close FILE;
        return ($ngp/2);
}
# }}}

# {{{ sub blat
sub blat {
        my $choice='';
        my %options=getConfig("BLAT");
        my @foptions;
        my $nucFile="nucleic.dbn";
        my $protFile="proteic.dbp";
        my $nfile=0;

        print "\n";

        #Parameters display
        printTitle "BLAT parameters:";
        foreach (sort keys %options){
                print "\t$_ = $options{$_}\n";
        }
        print "\t-Other parameters setup to default values\n";
        while($choice!~/y|q/i){ 
                print "\n\tAre these parameters correct (y) ? \n\tElse you can edit them in $configfile (q):  ";
                $choice=readline *STDIN;
        }
        exit(0) if ($choice=~/q/i);

        ###
        my $num_threads=delete $options{"-num_threads"};
        push(@foptions, $_."=".$options{$_}) foreach(keys %options);
        
        if(-e $nucFile){

                if(-e $protFile){
                        my $choice='';
                        print "\n\n\tWarning: Data contain nucleic and proteic sequences.\n\tNucleic sequences wont be aligned with proteic ones.";
                        while($choice!~/y|Y|n|N/){
                                print "\n\tDo you want to continue? (y/n): ";
                                chomp($choice=readline *STDIN);
                                
                        }
                        if($choice=~/n|N/){
                                return 0;
                        }
                }
                print "\n#Nucleic BLAT...\n\n";

                
                my @subFiles;
                if($num_threads>1){
                        print "Preparation of data for parallelization\n";
                        unlink glob "nucleic.dbn.*";
                        unlink glob "tmp.blatn.*";
                        @subFiles=splitFastaFile($nucFile,$num_threads);
                        print "done.\n\n";
                }
                else{
                        $num_threads=1;
                }
                
                open(my $olderr, ">&STDERR") or die "Can't dup STDERR: $!";
                open(STDERR,">blatn.log");
                my @pid;
                for(my $i=0;$i<$num_threads;$i++){
                        push(@pid,my $pid=fork);
                        unless($pid){
                                my @command= ("blat",$nucFile,$nucFile.".".$i,@foptions,"-out=blast8","tmp.blatn.$i");
                                exec(@command) or die ("Problem: ".join("\t",@command)." $!\n");
                                exit(0);
                        }
                }
                
                foreach (@pid) {
                        waitpid($_,0);
                }

                open(OUT,">align.nn.out");
                for(my $i=0;$i<$num_threads;$i++){
                        open IN, "tmp.blatn.$i" or die "unable to open tmp.blatn.$i: $!\n";
                        print OUT while(<IN>);
                        close IN;
                }
                close(OUT);
                unlink glob("tmp.blatn.* nucleic.dbn.*");
                open(STDERR, ">&", $olderr) or die "Can't dup \$olderr: $!";
                print "\ndone.\n";              
        }

###########
# PROTEIC BLAT
###########

        if(-e $protFile){

                print "\n#Proteic BLAT...\n\n";

                if($num_threads>1){
                        unlink glob "proteic.dbp.*";
                        unlink glob "tmp.blatp.*";
                        splitFastaFile($protFile,$num_threads);
                }
                else{
                        $num_threads=1;
                }

                open(my $olderr, ">&STDERR") or die "Can't dup STDERR: $!";
                open(STDERR,">blatp.log");
                my @pid;
                for(my $i=0;$i<$num_threads;$i++){
                        push(@pid,my $pid=fork);
                        unless($pid){
                                
                                my @command= ("blat",$protFile,$protFile.".".$i,"-prot",@foptions,"-out=blast8","tmp.blatp.$i");
                                exec(@command) or die ("Problem: ".join("\t",@command)." $!\n");
                                exit(0);
                        }
                }
                
                foreach (@pid) {
                        waitpid($_,0);
                }

                open(OUT,">align.pp.out");
                for(my $i=0;$i<$num_threads;$i++){
                        open IN, "tmp.blatp.$i" or die "unable to open tmp.blatp.$i: $!\n";
                        print OUT while(<IN>);
                        close IN;
                }
                close(OUT);
                unlink glob("tmp.blatp.* proteic.dbp.*");
                open(STDERR, ">&", $olderr) or die "Can't dup \$olderr: $!";
                print "done.\n\n";      
        }
                #unlink glob ("*dbn.* *dbp.*");
        print "\nAll alignments processed\n\tPress enter to continue...";
        <STDIN>;
}
# }}}

# {{{ sub splitFastaFile
sub splitFastaFile {
        
        my $file=shift;
        my $nF=shift;   
        open(IN,$file) or die "unable to open $file: $!\n";

        my $c=0;
        my $handle=*STDOUT;
        while(my $line=<IN>){
                if($line=~/>/){
                        close(OUT);                     
                        $c++;
                        my $i=$c%$nF;
                        open(OUT,">>$file.$i");
                        $handle=*OUT;
                        
                }
                print {$handle} $line;
        }
        close(IN);
        return map { $file.".".$_ } (0..($nF-1));
}
# }}}

# {{{ sub submenu
sub submenu {
        my $title=shift;
        my @data=@_;
        my (@prop,@value,@isnum,@ispercent);
        ($prop[@prop], $value[@value]) = splice @data, 0, 2 while @data;
        for(0..$#value){
                $isnum[$_]=looks_like_number($value[$_]);
                $ispercent[$_]=(($prop[$_]=~/%/)?1:0);
        }


        my $key='';
        my $nitem=@prop;
        my $clear=`clear`;

        while($key!~/Y|y/){
                print $clear;
                printTitle($title);
                print "\n";
                for(my $i=0;$i<$nitem;$i+=1){
                        print $prop[$i],$value[$i]."\n";
                }
                
                print "\nOk or change a parameter (";
                for(1..$nitem){
                        print $_.", ";
                }
                print "or y): ";
                chomp($key = readline *STDIN);
                
                if(looks_like_number($key) && $key>0 && $key<=$nitem){
                        my $tmp='';
                        
                        if($isnum[$key-1]>0){
                                while(!(looks_like_number($tmp))){
                                        print $prop[$key-1];                            
                                        chomp($tmp = readline *STDIN);
                                }
                                next if($ispercent[$key-1] && $tmp>100);
                                next if($tmp<0);                                
#                               if($tmp>=0){
                                        $value[$key-1]=$tmp;
#                               }
#                               else{next;}

                        }
                        else{
                                if($value[$key-1]=~/y/i){
                                        $value[$key-1]='n';
                                }
                                else{
                                        $value[$key-1]='y';
                                }
                        }
                }
        }
        print "\n";
        return @value;
}
# }}}

# {{{ sub quickPrepTables
sub quickPrepTables  {
  my %options=getConfig("BLAST"); # call getConfig
#  my @args=submenu("Quick Edges File Creation",
#      "1. E-value threshold (>=0) = ", $options{'-evalue'},
#      "2. Hit identity threshold [0-100]% = ", 20,
#      "3. Hit covers at least [0-100]% of the shortest sequence = ", 20,                                      
#      "4. Minimal hit length in nucleic acids (/ by 3 for amino-acids) = ", 75,
#      "5. Best-reciprocity: sequences in top [0-100]% of the best E-value = ", 5,
#      "6. Hit covers at least [0-100%] of both sequences= ", 90
#      );
  my @args = @edgeCalcParams; # Processed from getopt stuff above.
  opendir(DIR,".");
  my @outs=grep(/.out$/,readdir(DIR));
  if(!@outs) {
    croak("You must have alignments before this step");
  }       

  open(INF,"<seq.info") or die "problem openning seq.info!\n";
  my %length;

  while(my @tab=split(/\t/,<INF>)){       
    $length{$tab[0]}=$tab[2];
  }
  close(INF);

  if(@outs==3){
    while($outs[$#outs]!~/np.out$/){
      unshift(@outs,pop(@outs));
    }
  }

  open(TABLE,">edges.table");
  print TABLE "#evalue=$args[0]\t#\%id=$args[1]\t#hitlength=$args[2]\tHl=$args[3]\t\%br=$args[4]\thl=$args[5]\n";

  my $nedges=0;
  for my $m8 (@outs){
    $nedges+=getNLine($m8); # call getNLine
  }
  $nedges=ceil($nedges/100);
  my $c=0;
  my $percent=0;
#
  for my $m8 (@outs) {

    if($m8=~/np.out$/){
      foreach my $seq (keys %length){
        if($seq=~/^n/){
          $length{$seq} = int($length{$seq}/3);
        }
      }               
    }

#               unless(fork) {
  open(M8,"<$m8") or die "problem opening $m8!\n";

  my %exist;
  my $previous_query='';
  my $previous_hit='';
  my $best_evalue;
  my $bhit;
#<M8>;
  while(my @hit=split(/\t/,<M8>)){

    if($progind) {
    if($c%$nedges==0){
      $|=1;
      $percent++;                                     
      my $label="#Analyzed Edges: $percent\%";
      print $label;
      print "\b" x length($label);    
    }
    }

    $c++;

    if( ($hit[0] ne $hit[1]) &&  ((my $newQ=$hit[0] ne $previous_query) || ($hit[1] ne $previous_hit)) ){

      $previous_query=$hit[0];
      $previous_hit=$hit[1];

      my $evalue=$hit[10];
      $evalue=~s/,//;

        if($evalue==0.0){
          $evalue=1e-200;
        }

      if($newQ){
        $best_evalue=$evalue;
        $bhit=1;
      }
      else{ 
        my $ref=log($best_evalue)/log(10);
        my $e=log($evalue)/log(10);
        my $rep=($ref-(($ref*$args[4])/100));
        $bhit=($e<=$rep?1:0);
      }
      my $bhol=( ($hit[3]>=(($length{$hit[0]}/100)*$args[5])) && ($hit[3]>=(($length{$hit[1]}/100)*$args[5])) ) ? 1 :0 ;
      my $min=$length{$hit[0]};
      if($length{$hit[1]}<$min){$min=$length{$hit[1]};}
      my $nia=($hit[3]/100)*$hit[2];
      my $id=sprintf("%.2f", (($nia*100)/$min) );

      if(($evalue<=$args[0]) && ($hit[2]>=$args[1]) &&($id>=$args[2]) && ($hit[3]>=$args[3])){
#ID% #evalue #Best_Reciproc [0-1-2]             0:nobr, 1: br(%), 2:strict br

        if(!$exist{$hit[1]."<>".$hit[0]}){
          push(@{$exist{$hit[0]."<>".$hit[1]}}, $hit[2], $id, $hit[10], $bhit, $bhol);
        }
        else{
          my @data=@{$exist{$hit[1]."<>".$hit[0]}};                                                               
          my $er=$data[1];
          if($hit[10]<$er){
            print TABLE join("\t",$hit[0],$hit[1],$hit[2], $id,$hit[10], (($bhit && $data[2])? 1 : 0),$bhol,"\n");
            delete $exist{$hit[1]."<>".$hit[0]};
            delete $exist{$hit[0]."<>".$hit[1]};
          }
          else{
            print TABLE join("\t",$hit[1],$hit[0], $data[0], $data[1], $data[2], (($bhit && $data[2])? 1 : 0),$bhol,"\n");
            delete $exist{$hit[1]."<>".$hit[0]};
            delete $exist{$hit[0]."<>".$hit[1]};
          }
        }
      }
    }
  }
#print "100%";
  foreach my $hit (keys %exist){
    print TABLE join("\t",(split(/<>/,$hit)),$exist{$hit}[0],$exist{$hit}[1],$exist{$hit}[2],0,$exist{$hit}[4],"\n");
    delete($exist{$hit});
  }
  close(M8);
#               }
#               wait;
  }
  close(TABLE);

  if($progind) {
  print "\nEdges file created.\n";
  # readline *STDIN;
  }
}
# }}}

# {{{ sub slowPrepTables
sub slowPrepTables {
        my %options=getConfig("BLAST");
        my @args=submenu("Slow Edges File Creation",
                        "1. E-value threshold (>=0) = ", $options{'-evalue'},
                        "2. Hit identity threshold [0-100]% = ", 20,
                        "3. Hit covers at least [0-100]% of the shortest sequence = ", 20,                                      
                        "4. Minimal hit length in nucleic acids (/ by 3 for amino-acids) = ", 75,
                        "5. Best-reciprocity: sequences in top [0-100]% of the best E-value = ", 5,
                        "6. Hit covers at least [0-100%] of both sequences= ", 90
        );
        opendir(DIR,".");
        my @outs=grep(/.out$/,readdir(DIR));
        if(!@outs){
                print "\n\tYou must process alignments before this step!\nPress enter to go back to the main menu...";
                <STDIN>;
                return -1;
        }       
        my $nfile=@outs;
        open(INF,"<seq.info") or die "problem opening seq.info!\n";
        my %length;
        while( (my @tab = split(/\t/,<INF>))){
                $length{$tab[0]}=$tab[2];
        }
        close(INF);

        if($nfile==3){
                while($outs[$#outs]!~/np.out$/){
                        unshift(@outs,pop(@outs));
                }
        }

        open(TABLE,">edges.table");

        print TABLE "#evalue=$args[0]\t#\%id=$args[1]\t#hitlength=$args[2]\tHl=$args[3]\t\%br=$args[4]\thl=$args[5]\n";

        

        for my $m8 (@outs){
                
                if($m8=~/np.out$/){
                        foreach my $seq (keys %length){
                                if($seq=~/^n/){
                                        $length{$seq} = int($length{$seq}/3);
                                }
                        }               
                }
                #my $nF=1;
                my $nedges=getNLine($m8);
                $nedges=ceil($nedges/100);
                my $c=0;
                my $percent=0;

                my $pid;
                unless($pid=fork){

                        open(M8,"<$m8") or die "problem opening $m8!\n";
                        open(FOR,">$m8.for") or die "unable to write in $m8.for!\n";
                        open(REW,">$m8.rew") or die "unable to write in $m8.rew!\n"; 
                        my $previous_query='';
                        my $previous_hit='';
                        my $best_evalue;
                        my %exist;
                        my $bhit;
                        
                        while(my @hit=split(/\t/,<M8>)){

                                        if($c%$nedges==0){
                                                $|=1;
                                                $percent++;                                     
                                                my $label="#Analyzed edges of $m8 (first pass): $percent\%";
                                                print $label;
                                                print "\b" x length($label);    
                                        }
                                        $c++;

                                        if( ($hit[0] ne $hit[1]) &&  ((my $newQ= $hit[0] ne $previous_query) || ($hit[1] ne $previous_hit)) ){

                                                $previous_query=$hit[0];
                                                $previous_hit=$hit[1];
                                
                                                my $evalue=$hit[10];
                                                $evalue=~s/,//;
                                                if($evalue==0.0){
                                                        $evalue=1e-200;
                                                }

                                                if($newQ){
                                                        $best_evalue=$evalue;
                                                        $bhit=1;
                                                }
                                                else{ 
                                                        my $ref=log($best_evalue)/log(10);
                                                        my $e=log($evalue)/log(10);
                                                        my $rep=($ref-(($ref*$args[4])/100));
                                                        $bhit=($e<=$rep?1:0);
                                                }
                                                
                                                my $bhol=( ($hit[3]>=(($length{$hit[0]}/100)*$args[5])) && ($hit[3]>=(($length{$hit[1]}/100)*$args[5])) ) ? 1 :0 ;
                                                my $min=$length{$hit[0]};
                                                if($length{$hit[1]}<$min){$min=$length{$hit[1]} ;}

                                                my $nia=($hit[3]/100)*$hit[2];
                                                my $id=sprintf("%.2f", (($nia*100)/$min) );

                                                if(($evalue<=$args[0]) && ($hit[2]>=$args[1]) && ($id>=$args[2]) && ($hit[3]>=$args[3])){
                                                        $exist{$hit[0]."<>".$hit[1]}++;
                                                        if(!$exist{$hit[1]."<>".$hit[0]}){
                                                                print FOR join("\t",$hit[0],$hit[1],$hit[2],$id,$hit[10], $bhit, $bhol,"\n");
                                                        }
                                                        else{
                                                                print REW join("\t",$hit[0],$hit[1],$hit[2],$id,$hit[10], $bhit, $bhol,"\n");
                                                        }
                                                }
                                        }
                                }
                        
                                close(M8);
                                close(FOR);
                                close(REW);
                                undef %exist;
                                print "#Analyzed edges of $m8 (first pass): 100\%\n";
                        
                        }
                        waitpid($pid,0);
                        $nedges=getNLine("$m8.rew");

                        open(REW,"<$m8.rew") or die "unable to open $m8.rew!\n";
                        my %H;
                        $c=0;$percent=0;
                        while(my @tab=split(/\t/,<REW>)){
                                if($c%$nedges==0){
                                        $|=1;
                                        $percent++;                                     
                                        my $label="#Analyzed edges of $m8 (second pass): $percent\%";
                                        print $label;
                                        print "\b" x length($label);    
                                }
                                $c++;

                                push(@{$H{$tab[0]."<>".$tab[1]}},$tab[2],$tab[3],$tab[4],$tab[5],$tab[6]);
                        }
                        close(REW);
                        print "#Analyzed edges of $m8 (second pass): 100\%\n";

                        open(FOR,"<$m8.for");
                        $nedges=getNLine("$m8.for");
                        $c=0;$percent=0;
                        while(my @for=split(/\t/,<FOR>)){

                                if($c%$nedges==0){
                                        $|=1;
                                        $percent++;                                     
                                        my $label="#Analyzed edges of $m8 (third pass): $percent\%";
                                        print $label;
                                        print "\b" x length($label);    
                                }
                                $c++;
                                
                                if($H{$for[1]."<>".$for[0]}){
                                        my @rew=@{$H{$for[1]."<>".$for[0]}};
                                        if($rew[1]<$for[3]){
                                                print TABLE $for[1]."\t".$for[0]."\t".$rew[0]."\t".$rew[1]."\t".$rew[2]."\t".(($rew[3] && $for[5]) ? 1 : 0)."\t".$rew[4]."\n";
                                        }
                                        else{
                                                print TABLE $for[0]."\t".$for[1]."\t".$for[2]."\t".$for[3]."\t".$for[4]."\t".(($rew[3] && $for[5]) ? 1 : 0)."\t".$rew[4]."\n";
                                        }
                                }
                                else{
                                        print TABLE $for[0]."\t".$for[1]."\t".$for[2]."\t".$for[3]."\t".$for[4]."\t0\t".$for[5]."\n";
                                }
                        }
                        print "#Analyzed edges of $m8 (third pass): 100\%\n\n";
                        close(FOR);
                        unlink("$m8.for","$m8.rew");
        }
        close(TABLE);

        print "\nEdges file created.\n\tPress enter to continue...\n";
        readline *STDIN;

}
# }}}

# {{{ sub simpleLink
sub simpleLink {

        #my %param=@_;
        my ($dest,$threshold,$identity,$idshortSeq,$br,$hl)=@_; 
        open(ALI,"<edges.table") or die "cannot open edges.table: $!\n";
        <ALI>;
#       my @args=split(/=|\t/,<ALI>);

        
        if($progind) {
        print "#Edges loading...\n";
        }

        my $clear=`clear`;
        my %edges = ();
        my @data;
        my $c=0;
        my (%evalue,%identity);
        $|=1;
        if($br && $hl){
                while(my @pair = split(/\t/,<ALI>)){
                        $c++;
                        if($c%100000==0){
                                my $label= "\tRead Hits: $c";
                                if($progind) {
                                print $label;
                                print "\b" x length($label);
                                }
                        }
                        if($threshold>=$pair[4] && $identity<=$pair[2] && $idshortSeq<=$pair[3] && $pair[5] && $pair[6]){
                                $edges{$pair[0]}->{$pair[1]}="$pair[2]\t$pair[3]\t$pair[4]\t$pair[6]";
                                $edges{$pair[1]}->{$pair[0]}=1;
                        }
                }
        }
        if($br && !$hl){
                while(my @pair = split(/\t/,<ALI>)){
                        $c++;
                        if($c%100000==0){
                                my $label= "\tRead Hits: $c";
                                if($progind) {
                                print $label;
                                print "\b" x length($label);
                                }
                        }
                        if($threshold>=$pair[4] && $identity<=$pair[2] && $idshortSeq<=$pair[3] && $pair[5]){
                                $edges{$pair[0]}->{$pair[1]}="$pair[2]\t$pair[3]\t$pair[4]\t$pair[6]";
                                $edges{$pair[1]}->{$pair[0]}=1;
                        }
                }
        }
        if(!$br && $hl){
                while(my @pair = split(/\t/,<ALI>)){
                        $c++;
                        if($c%100000==0){
                                my $label= "\tRead Hits: $c";
                                if($progind) {
                                print $label;
                                print "\b" x length($label);
                                }
                        }
                        if($threshold>=$pair[4] && $identity<=$pair[2] && $idshortSeq<=$pair[3] && $pair[6]){
                                $edges{$pair[0]}->{$pair[1]}="$pair[2]\t$pair[3]\t$pair[4]\t$pair[6]";
                                $edges{$pair[1]}->{$pair[0]}=1;
                        }
                }
        }
        else{
                while(my @pair = split(/\t/,<ALI>)){
                        $c++;
                        if($c%100000==0){
                                my $label= "\tRead Hits: $c";
                                if($progind) {
                                print $label;
                                print "\b" x length($label);                    
                                }
                        }
                        if($threshold>=$pair[4] && $identity<=$pair[2] && $idshortSeq<=$pair[3]){
                                $edges{$pair[0]}->{$pair[1]}="$pair[2]\t$pair[3]\t$pair[4]\t$pair[6]";
                                $edges{$pair[1]}->{$pair[0]}=1;
        
                        }
                }
        }
        if($progind) {
        print "\tRead Hits: $c";
        }

        close(ALI);
        if($progind) {
        print "\ndone.\n\n";
        }

        if($progind) {
        print "#Networks organization...\n";
        }

        my %global = ();
        my %local = ();
        my @keys = sort keys(%edges);
        my $n=@keys;
        my $toteltsclasses = 0;
        my %CHG = ();
        my $num=0;

        if($progind) {
        print "\tNodes number: $n\n";
        }
        foreach my $node (@keys){
                
                if(!defined($global{$node})){
                        
                        %local = ();
                        _sl($node, \%edges, \%global, \%local); # lancement de la recursion
                        # affichage

                        my @results = keys(%local);
                        for(@results){
                                push(@{$CHG{$num}},$_);
                        }

                        $num++;
                }
        }
        if($progind) {
        print "\tGroups number: $num\n";
        print "done.\n\n";
        }

        if($progind) {
        print "#Group Files creation...\n";
        }


        open(RES,">$dest") or die "unable to open $dest: $!\n";
        foreach my $group (sort { @{$CHG{$b}} <=> @{$CHG{$a}} } keys %CHG){     
                my $n=@{$CHG{$group}};  
                for my $sc (@{$CHG{$group}}){
                        foreach my $tg (keys %{$edges{$sc}}){
                                if($edges{$sc}->{$tg} ne "1") {                                 
                                        print RES "$sc\t$tg\t$edges{$sc}->{$tg}\t\n";
                                }
                        }
                }
                print RES "//\n";
        }
        close(RES);

        if($progind) {
        print "done.\n\n";
        }
}
# }}}

# {{{ sub genomeSimpleLink
sub genomeSimpleLink {

        my ($dir,$dest,$threshold,$identity,$idshortSeq,$br,$hl)=@_;            
        my %id2gi;
        my %id2sample;
        my %samples;
        my $clear=`clear`;
        print "#Sequences information loading...\n";

        open(INF,"<seq.info") or die "unable to open seq.info: $!\n";
        while(my @tab=split(/\t/,<INF>)){
                $id2gi{$tab[0]}=$tab[1];
        }
        
        open(ATT,"<seq.att") or die "unable to open seq.att: $!\n";
        my $line=<ATT>;
        while(($line=<ATT>)!~/^#ATTRIB/){
                chomp($line);
                my @tab=split(/\|#\|/,$line);
                my $sample=shift @tab;
                @tab=split(/,/,$tab[0]);
                if(!$sample){$sample="NA";}
                $samples{$sample}++;
                for(@tab){
                        $id2sample{$_}=$sample;
                }
                last if(eof);
        }
        close(ATT);

        my $nsample=keys %samples;
        if($nsample<=1){
                print "\n\n##### Construction aborted! #####\n\nEGN did not detect more than 1 genome/sample name.\n";
                print "Check that fasta file headers contain [genome/sample] informations.\n";
                print "\nPress enter to quit...\n";
                readline *STDIN;
                exit 0;
        }
        print "\ndone.\n\n";
        print "#Edges loading...\n";

        my %omelinks;
        my $c=0;
        my $compdir="GENENET_$threshold\.$identity\.$idshortSeq\.$br\.$hl";
        open(GTAB,"<$compdir/groups.table") or die "cannot open $compdir/groups.table: $!\n";
        <GTAB>;

        if ($br){
                while(1){
                        my %tmplinks;
                        while((my $line=<GTAB>)!~/\/\//){
                                my @tab=split(/\t/,$line);
                                $c++;
                                if($c%100000==0){
                                        my $label= "\tRead Hits: $c";
                                        print $label;
                                        print "\b" x length($label);
                                }
#                               if($tab[4]<=$threshold && $tab[2]>=$identity && $tab[3]>= $idshortSeq && $tab[5]){
                                        if((my $samp1=$id2sample{$tab[0]}) ne (my $samp2=$id2sample{$tab[1]})){                                 
                                                my @tmp=sort($samp1,$samp2);
                                                $tmplinks{$tmp[0]}->{$tmp[1]}=1;
                                        }
#                               }
                        }
                        foreach my $key (keys %tmplinks){
                                foreach my $val (keys %{$tmplinks{$key}}){
                                        $omelinks{$key}->{$val}+=1;
                                        $omelinks{$val}->{$key}=-1;
                                }
                        }
                        
                        last if(eof);
                }
        }
        else{
                while(1){
                        my %tmplinks;
                        while((my $line=<GTAB>)!~/\/\//){
                                my @tab=split(/\t/,$line);
                                $c++;
                                if($c%100000==0){
                                        my $label= "\tRead Hits: $c";
                                        print $label;
                                        print "\b" x length($label);
                                }
#                               if($tab[4]<=$threshold && $tab[2]>=$identity && $tab[3]>=$idshortSeq){
                                        if((my $samp1=$id2sample{$tab[0]}) ne (my $samp2=$id2sample{$tab[1]})){                                 
                                                my @tmp=sort($samp1,$samp2);
                                                $tmplinks{$tmp[0]}->{$tmp[1]}=1;
                                        }
#                               }
                        }
                        foreach my $key (keys %tmplinks){
                                foreach my $val (keys %{$tmplinks{$key}}){
                                        $omelinks{$key}->{$val}+=1;
                                        $omelinks{$val}->{$key}=-1;
                                }
                        }
                        last if(eof);
                }
        }
        close(GTAB);
        print "\ndone.\n\n";

        print "#Networks organization...\n";

        my %global = ();
        my %local = ();
        my @keys = sort keys(%omelinks);
        my $n=@keys;
        my $toteltsclasses = 0;
        my %CHG = ();
        my $num=0;

        print "\tNodes number: $n\n";
        foreach my $node (@keys){
                
                if(!defined($global{$node})){
                        
                        %local = ();
                        _sl($node, \%omelinks, \%global, \%local); # lancement de la recursion
                        # affichage

                        my @results = keys(%local);
                        for(@results){
                                push(@{$CHG{$num}},$_);
                        }

                        $num++;
                }
        }
        print "\tGroups number: $num\n";
        print "done.\n\n";

        print "#Group Files creation...\n";


        open(RES,">$dir/$dest") or die "unable to open $dest: $!\n";
        foreach my $group (sort { @{$CHG{$b}} <=> @{$CHG{$a}} } keys %CHG) {    
                my $n=@{$CHG{$group}};
                for my $sc (@{$CHG{$group}}){
                        foreach my $tg (keys %{$omelinks{$sc}}){
                                if($omelinks{$sc}->{$tg} != -1) {               
                                        print RES "$sc\t$tg\t$omelinks{$sc}->{$tg}\t\n";
                                }
                        }
                }
                print RES "//\n";
        }
        close(RES);

        print "done.\n\n";
}
# }}}

sub par_num { return $a <=> $b }


# {{{ sub _rsd
sub _rsd {
        my @data=@_;
        my $nb_seq=@data;
        
        my $sum=0;
        my $sod=0;
        my $rsd=0;
        
        #calcul moyenne
        for(@data){
                $sum+=$_;
        }
        $sum/=$nb_seq;

        #calcul sd
        if($nb_seq>2){
                for(@data){
                        $sod += ($_-$sum)*($_-$sum);
                }
                $sod/=($nb_seq-1);
                $sod=sqrt($sod);
                if($sum!=0){
                        $rsd=sqrt($sod/$sum);
                }
        }
        return ('mean'=>$sum,'sd'=>$sod,'rsd'=>$rsd);
}
# }}}

# {{{ sub _sl
sub _sl {
        my $sommet = $_[0];
        my $refAretes = $_[1];
        my $refGlobal = $_[2];
        my $refLocal = $_[3];
        $$refLocal{$sommet} = 1;
        $$refGlobal{$sommet} = 1;
        my @liste = keys %{$$refAretes{$sommet}};
        my $som;
        foreach $som (@liste){
                 if(!defined($$refLocal{$som})){
                        _sl ($som, $_[1], $_[2], $_[3]);
                }
        }
}
# }}}

# {{{ sub genetw
sub genetw {
  my $clear=`clear`;
#evalue=1e-05   #%id=20 #hitlength=20   Ha=75   %br=5
  open(ALI,"<edges.table") or die "cannot open edges.table: $!\n";
  my @args=split(/=|\t/,<ALI>);
#  my ($threshold,$identity,$idshortSeq,$br,$hl)=submenu("Simple Link Parameters",
#      "1. E-value threshold (<=$args[1]) = ", $args[1],
#      "2. Hit identity threshold [$args[3]-100]% = ", $args[3]        ,
#      "3. Identities must correspond at least to [$args[5]-100]% of the smallest homolog = ", $args[5],
#      "4. Best-reciprocal condition enforced(y/n) = ", 'n',
#      "5. Hit coverage condition enforced(y/n) = ", 'n'
#
#      );
  my ($threshold,$identity,$idshortSeq,$br,$hl) = (@args[1,3,5], "n", "n");
 


      $br= $br eq 'y' ? 1 : 0; 
      $hl= $hl eq 'y' ? 1 : 0;
      my $dir="GENENET_$threshold\.$identity\.$idshortSeq\.$br\.$hl";
      my $gptab="groups.table";       
      
      my $choice='';
      if(-e "$dir/$gptab") {
      while($choice!~/r|R|o|O|q|Q/) {
      print "An analysis with same parameteres was already performed.\n";
      print("Would you like to:\n");
      print("\t- recompute the network (r)\n");
      print("\t- or quit (q)\n>");
      chomp($choice=readline *STDIN);
      }
      if($choice=~/r|R/){
      unlink glob ("$dir/*");
      }
      elsif($choice=~/q|Q/){
      exit(0);
      }
      }
      elsif(-d $dir) {
        $choice = "r";
      }
      else {
        mkdir($dir) or croak("unable to create $dir: $!\n");
        $choice='r';
      }


#      my @outptions=submenu("Output files format",
#          "1. Groups statistics (y/n)= ", "y",
#          "2. Groups composition informations= ", "y",
#          "3. Cytoscape inputs (y/n)= ", "y",
#          "4. Gephi inputs (y/n)= ", "n",
#          "5. Fasta Files (y/n)= ", "n"
#          );

      my @outptions = qw(y y y n y);
      if($choice=~/r/i) {
        if($progind) {
        printTitle("Network computation"); # call printTitle
        print "\n";
        }
        simpleLink("$dir/$gptab",$threshold,$identity,$idshortSeq,$br,$hl); # call simpleLink
      }

      $| = 1;
      my $ntotgp=getNGroup("$dir/$gptab"); # call getNGroup
      $ntotgp=ceil($ntotgp/100);
      my %id2gi;
      my %id2att;

      if(-z "$dir/$gptab"){
        print "\tThere is no connected component.\n\tTry to change simple link parameters.\n\tPress enter to continue...";
        readline *STDIN;
        return(0);
      }

      if($outptions[0]=~/y|Y/){

        if($progind) {
        print "#Groups statistics computation...\n";
        }

        open(GTAB,"<$dir/$gptab") or die "unable to open $dir/$gptab: $!\n";
        open(STAT,">$dir/gpstat.txt");
        print STAT "Group\tSequence Number\tTransitivity\tMean hit identity%\tSD hit identity%\tMean shortest sequence identity%\tSD shortest sequence identity%\tMean E-value\tSD E-value\n";
        my $ng=1;
        my $percent=0;


        while(1){
          my %nnod;
          my (@e,@i,@l);

          while((my $line=<GTAB>)!~/\/\//){
            my @tab=split(/\t/,$line);
          $nnod{$tab[0]}++;
          $nnod{$tab[1]}++;                               
          push(@e,$tab[4]);
          push(@i,$tab[2]);
          push(@l,$tab[3]);
        }

        print STAT "$ng\t".(my $l=keys(%nnod))."\t";

        my $nedges=@i;
        my $nnods=keys %nnod;
        print STAT sprintf("%.2f",($nedges/(($nnods*($nnods-1))/2)))."\t";

# call _rsd() 3 times.
        my %id=_rsd(@i); undef(@i);
        print STAT sprintf("%.2f",$id{'mean'})."\t".sprintf("%.2f",$id{'sd'})."\t";
        my %lid=_rsd(@l); undef(@l);
        print STAT sprintf("%.2f",$lid{'mean'})."\t".sprintf("%.2f",$lid{'sd'})."\t";   
        my %ev=_rsd(@e); undef(@e);
        print STAT sprintf("%.0e",$ev{'mean'})."\t".sprintf("%.0e",$ev{'sd'})."\n";


        if($ng%$ntotgp==0){
          $percent++;
          if($progind) {
            print $percent."%";
            print "\b" x length($percent."%");
          }
        }
        $ng++;

        if(eof){last;}
        }
        close(GTAB);
        close(STAT);
        if($progind) {
          print "done.\n\n";
        }
      }

####################
#       COMPOSITION
####################
      if($outptions[1]=~/y|Y/){
        if($progind) {
          print "#Groups composition analysis...\n";
        }
        open(COMPO,">$dir/gpcompo.txt");
        if(!keys(%id2att)){
          my %att2id;
          my %s;
          open(ATT,"<seq.att") or die "unable to open seq.att: $!\n";
          my $line=<ATT>;
          while(($line=<ATT>)!~/^#ATTRIB/){
            chomp($line); ############
              my @tab=split(/\|#\|/,$line);
            my $sample=shift @tab;
            @tab=split(/,/,$tab[0]);
            if(!$sample){$sample="No specified Sample";}
            $s{$sample}++;
            for(@tab){ ####!!!!!!!!!!!!
              $id2att{'sample'}->{$_}=$sample;
            }
            last if(eof);
          }
          @{$id2att{'sample'}->{'NAMES'}}=sort keys %s;

          while(my $line=<ATT>){
            chomp($line);
            my @tab=split(/\|#\|/,$line);
            my $att=shift @tab;
            @tab=split(/,/,$tab[0]);
            if(!$att){$att="No specified Attributes";}
            $att2id{$att}=@tab;     
            for(@tab){
              push(@{$id2att{'attributes'}->{$_}},$att);
            }
          }
          close(ATT);
          @{$id2att{'attributes'}->{'NAMES'}}=sort keys %att2id;
        }

        open(GTAB,"<$dir/$gptab") or die "unable to open $dir/$gptab: $!\n";
        my $ng=1;

        print COMPO ("Group\t","Sequence Number\t",join("\t",@{$id2att{'sample'}->{'NAMES'}}),"\t",join("\t",@{$id2att{'attributes'}->{'NAMES'}}),"\n");

        while(1){
          my %id; 
          my (@e,@i,@l);

          while((my $line=<GTAB>)!~/\/\//){
            my @tab=split(/\t/,$line);
          $id{$tab[0]}++;
          $id{$tab[1]}++;
        }
        my %ressample=map {$_ => 0} @{$id2att{'sample'}->{'NAMES'}};
        my %resattr=map {$_ => 0} @{$id2att{'attributes'}->{'NAMES'}};

        foreach my $id (keys %id){
#print $id2att{'sample'}->{$id}."\n";
          $ressample{$id2att{'sample'}->{$id}}++; 
          for(@{$id2att{'attributes'}->{$id}}){
            $resattr{$_}++;
          }
        }

        print COMPO $ng."\t".(keys %id)."\t";
        foreach(sort keys %ressample){
          print COMPO $ressample{$_}."\t";
        }
        foreach(sort keys %resattr){
          print COMPO $resattr{$_}."\t";
        }
        print COMPO "\n";

        $ng++;

        if(eof){last;}
        }
        close(GTAB);
        close(COMPO);
        if($progind) {
          print "done.\n\n";
        }

      }


#################
#       CYTOSCAPE
#################

      if($outptions[2]=~/y|Y/){

        if($progind) {
        print "#Cytoscape input files creation...\n";
        }
        if(!keys(%id2gi)){
          open(INF,"<seq.info") or die "unable to open seq.info: $!\n";
          while(my @tab=split(/\t/,<INF>)){
            $id2gi{$tab[0]}=$tab[1];
          }
        }

        if(!keys(%id2att)){
          my %att2id;
          my %s;
          open(ATT,"<seq.att") or die "unable to open seq.att: $!\n";
          my $line=<ATT>;
          while(($line=<ATT>)!~/^#ATTRIB/){
            chomp($line);
            my @tab=split(/\|#\|/,$line);
            my $sample=shift @tab;
            @tab=split(/,/,$tab[0]);
            if(!$sample){$sample="No specified";}
            $s{$sample}++;
            for(@tab){
              $id2att{'sample'}->{$_}=$sample;
            }
            last if(eof);
          }
          @{$id2att{'sample'}->{'NAMES'}}=sort keys %s;

          while(my $line=<ATT>){
            chomp($line);
            my @tab=split(/\|#\|/,$line);
            my $att=shift @tab;
            @tab=split(/,/,$tab[0]);
            if(!$att){$att="No specified Attributes";}
            $att2id{$att}=1;        
            for(@tab){
              push(@{$id2att{'attributes'}->{$_}},$att);
            }
          }
          close(ATT);
          @{$id2att{'attributes'}->{'NAMES'}}=sort keys %att2id;
        }



        open(GTAB,"<$dir/$gptab") or die "unable to open $dir/$gptab: $!\n";
        mkdir($dir."/CYTOSCAPE") if(! -e $dir."/CYTOSCAPE");

        my $ng=1;               
        my $buf='';
        my $nedges=0;
        my $file='';
        my $firstgp=1;
        my $lastgp;
        my %forattr;

        while(1){

          while((my $line=<GTAB>)!~/\/\//){
            chomp($line);
          my @tab=split(/\t/,$line);
          $forattr{$tab[0]}++;
          $forattr{$tab[1]}++;


######
          if($tab[4]==0){
            $tab[4]=350;
          }
          elsif($tab[4]=~/e-/){
            $tab[4]=~s/(.+)e-//;
          }
#######
          $buf.=$id2gi{$tab[0]}."\t".$id2gi{$tab[1]}."\t".$tab[2]."\t".$tab[3]."\t".$tab[4]."\t".$tab[5]."\n";
          $nedges++;
        }
        $lastgp=$ng++;

        if($nedges>=150000){

          my $suffix=(($lastgp==$firstgp) ? "$firstgp.txt" : "$firstgp.to.$lastgp.txt");
          open(CC,">$dir/CYTOSCAPE/cc_$suffix");
          print CC "ID1\tID2\tHIT\%ID\tSS\%ID\tEVALUE\tMIN_COV_OPT\n";
          print CC $buf;
          close(CC);                      
          $buf='';
          $nedges=0;
          $firstgp=$ng;

          open(ATT,">$dir/CYTOSCAPE/att_cc_$suffix");
          print ATT "ID\tSAMPLE\t".join("\t",@{$id2att{'attributes'}->{'NAMES'}})."\n";
          foreach my $id (keys %forattr){
            print ATT $id2gi{$id}."\t".($id2att{'sample'}->{$id})."\t";
            my %resattr=map {$_ => 'no'} @{$id2att{'attributes'}->{'NAMES'}};                                       

            if($id2att{'attributes'}->{$id}){                                       
              for(@{$id2att{'attributes'}->{$id}}){
                $resattr{$_}='yes';
              }
            }
            for(@{$id2att{'attributes'}->{'NAMES'}}){
              print ATT $resattr{$_}."\t";
            }
            print ATT "\n";
          }
          undef %forattr;

        }
        if(eof){
          my $suffix="$firstgp.to.$lastgp.txt";

          open(CC,">$dir/CYTOSCAPE/cc_$suffix") or die "unable to open $dir/CYTOSCAPE/cc_$suffix: $!\n";
          print CC "ID1\tID2\tHIT\%ID\tSS\%ID\tEVALUE\tMIN_COV_OPT\n";                            
          print CC $buf;
          close(CC);                      

          open(ATT,">$dir/CYTOSCAPE/att_cc_$suffix");
          print ATT "ID\tSAMPLE\t".join("\t",@{$id2att{'attributes'}->{'NAMES'}})."\n";
          foreach my $id (keys %forattr){
            print ATT $id2gi{$id}."\t".$id2att{'sample'}->{$id}."\t";
            my %resattr=map {$_ => 'no'} @{$id2att{'attributes'}->{'NAMES'}};                                       
            if($id2att{'attributes'}->{$id}){                                       
              for(@{$id2att{'attributes'}->{$id}}){
                $resattr{$_}='yes';
              }
            }
            for(@{$id2att{'attributes'}->{'NAMES'}}){
              print ATT $resattr{$_}."\t";
            }
            print ATT "\n";
          }
          last;
        }
        }
        close(GTAB);
        if($progind) {
          print "done.\n\n";
        }
      }

#################
#         GEFX          #
#################

      if($outptions[3]=~/y|Y/){### Attention, changer le 4 en 3 et inverse pour fasta.+Rajouter la ligne de menu

        print "#Gephi input files creation...\n";
        if(!keys(%id2gi)){
          open(INF,"<seq.info") or die "unable to open seq.info: $!\n";
          while(my @tab=split(/\t/,<INF>)){
            $id2gi{$tab[0]}=$tab[1];
          }
        }

        if(!keys(%id2att)){
          my %att2id;
          my %s;
          open(ATT,"<seq.att") or die "unable to open seq.att: $!\n";
          my $line=<ATT>;
          while(($line=<ATT>)!~/^#ATTRIB/){
            chomp($line);
            my @tab=split(/\|#\|/,$line);
            my $sample=shift @tab;
            @tab=split(/,/,$tab[0]);
            if(!$sample){$sample="No specified";}
            $s{$sample}++;
            for(@tab){
              $id2att{'sample'}->{$_}=$sample;
            }
            last if(eof);
          }
          @{$id2att{'sample'}->{'NAMES'}}=sort keys %s;

          while(my $line=<ATT>){
            chomp($line);
            my @tab=split(/\|#\|/,$line);
            my $att=shift @tab;
            @tab=split(/,/,$tab[0]);
            if(!$att){$att="No specified Attributes";}
            $att2id{$att}=1;        
            for(@tab){
              push(@{$id2att{'attributes'}->{$_}},$att);
            }
          }
          close(ATT);
          @{$id2att{'attributes'}->{'NAMES'}}=sort keys %att2id;
        }



        open(GTAB,"<$dir/$gptab") or die "unable to open $dir/$gptab: $!\n";
        mkdir($dir."/GEPHI") if(! -e $dir."/GEPHI");

        my $ng=0;               

        my $file='';
        my $nattmax=0;

        while(1) {
          my %nodes;
          my $bufnodes;
          my $bufedges;

          while((my $line=<GTAB>)!~/\/\//){
            chomp($line);
          my @tab=split(/\t/,$line);

          if($tab[4]==0){
            $tab[4]=350;
          }
          elsif($tab[4]=~/e-/){
            $tab[4]=~s/(.+)e-//;
          }
          $nodes{$tab[0]}=1;
          $nodes{$tab[1]}=1;

          if(@{$id2att{'attributes'}->{$tab[0]}}){
            my $l=@{$id2att{'attributes'}->{$tab[0]}};
# $l=($l<length(@{$id2att{'attributes'}->{$tab[1]}})?length(@{$id2att{'attributes'}->{$tab[1]}}):$l);
            $l = ($l < scalar(@{$id2att{'attributes'}->{$tab[1]}}) ?
                scalar(@{$id2att{'attributes'}->{$tab[1]}}) : $l);
            $nattmax=($nattmax<$l?$l:$nattmax);
          }

          $bufedges.='      <edge source="'.$tab[0].'" target="'.$tab[1].'">'."\n";
          $bufedges.='        <attvalues>'."\n";
          $bufedges.='          <attvalue for="Score" value="'.$tab[4].'.0"></attvalue>'."\n";
          $bufedges.='          <attvalue for="Id2" value="'.$tab[2].'"></attvalue>'."\n";
          $bufedges.='          <attvalue for="Idseq" value="'.$tab[3].'"></attvalue>'."\n";
          $bufedges.='        </attvalues>'."\n";
          $bufedges.='      </edge>'."\n";
        }
        $ng++;

        my @date=localtime(time);
        my $y=$date[5]+1900;
        my $m=$date[4]+1;

        open(OUT,">$dir/GEPHI/cc_$ng\.gexf") or die "unable to open $dir/GEPHI/cc_$ng: $!\n";

        print OUT '<?xml version="1.0" encoding="UTF-8"?>'."\n";
        print OUT '<gexf xmlns="http://www.gexf.net/1.1draft" version="1.1" xmlns:viz="http://www.gexf.net/1.1draft/viz" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.gexf.net/1.1draft http://www.gexf.net/1.1draft/gexf.xsd">'."\n";
        print OUT "  <meta lastmodifieddate=\"$y\-$m\-$date[3]\">\n";
        print OUT '    <creator>EGON</creator>'."\n";
        print OUT '    <description></description>'."\n";
        print OUT '  </meta>'."\n";
        print OUT '  <graph defaultedgetype="undirected" timeformat="double" mode="static">'."\n";

        print OUT '    <attributes class="node" mode="static">'."\n";
        print OUT '      <attribute id="Sample" title="Sample" type="string">'."\n";
        print OUT '        <default>"unknown"</default>'."\n";
        print OUT '      </attribute>'."\n";
        for(my $i=0;$i<$nattmax;$i++){
          print OUT '      <attribute id="Att#'.($i+1).'" title="Attribute'.($i+1).'" type="string">'."\n";
          print OUT '        <default>"unknown"</default>'."\n";
          print OUT '      </attribute>'."\n";
        }
        print OUT '    </attributes>'."\n";

        print OUT '    <attributes class="edge" mode="static">'."\n";
        print OUT '      <attribute id="Score" title="BLAST Score" type="float"></attribute>'."\n";
        print OUT '      <attribute id="Id2" title="Identity" type="float"></attribute>'."\n";
        print OUT '      <attribute id="Idseq" title="IdSmallestSeq" type="float"></attribute>'."\n";
        print OUT '    </attributes>'."\n";
        print OUT '    <nodes>'."\n";

#       print CC $buf;
        foreach my $node (keys %nodes) {
          print OUT '      <node id="'.$node.'" label="'.$id2gi{$node}.'">'."\n";
          print OUT '        <attvalues>'."\n";
          print OUT '          <attvalue for="Sample" value="'.$id2att{'sample'}->{$node}.'"></attvalue>'."\n";
          if(@{$id2att{'attributes'}->{$node}}){  
            my @tmp=@{$id2att{'attributes'}->{$node}};
            for(0..$#tmp){
              print OUT '          <attvalue for="Att#'.($_+1).'" value="'.$tmp[$_].'"></attvalue>'."\n";
            }
          }
          print OUT '        </attvalues>'."\n";
          print OUT '      </node>'."\n";

        }
        print OUT '    </nodes>'."\n";
        print OUT '    <edges>'."\n";

        print OUT $bufedges;

        print OUT '    </edges>'."\n";
        print OUT '  </graph>'."\n";
        print OUT '</gexf>'."\n";
        close(OUT);                     

        $nattmax=0;
        last if(eof);
        }

        close(GTAB);
        print "done.\n\n";
      }


########
#       FASTA
########
      if($outptions[4]=~/y|Y/){

        if($progind) {
        print "#Groups fasta files creation...\n";
        }

        if(!keys(%id2gi)){
          open(INF,"<seq.info") or die "unable to open seq.info: $!\n";
          while(my @tab=split(/\t/,<INF>)){
            $id2gi{$tab[0]}=$tab[1];
          }
        }

        open(GTAB,"<$dir/$gptab") or die "unable to open $dir/$gptab: $!\n";
        if(! -e $dir."/FASTA"){
          mkdir($dir."/FASTA");
        }
        else{
          unlink glob($dir."/FASTA/*");
        }


        my $ng=1;               
        my $buf='';
        my $nedges=0;
        my $file='';
        my $firstgp=1;
        my $lastgp;
        my %id2file;
        while(my $line=<GTAB>){
          if($line!~/\/\//){
            my @tab=split(/\t/,$line);
          for(0..1){
            $id2file{$id2gi{$tab[$_]}}=$ng;
          }
        }                       
          else{
            $ng++;
          }
        }
        close(GTAB);

        opendir(DIR,".");
        my @files = readdir(DIR);
        my @fastas = grep(/\.f(n|a)a$/,@files);

        for my $file(@fastas){
          my $tag=($file=~/fna$/ ? 'n' : 'p');
          my @tab=split(/\./,$file);
          my $suffix=pop(@tab);
          open(FAS,"<$file") or die "unable to open $file: $!\n";
          while(my $line=<FAS>){
            if($line=~/^>(\w+)\|((\w|\.)+)(\||\s|\[)/){
              my $gi=$2;
              if($id2file{$gi}){
                open(OUT,">>","$dir/FASTA/".$tag."_cc".$id2file{$gi}.".".$suffix) or die "unable to open $dir/FASTA/".$tag."_cc".$id2file{$gi}.".".$suffix.": $!\n";
              }
              else{
                open(OUT,">>","$dir/FASTA/".$tag."_Singletons.".$suffix) or die "unable to open $dir/FASTA/".$tag."_Singletons.".$suffix.": $!\n";
              }
            }
            print OUT $line;
          }
          close(OUT);
          close(FAS);

        }

        closedir(DIR);
        if($progind) {
          print "done.\n\n";
        }

      }
      return 0;
}
# }}}

# {{{ sub genomnetw
sub genomnetw {
        #evalue=1e-05   #%id=20 #hitlength=20   Ha=75   %br=5
        open(ALI,"<edges.table") or die "cannot open edges.table: $!\n";
        my @args=split(/=|\t/,<ALI>);
        my ($threshold,$identity,$idshortSeq,$br,$hl)=submenu("Linkage Parameters",
                                "1. E-value threshold (<=$args[1]) = ", $args[1],
                                "2. Hit identity threshold [$args[3]-100]% = ", $args[3]        ,
                                "3. Identities must correspond at least to [$args[5]-100]% of the smallest homolog = ", $args[5],
                                "4. Best-reciprocal condition enforced(y/n) = ", 'n',
                                "5. Hit coverage condition enforced(y/n) = ", 'n'
        );
#
        $br= $br eq 'y' ? 1 : 0;
        $hl= $hl eq 'y' ? 1 : 0; 
        my $dir="GENOMNET_$threshold\.$identity\.$idshortSeq\.$br\.$hl";
        my $linktab="links.table";      
        my $choice='';
        my%id2gi;
        
        if(-e "$dir/$linktab"){
                while($choice!~/r|o|q/i){
                        print "An analysis with same parameteres was already performed. Would you like to: \n\t- recompute the network (r),\n\t- just create outfiles (o) without recomputation\n\t- or quit (q)\n>";
                        chomp($choice=readline *STDIN);
                }
                if($choice=~/r|R/){
                        unlink glob ("$dir/*");
                }
                elsif($choice=~/q|Q/){
                        exit(0);
                }
        }
        else{
                if(! -e $dir){
                        mkdir($dir) or die ("unable to create $dir: $!\n");
                }               
                $choice='r';
        }
        
        my @outptions=submenu("Output files format",
                                        "1. Cytoscape inputs (y/n)= ", "y",
                                        "2. Gephi inputs (y/n)= ", "n"
        );


##############################################
        if($choice=~/r/i){
                my $compdir="GENENET_$threshold\.$identity\.$idshortSeq\.$br\.$hl";
                if(! -e $compdir){
                        mkdir $compdir;
                        if(! -e "$compdir/groups.table"){
                                printTitle("Network computation");
                                print "\n";
                                simpleLink("$compdir/groups.table",$threshold,$identity,$idshortSeq,$br);
                        }
                }

                print "\n";
                genomeSimpleLink($dir,$linktab,$threshold,$identity,$idshortSeq,$br,$hl);
                print "done.\n\n";
        }

#############
# CYTOSCPAE
#############
        if($outptions[0]=~/y|Y/){

                print "#Cytoscape input files creation...\n";

                open(GTAB,"<$dir/$linktab") or die "unable to open $dir/$linktab: $!\n";
                if(! -e $dir."/CYTOSCAPE"){
                        mkdir($dir."/CYTOSCAPE");
                }
                else{
                        unlink glob($dir."/CYTOSCAPE/*");
                } 
                        
                my $ng=1;               
                my $buf='';
                my $nedges=0;
                my $file='';
                my $firstgp=1;
                my $lastgp;
                my %forattr;

                while(1){

                        while((my $line=<GTAB>)!~/\/\//){
                                $buf.=$line;
                                $nedges++;
                        }
                        $lastgp=$ng++;

                        if($nedges>=150000){

                                my $suffix=(($lastgp==$firstgp) ? "$firstgp.txt" : "$firstgp.to.$lastgp.txt");
                                open(CC,">$dir/CYTOSCAPE/cc_$suffix");
                                print CC "Sample1\tSample2\tShared_Gene_Families\n";
                                print CC $buf;
                                close(CC);                      
                                $buf='';
                                $nedges=0;
                                $firstgp=$ng;
                        }
                        if(eof){
                                my $suffix="$firstgp.to.$lastgp.txt";
                        
                                open(CC,">$dir/CYTOSCAPE/cc_$suffix");
                                print CC "Sample1\tSample2\tShared_Gene_Families\n";
                                print CC $buf;
                                close(CC);                              

                                last;
                        }
                }
                close(GTAB);
                print "done.\n\n";
        }



#############
# GEPHI
#############
        if($outptions[1]=~/y|Y/){### Attention, changer le 4 en 3 et inverse pour fasta.+Rajouter la ligne de menu

                print "#Gephi input files creation...\n";

                open(GTAB,"<$dir/$linktab") or die "unable to open $dir/$linktab: $!\n";
                mkdir($dir."/GEPHI") if(! -e $dir."/GEPHI");
        
                my $ng=0;               
                my $file='';
                my $nattmax=0;
                 
                while(1){
                        my $bufnodes;
                        my $bufedges;
                        my %nodes;

                        while((my $line=<GTAB>)!~/\/\//){

                                chomp($line);
                                my @tab=split(/\t/,$line);

                                $nodes{$tab[0]}=1;
                                $nodes{$tab[1]}=1;

                                $bufedges.='      <edge source="'.$tab[0].'" target="'.$tab[1].'">'."\n";
                                $bufedges.='        <attvalues>'."\n";
                                $bufedges.='          <attvalue for="Score" value="'.$tab[2].'.0"></attvalue>'."\n";
                                $bufedges.='        </attvalues>'."\n";
                                $bufedges.='      </edge>'."\n";
                        }
                        $ng++;
        
                        my @date=localtime(time);
                        my $y=$date[5]+1900;
                        my $m=$date[4]+1;

                        open(OUT,">$dir/GEPHI/cc_$ng\.gexf") or die "unable to open $dir/GEPHI/cc_$ng: $!\n";

                        print OUT '<?xml version="1.0" encoding="UTF-8"?>'."\n";
                        print OUT '<gexf xmlns="http://www.gexf.net/1.1draft" version="1.1" xmlns:viz="http://www.gexf.net/1.1draft/viz" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.gexf.net/1.1draft http://www.gexf.net/1.1draft/gexf.xsd">'."\n";
                        print OUT "  <meta lastmodifieddate=\"$y\-$m\-$date[3]\">\n";
                        print OUT '    <creator>EGON</creator>'."\n";
                        print OUT '    <description></description>'."\n";
                        print OUT '  </meta>'."\n";
                        print OUT '  <graph defaultedgetype="undirected" timeformat="double" mode="static">'."\n";

                        print OUT '    <attributes class="edge" mode="static">'."\n";
                        print OUT '      <attribute id="Score" title="Shared gene families" type="float"></attribute>'."\n";
                        print OUT '    </attributes>'."\n";
                        print OUT '    <nodes>'."\n";

                #       print CC $buf;
                        foreach my $node (keys %nodes) {
                                print OUT '      <node id="'.$node.'" label="'.$node.'">'."\n";
                                print OUT '      </node>'."\n";
                        }
                        print OUT '    </nodes>'."\n";
                        print OUT '    <edges>'."\n";

                        print OUT $bufedges;

                        print OUT '    </edges>'."\n";
                        print OUT '  </graph>'."\n";
                        print OUT '</gexf>'."\n";
                        close(OUT);                     

                        $nattmax=0;
                        last if(eof);

                }
        }

#############
        print "\tPress enter to continue...";
        <STDIN>;
        return 0;
}
# }}}

__END__

