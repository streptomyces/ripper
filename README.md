# ripper.pl
ripper.pl
=========

## Description

The _rodeo2_ Python script _rodeo\_main.py_ produces and output file
named _main\_co\_occur.csv_. An example of this is shown below.

    Query,Genus/Species,Nucleotide_acc,Protein_acc,start,end,dir,PfamID1,Name1,Description1,E-value1,PfamID2,Name2,Description2,E-value2,PfamID3,Name3,Description3,E-value3  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37395.1,3876197,3875843,-  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37396.1,3878350,3877288,-,PF07143,CrtC,CrtC N-terminal lipocalin domain,6.4e-57,PF17186,Lipocalin_9,Lipocalin-like domain,7.1e-42  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37397.1,3880802,3878339,-,PF02687,FtsX,FtsX-like permease family,9.3e-22,PF12704,MacB_PCD,MacB-like periplasmic core domain,2.5e-10,PF01568,Molydop_binding,Molydopterin dinucleotide binding domain,6.9e-05  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37398.1,3881472,3880803,-,PF00005,ABC_tran,ABC transporter,6.9e-28,PF13304,AAA_21,"AAA domain, putative AbiEii toxin, Type IV TA system",2.3e-05,PF05729,NACHT,NACHT domain,4e-05,PF13401,AAA_22,AAA domain,9.7e-05,PF13191,AAA_16,AAA ATPase domain,0.0001  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37399.1,3881748,3882423,+,PF00300,His_Phos_1,Histidine phosphatase superfamily (branch 1),2.6e-05  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37400.1,3882597,3884253,+,PF02366,PMT,Dolichyl-phosphate-mannose-protein mannosyltransferase,7.3e-28,PF13231,PMT_2,Dolichyl-phosphate-mannose-protein mannosyltransferase,8.5e-19  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37401.1,3885283,3884569,-,PF13304,AAA_21,"AAA domain, putative AbiEii toxin, Type IV TA system",1.6e-16,PF00005,ABC_tran,ABC transporter,1.2e-14  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37402.1,3886026,3885282,-  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37403.1,3887228,3886034,-,PF02624,YcaO,"YcaO cyclodehydratase, ATP-ad Mg2+-binding",3e-15  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37404.1,3888021,3887214,-,PF00881,Nitroreductase,Nitroreductase family,0.00082  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37405.1,3888875,3888017,-  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37406.1,3889975,3889744,-  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37407.1,3892677,3890124,-,PF03272,Mucin_bdg,Putative mucin or carbohydrate-binding module,3.8e-31,PF13402,Peptidase_M60,"Peptidase M60, enhancin and enhancin-like",2.4e-13  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37408.1,3893744,3892883,-,PF12833,HTH_18,Helix-turn-helix domain,4.3e-16,PF02311,AraC_binding,AraC-like ligand binding domain,5.2e-15,PF07883,Cupin_2,Cupin domain,9.8e-07,PF00165,HTH_AraC,"Bacterial regulatory helix-turn-helix proteins, AraC family",9.1e-05,PF14525,AraC_binding_2,AraC-binding-like domain,0.00019  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37409.1,3893872,3894538,+,PF01557,FAA_hydrolase,Fumarylacetoacetate (FAA) hydrolase family,2.3e-48  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37410.1,3894534,3895305,+,PF01557,FAA_hydrolase,Fumarylacetoacetate (FAA) hydrolase family,1.7e-57  
    AIB37403.1,Pseudomonas simiae,CP007637.1,AIB37411.1,3895310,3896771,+,PF00171,Aldedh,Aldehyde dehydrogenase family,1.5e-174  

_ride\_sp.pl_ reads the _main\_co\_occur.csv_ file produced by
_rodeo2_ and


1. Determines the genbank accession to fetch based on the
value in column 3.

2. Determines the coordinates of the tailoring enzyme by reading
columns 5, 6 and 7 for the line in which the values in column 1 and
column 4 are identical.

