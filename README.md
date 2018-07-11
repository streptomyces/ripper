# ripper.pl

## Description

This file is for the standalone version. It needs to be changed for
the Docker version.

RiPPER (RiPP Precursor Peptide Enhanced Recognition) identifies genes
encoding putative precursor peptides within RiPP (ribosomally
synthesised and post-translationally modified peptide) gene clusters.
This retrieves putative gene clusters using RODEO2, searches for
likely precursor peptide coding regions using a modified form of
Prodigal (prodigal-short), provides an output Genbank file for
visualisation in
[Artemis](http://www.sanger.ac.uk/science/tools/artemis). Output
peptides are analysed for Pfam domains and the results are then
tabulated from a batch input for further analysis.

## Pre-requisites

1. Perl >= 5.14.0
2. BioPerl modules installed for the Perl being used.
3. Python >= 2.7.0
4. Biopython modules installed for the Python being used.
5. Perl modules _DBI_ and _DBD::SQLite_.
6. [HMMER](http://hmmer.org/).
7. [Prodigal](https://github.com/hyattpd/Prodigal). We actually use
a specially built form of Prodigal which we call _prodigal-short_.
The building of _prodigal-short_ is described later under the section
**Building prodigal-short**.

## Brief workflow

A bash script (ripper_run.sh, further details below) runs a series of
scripts to provide a full RiPPER analysis. This uses analysis settings
defined in an associated configuration file (local.conf). Where
relevant, variables defined in local.conf are described below.

Using an accession number for a predicted RiPP tailoring enzyme, the
[rodeo2](https://github.com/thedamlab/rodeo2) Python script
*rodeo\_main.py* produces and output file named *main\_co\_occur.csv*
that contains information about the annotated genes that flank the
RiPP tailoring enzyme.

*ripper.pl* reads the *main\_co\_occur.csv* file produced by
the *rodeo2* script *rodeo\_main.py* to determine the genbank
accession to fetch and the coordinats of the tailoring enzyme that was
used as the search term.

The genbank file is then fetched from GenBank and a smaller genbank
file is generated from it whose length is twice the value of the
variable *$flankLen* (default = 12500). This smaller genbank file,
hereafter referred to as the *sub-genbank* file, is centered around
the centre of the tailoring enzyme.

1. Determines the genbank accession to fetch based on the
value in column 3.

2. Determines the coordinates of the tailoring enzyme by reading
columns 5, 6 and 7 for the line in which the values in column 1 and
column 4 are identical.

Then the genbank file is fetched from Genbank and a smaller genbank
file is generated from it whose length is twice the value of the
variable *$flankLen*. This smaller genbank file, hereafter referred
to as the *sub-genbank* file, is centered around the centre of the
tailoring enzyme.

```
Rodeo retrieves the entire genbank file as it exists in Genbank.
```


A specially built version of *prodigal* renamed *prodigal-short* is
then used to find genes in the sub-genbank file. *prodigal-short* is
configured to find genes as short as 60 nucleotides compared to 90
nucleotides in the default build.

For all the genes found by *prodigal-short* the following is done.

1. The prodigal score is enhanced by a reward if the gene is on the
same strand as the tailoring enzyme and its score before reward is 
more than negative of the reward number.(variable `$sameStrandReward`,
default = 5).

2. Determine overlap with already annotated genes.

3. Translate to get the protein sequence.

4. If the length of the protein is less than `$minPPlen` (default = 20)
or greater than `$maxPPlen`; skip to the next gene found by prodigal.

5. If the gene has significant overlap (> 20 nucleotides) with an
already annotated gene then it is skipped.

6. If a gene is not filtered out in steps 4 or 5, it is annotated in
the genbank file and its distance from the tailoring enzyme is
determined.

7. If the gene is within a specified distance from the TE
(variable `$maxDistFromTE`, default = 8000)
it is included in the list to be output and also saved in a *Sqlite3*
table. By default, ripper.pl includes 3 peptides per gene cluster
(variable `$fastaOutputLimit`) within this specified distance, as well
as any additional peptides whose prodigal-short scores are greater
than variable `$prodigalScoreThresh` (default = 15).


The proteins in this table are then searched for pfam domains using
the *pfam\_sqlite.pl* script. The results of these searches are placed
in a new table in the same sqlite3 database.

*mergeRidePfam.pl* then merges the information contained in the two
sqlite3 tables, one containing the output of prodigal-short and the
other containing the output of Pfam searches on the proteins selected
from the output of prodigal-short. A tab delimited file (out.txt) is
then generated that contains all protein sequence and Pfam information
alongside various associated data (tailoring enzyme accession, strain,
peptide sequence, distance from tailoring enzyme, coding strand in
relation to tailoring gene, Prodigal score). If multiple genomic
regions are searched in parallel, all data are collated in this single
file.

*gbkNameAppendOrg.pl* copies the output genbank files to a new
directory with the organism names appended to the filenames for ease
of identification. Files are copied to the directory specified in the
configuration variable *orgnamegbkdir* (default = orgnamegbk).

*collectFiles.pl* is used to copy all rodeo result .html files into a
single directory defined by the *rodeohtmldir* variable in the
configuration file (default = rodeohtml).

## Example Bash script implementing the full analysis pipeline

A file named *ripper\_run.sh* is included in the GitHub repository.

The starting point is a query file containing Genpept accessions for
tailoring enzymes. In the example below this file is named
*minitest.txt*. Each query file containing a list of tailoring enzyme
accessions should be processed in a directory of its own. This
directory should also contain *local.conf* including any optional
changes to analysis variables) and the *ripper\_run.sh* Bash script
(queryfn=”xxx.txt” should be modified to list the file that contains
the list of accessions).

Within *ripper\_run.sh*, `queryfn=xxx.txt` should be modified to list
the file that contains the list of accessions, `ripperdir` specifies the
directory of the ripper Perl scripts, `rodeodir` specifies the directory
that contains the rodeo scripts and `pfamdir` specifies the directory
that contains the Pfam databases. `perlbin` and `pythonbin` specify the
respective locations of perl and python.


Example of Bash script to run *rodeo\_main.py* followed by
*ripper.pl* and some other scripts to organise the output and output
files.

```BASH 
# This file should be in the directory from where it
# will be run as
#
#  source ripper_run.sh
#
#


homedir=\<insert home directory here\>;
# Below are a couple of examples
# homedir="/home/sco";
# homedir="/Users/sco";


queryfn="minitest.txt";

# Two lines below assume that in your home directory you have
# a sub-directory named "fromgithub" where you have cloned
# ripper and rodeo2 repositories using commands like. 
# git clone https://github.com/streptomyces/ripper.git
# git clone https://github.com/thedamlab/rodeo2.git
ripperdir=${homedir}/fromgithub/ripper;
rodeodir=${homedir}/fromgithub/rodeo2;

pfamdir=${homedir}/blast_databases/pfam

# $perlbin and $pythonbin. Both these should have BioPerl and Biopython
# (respectively) installed for them. It is not uncommon to have more than one
# versions of Perl and Python installed on the same machine. Hence the need for
# the next two lines.
perlbin="/usr/local/bin/perl"
pythonbin="/usr/bin/python"

########################################################
### Users should not need to make changes below this ###
########################################################

# Make a couple of symlinks to keep rodeo_main.py happy.
ln -s $pfamdir ./hmm_dir
ln -s ${rodeodir}/confs ./

# Make the various directories where output will be placed.
for hcd in rodout ripout sqlite gbkcache orgnamegbk rodeohtml; do
if [[ ! -d $hcd ]]; then
  mkdir $hcd
fi
done

### Setup is now complete. Actual runs below. ###

# rodeo run and ripper.pl run for each query in $queryfn

for acc in $(cat $queryfn); do 
  echo $pythonbin ${rodeodir}/rodeo_main.py -out rodout/${acc} ${acc}
  $pythonbin ${rodeodir}/rodeo_main.py -out rodout/${acc} ${acc}
  echo $perlbin ${ripperdir}/ripper.pl -outdir ripout -- rodout/${acc}/main_co_occur.csv
  $perlbin ${ripperdir}/ripper.pl -outdir ripout -- rodout/${acc}/main_co_occur.csv
done

# Run the postprocessing scripts

$perlbin ${ripperdir}/pfam_sqlite.pl
$perlbin ${ripperdir}/mergeRidePfam.pl -out out.txt
$perlbin ${ripperdir}/gbkNameAppendOrg.pl -indir ripout
$perlbin ${ripperdir}/collectFiles.pl rodout '\.html$'

```

## Example of *local.conf*

A file named *local.conf* is included in the repository.

*local.conf* is a two column (space delimited) text file which is
read by *ripper.pl* and the following scripts in the pipeline.


    # Lines beginning with \# are comments.
    # All names are case sensitive.
    
    # Downloaded genbank files are cached here.
    gbkcache            gbkcache
    
    # Filename for the SQLite3 database.
    sqlite3fn           sqlite/ripp.sqlite3

    # Location of prodigal-short binary
    prodigalshortbin      /usr/local/bin/prodigal-short

    # Location of hmmscan binary
    hmmscanbin      /usr/local/bin/hmmscan

    # Directory containing the Pfam database files.
    # Note that this is an absolute path.
    # Should be the same as pfamdir in the ripper_run.sh file.
    hmmdir              /home/sco/blast_databases/pfam
    
    # Name of the Pfam database to use.
    hmmdb               Pfam-A.hmm
    
    # Name of the Pfam data file.
    # Used for reading information about models.
    pfamhmmdatfn        Pfam-A.hmm.dat
    
    # Name of the SQLite3 table where results of
    # hmmer searches are stored.
    pfamrestab          pfamscan
    
    # Name of the SQLite3 table where results of
    # prodigal search are stored.
    prepeptab           ripper
    
    # Directory where output genbank files are stored.
    # Organism names are prefixed to the file names for
    # ease of identification.
    orgnamegbkdir       orgnamegbk
    
    
    # Below are some defaults (commented out) that can also
    # be specified in this file. The names are case sensitive!
    
    # minPPlen                   20
    # maxPPlen                  120
    # prodigalScoreThresh        15
    # maxDistFromTE            8000
    # fastaOutputLimit            3
    # sameStrandReward            5
    # flankLen                12500


## Building *prodigal-short*

The following changes (shown as the output of the *git diff* command)
were made to *prodigal* source files before building
*prodigal-short* according to instructions provided with the
*prodigal* source download.

1. In the file *makefile* first and only occurrence of
`TARGET = prodigal` was changed to `TARGET = prodigal-short`.

```diff
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
```

2. In the file *dprog.h* first and only occurrence of
`#define MAX_SAM_OVLP 60` was changed to `#define MAX_SAM_OVLP 45`

```diff
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
```

3. In the file *node.h* the following lines

```
#define MIN_GENE 90
#define MIN_EDGE_GENE 60
#define MAX_SAM_OVLP 60
#define ST_WINDOW 60
#define OPER_DIST 60
```

Were changed to the following lines.

```
#define MIN_GENE 60
#define MIN_EDGE_GENE 45
#define MAX_SAM_OVLP 45
#define ST_WINDOW 45
#define OPER_DIST 45
```    

```diff
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
```


## Other supporting Perl scripts

### pfam\_sqlite.pl

*pfam\_sqlite.pl* takes all the proteins in a specified table in a
specified sqlite3 database and searches them for Pfam domains. The
results of these searches are placed in a new table in the same
sqlite3 database.

### mergeRidePfam.pl

*mergeRidePfam.pl* merges the information contained in the two sqlite3
tables, one containing the output of prodigal-short and the other
containing the output of Pfam searches on the proteins selected from
the output of prodigal-short. It writes out a tab delimited file.

### gbkNameAppendOrg.pl

Copies the output genbank files to a new directory with the organism
names appended to the filenames for ease of identification. Files are
copied to the directory specified in the configuration variable
*orgnamegbkdir*.

### collectFiles.pl

*collectFiles.pl* copies files from a specified directory (and
subdirectories) to another directory if the base filename matches the
specified regular expression.

```
perl collectFiles.pl -indir rodout -pat '\.html$' -outdir rodeohtml
```

The options shown above are the defaults. *-outdir* may be specified
in *local.conf* as *rodeohtmldir*. Value in the configuration file
takes precedence.