Then the genbank file is fetched from Genbank and a smaller genbank
file is generated from it whose length is twice the value of the
variable _$flankLen_. This smaller genbank file, hereafter referred
to as the _sub-genbank_ file, is centered around the centre of the
tailoring enzyme.

A specially built version of _prodigal_ renamed _prodigal-short_ is
then used to find genes in the sub-genbank file. _prodigal-short_ is
configured to find genes as short as 60 nucleotides compared to 90
nucleotides in the default build.



> fetchGbk called on 391 and 437
> TEcoordsByProtId called on 397
> 
> locateTE called on 495
> 
> subgenbank called on 499
> 
> prodigal-short called on 557
> 
> for my $lr (@sprdl) is 612 to 788
> 
> 
> distTE called on 693
> 
> prdcol called on 706
> 
> aaseq  called on 725
> 
> 
> sub prodigal2aa is not used. Looks like it was replaced by aaseq() at
> some point.
> 
> sub seqobj2print is not used.


For all the genes found by _prodigal-short_ the following is done.

1. The prodigal score is enhanced by a reward if the gene is on the
same strand as the tailoring enzyme.

2. Determine overlap with already annotated genes.

3. Translate to get the protein sequence.

4. If the length of the protein is less than $minPPlen or greater than
$maxPPlen; skip to the next gene found by prodigal.

5. If the gene has significant overlap with an already annotated gene
then it is skipped.

6. If a gene is not filtered out in steps 4 or 5, it is annotated in
the genbank file and its distance from the tailoring enzyme is
determined.

7. If the gene is within a specified distance from the TE it is
included in the list to be output and also saved in a _Sqlite3_
table.

## Example Bash script implementing the full analysis pipeline

A file named ripper_run.sh is included in the GitHub repository.

The starting point is a query file containing Genpept accessions for
tailoring enzymes. In the example below this file is named _in.list_.
Each query file with its list of tailoring enzyme accession should be
processed in a directory of its own. This directory should also
contain _local.conf_ and the Bash script listed below.

Example of Bash script to run _rodeo\_main.py_ followed by
_ride\_sp.pl_ and some other scripts to organise the output and output
files.

```BASH 
for hcd in rodout rideout sqlite gbkcache orgnamegbk rodeohtml; do
if [[ ! -d $hcd ]]; then
  mkdir $hcd
fi
done

queryfn="in.list";
asdir=/Users/nouser;
codedir=${asdir}/code/ride;
ln -s ${asdir}/databases/pfam ./hmm_dir
ln -s ${asdir}/github/rodeo2/confs ./
perlbin="/usr/bin/perl"
for acc in $(cat $queryfn); do 
  echo python ${asdir}/github/rodeo2/rodeo_main.py -out rodout/${acc} ${acc}
  python ${asdir}/github/rodeo2/rodeo_main.py -out rodout/${acc} ${acc}
  echo $perlbin ${codedir}/ride_sp.pl -outdir rideout -- rodout/${acc}/main_co_occur.csv
  $perlbin ${codedir}/ride_sp.pl -outdir rideout -- rodout/${acc}/main_co_occur.csv
  # break;
done

$perlbin ${codedir}/pfam_sqlite.pl
$perlbin ${codedir}/mergeRidePfam.pl -out out.txt
$perlbin ${codedir}/gbkNameAppendOrg.pl -indir rideout
$perlbin ${codedir}/collectFiles.pl rodout '\.html$'
```

## Example of _local.conf_

_local.conf_ is a two column (space delimited) text file which is
read by _ride\_sp.pl_ and the following scripts in the pipeline.

A file named _local.conf_ is included in the repository.


    # Lines beginning with \# are comments.
    # All names are case sensitive.
    
    # Downloaded genbank files are cached here.
    bkcache            gbkcache
    
    # Filename for the SQLite3 database.
    qlite3fn           sqlite/ride.sqlite3
    qlitefn            sqlite/ride.sqlite3
    
    # Directory containing the Pfam database files.
    # Note that this is an absolute path.
    # Should be the same as pfamdir in the ripper_run.sh file.
    mmdir              /home/sco/blast_databases/pfam
    
    # Name of the Pfam database to use.
    mmdb               Pfam-A.hmm
    
    # Name of the Pfam data file.
    # Used for reading information about models.
    famhmmdatfn        Pfam-A.hmm.dat
    
    # Name of the SQLite3 table where results of
    # hmmer searches are stored.
    famrestab          pfamscan
    
    # Name of the SQLite3 table where results of
    # prodigal search are stored.
    repeptab           ride
    
    # Directory where output genbank files are stored.
    # Organism names are prefixed to the file names for
    # ease of identification.
    rgnamegbkdir       orgnamegbk
    
    
    
    # Below are some defaults (commented out) that can also
    # be specified in this file. The names are case sensitive!
    
    # minPPlen                   20
    # maxPPlen                  120
    # prodigalScoreThresh        15
    # maxDistFromTE            8000
    # fastaOutputLimit            3
    # sameStrandReward            5
    # flankLen                12500


## Building _prodigal-short_

The following changes (shown as the output of the _git diff_ command)
were made to _prodigal_ source files before building
_prodigal-short_ according to instructions provided with the
_prodigal_ source download.

    diff --git a/Makefile b/Makefile
    index 23ffe00..6edbb53 100644
    --- a/Makefile
    +++ b/Makefile
    @@ -24,7 +24,7 @@ CC      = gcc
     CFLAGS  += -pedantic -Wall -O3
     LFLAGS = -lm $(LDFLAGS)
    
    -TARGET  = prodigal
    +TARGET  = prodigal-short
     SOURCES = $(shell echo *.c)
     HEADERS = $(shell echo *.h)
     OBJECTS = $(SOURCES:.c=.o)
    
    
    diff --git a/dprog.h b/dprog.h
    index d729f4c..ea7fa10 100644
    --- a/dprog.h
    +++ b/dprog.h
    @@ -26,7 +26,7 @@
     #include "sequence.h"
     #include "node.h"
    
    -#define MAX_SAM_OVLP 60
    +#define MAX_SAM_OVLP 45
     #define MAX_OPP_OVLP 200
     #define MAX_NODE_DIST 500
    
    diff --git a/node.h b/node.h
    index 6c722be..551c7b8 100644
    --- a/node.h
    +++ b/node.h
    @@ -27,11 +27,11 @@
     #include "training.h"
    
     #define STT_NOD 100000
    -#define MIN_GENE 90
    -#define MIN_EDGE_GENE 60
    -#define MAX_SAM_OVLP 60
    -#define ST_WINDOW 60
    -#define OPER_DIST 60
    +#define MIN_GENE 60
    +#define MIN_EDGE_GENE 45
    +#define MAX_SAM_OVLP 45
    +#define ST_WINDOW 45
    +#define OPER_DIST 45
     #define EDGE_BONUS 0.74
     #define EDGE_UPS -1.00
     #define META_PEN 7.5



## Other supporting Perl scripts

### pfam\_sqlite.pl

_pfam\_sqlite.pl_ takes all the proteins in a specified table in a
specified sqlite3 database and searches them for Pfam domains. The
results of these searches are placed in a new table in the same
sqlite3 database.

### mergeRidePfam.pl

_mergeRidePfam.pl_ merges the information contained in the two sqlite3
tables, one containing the output of prodigal-short and the other
containing the output of Pfam searches on the proteins selected from
the output of prodigal-short. It writes out a tab delimited file.

### gbkNameAppendOrg.pl

Copies the output genbank files to a new directory with the organism
names appended to the filenames for ease of identification. Files are
copied to the directory specified in the configuration variable
_orgnamegbkdir_.

### collectFiles.pl

_collectFiles.pl_ copies files from a specified directory (and
subdirectories) to another directory if the base filename matches the
specified regular expression.

 perl collectFiles.pl -indir rodout -pat '\.html$' -outdir rodeohtml

The options shown above are the defaults. _-outdir_ may be specified
in _local.conf_ as _rodeohtmldir_. Value in the configuration file
takes precedence.

