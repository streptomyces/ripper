# Docker image for ripper.pl

## Quick start

### Getting an image and running a container from it

~~~ {.sh}
docker pull streptomyces/ripdock
~~~

The default is to pull the image tagged as *latest*.

~~~ {.sh}
docker run -it -v "$PWD":/home/mnt streptomyces/ripdock
~~~

You could pull a different image if you have a tagname. See
eaxmple below where *testing* is the tagname.

~~~ {.sh}
docker pull streptomyces/ripdock:testing
~~~

On Linux $PWD expands to the current directory. You can use a different
directory name here, as long as it exists, as shown below.

~~~ {.sh}
docker run -it -v /home/sco/analysis/set1:/home/mnt \
streptomyces/ripper:first
~~~

Do not change the `/home/mnt` part. Scripts in the container expect to
find this directory. The host directory you mount on `/home/mnt` in the
container is where the output directories and files are written. You
can place your input list in the mounted host directory on the host
side and access it in /home/mnt/ on the container side. See the
example Run on your own list below.

Analysis carried out in the running container

Run a small test analysis


~~~ {.sh}
./ripper_run.sh
~~~

The above uses a small list of 3 accessions as input saved in a file
named *minitest.txt*. Analyse your own list

~~~ {.sh}
./ripper_run.sh /home/mnt/te_accessions.txt
~~~

The filename given as argument to ripper_run.sh should contain protein
(genpept) accession numbers, one on each line.



## Detailed description

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

### Pre-requisites

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

### Brief workflow

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

Rodeo retrieves the entire genbank file as it exists in Genbank.

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

### The Bash script implementing the full analysis pipeline

A file named *ripper\_run.sh* is included. If it is run without any
arguments it reads the file *minitest.txt* as input. You can supply a
different input file an argument to *ripper\_run.sh*.

The starting point is a query file containing Genpept accessions for
tailoring enzymes. In the example below this file is named
*minitest.txt*. The input file should contain a list of tailoring
enzyme accessions.

Contents of *ripper_run.sh* are listed below. There is no need to make
any changes to it.

~~~ {.sh}
#!/bin/bash
# This file is the bash script that provides a full RiPPER analysis
# that encompasses a number of related Perl scripts. Final outputs
# are found in orgnamegbk (GenBank files featuring RiPPER annotations),
# out.txt (tab-delimited table containing retrieved peptides and
# associated data) and rodeohtml (RODEO2 html output).
# This file should be in the directory from where it
# will be run. The local.conf file (featuring any parameter
# modifications) should also be placed in this directory
# This file should be in the directory from where it
# will be run as
#
#  ./ripper_run.sh <inputfilename>
#
#

# Query file name defaults to minitest.txt.
queryfn=$1;

if [[ ${#queryfn} -lt 1 ]]; then
  queryfn="minitest.txt";
fi

if [[ ! -s ${queryfn} || ! -e ${queryfn} ]]; then
echo "Either $queryfn does not exists or is zero in size. Aborting."; 
exit 1;
fi


ripperdir=/home/work/ripper;
rodeodir=/home/work/rodeo2;
pfamdir=/home/work/pfam



# Tab delimited output file for results including pfam hits.
outfile=/home/mnt/out.txt

# Rodeo output directory
rodoutdir=/home/mnt/rodout;

# ripper output directory. Contains gbk files.
ripoutdir=/home/mnt/ripout;

# ripper output directory. Contains gbk files where filenames
# have the organism name prepended for convenience. 
orgnamegbkdir=/home/mnt/orgnamegbk;

# The html file output by rodeo2 are here.
rodeohtmldir=/home/mnt/rodeohtml;

# Below is legacy from the Linux installable version of this script.

perlbin="perl"
pythonbin="python"


# Make a couple of symlinks to keep rodeo_main.py happy.
ln -s $pfamdir ./hmm_dir
ln -s ${rodeodir}/confs ./

# Make the various directories where output will be placed.
for hcd in $rodoutdir $ripoutdir sqlite gbkcache $orgnamegbkdir $rodeohtmldir; do
if [[ ! -d $hcd ]]; then
  mkdir $hcd
fi
done

### Setup is now complete. Actual runs below. ###

# rodeo run and ripper.pl run for each query in $queryfn

for acc in $(cat $queryfn); do 
  echo $pythonbin ${rodeodir}/rodeo_main.py -out ${rodoutdir}/${acc} ${acc}
  $pythonbin ${rodeodir}/rodeo_main.py -out ${rodoutdir}/${acc} ${acc}
  echo $perlbin ${ripperdir}/ripper.pl -outdir $ripoutdir -- ${rodoutdir}/${acc}/main_co_occur.csv
  $perlbin ${ripperdir}/ripper.pl -outdir $ripoutdir -- ${rodoutdir}/${acc}/main_co_occur.csv
done

# Run the postprocessing scripts

$perlbin ${ripperdir}/pfam_sqlite.pl
$perlbin ${ripperdir}/mergeRidePfam.pl -out ${outfile}
$perlbin ${ripperdir}/gbkNameAppendOrg.pl -indir $ripoutdir
$perlbin ${ripperdir}/collectFiles.pl ${rodoutdir} ${rodeohtmldir} '\.html$'
~~~

### Example of *local.conf*

A file named *local.conf* is included in the repository.

*local.conf* is a two column (space delimited) text file which is read
by *ripper.pl* and the postprocessing scripts in the pipeline. There
should be no need to make changes to this file.

~~~ 
# Lines beginning with # are comments.
# All names are case sensitive.

# Downloaded genbank files are cached here.
# ripper_run.sh automatically generates a gbkcache
# directory in the directory it is run from.
gbkcache            gbkcache

# Filename for the SQLite3 database.
# ripper_run.sh automatically generates a sqlite
# directory in the directory it is run from.
sqlite3fn           sqlite/ripp.sqlite3

# Location of prodigal-short binary
# prodigalshortbin          /usr/local/bin/prodigal-short

# Location of hmmscan binary
# hmmscanbin          /usr/local/bin/hmmscan

# Directory containing the Pfam database files.
# Should be the same as pfamdir in the ripper_run.sh file.
hmmdir              pfam

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
# ripper_run.sh automatically generates an orgnamegbk directory in the
# directory it is run from.
orgnamegbkdir       /home/mnt/orgnamegbk

# Below are some defaults (commented out) that can also
# be specified in this file by removing the hashtag.
# The names are case sensitive!

# minPPlen                   20
# maxPPlen                  120
# prodigalScoreThresh        15
# maxDistFromTE            8000
# fastaOutputLimit            3
# sameStrandReward            5
# flankLen                12500
~~~

### Building *prodigal-short*

This is for documentation only. *prodigal-short* is provided in the
docker version.

The following changes (shown as the output of the *git diff* command)
were made to *prodigal* source files before building
*prodigal-short* according to instructions provided with the
*prodigal* source download.

1. In the file *makefile* first and only occurrence of
`TARGET = prodigal` was changed to `TARGET = prodigal-short`.

~~~ {.diff}
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
~~~

2. In the file *dprog.h* first and only occurrence of
`#define MAX_SAM_OVLP 60` was changed to `#define MAX_SAM_OVLP 45`

~~~ {.diff}
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
~~~

3. In the file *node.h* the following lines

~~~ {.diff}
#define MIN_GENE 90
#define MIN_EDGE_GENE 60
#define MAX_SAM_OVLP 60
#define ST_WINDOW 60
#define OPER_DIST 60
~~~

Were changed to the following lines.

~~~ {.diff}
#define MIN_GENE 60
#define MIN_EDGE_GENE 45
#define MAX_SAM_OVLP 45
#define ST_WINDOW 45
#define OPER_DIST 45
~~~

~~~ {.diff}
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
~~~


### Other supporting Perl scripts

#### pfam\_sqlite.pl

*pfam\_sqlite.pl* takes all the proteins in a specified table in a
specified sqlite3 database and searches them for Pfam domains. The
results of these searches are placed in a new table in the same
sqlite3 database.

#### mergeRidePfam.pl

*mergeRidePfam.pl* merges the information contained in the two sqlite3
tables, one containing the output of prodigal-short and the other
containing the output of Pfam searches on the proteins selected from
the output of prodigal-short. It writes out a tab delimited file.

#### gbkNameAppendOrg.pl

Copies the output genbank files to a new directory with the organism
names appended to the filenames for ease of identification. Files are
copied to the directory specified in the configuration variable
*orgnamegbkdir*.

#### collectFiles.pl

*collectFiles.pl* copies files from a specified directory (and
subdirectories) to another directory if the base filename matches the
specified regular expression.

~~~ {.sh}
perl collectFiles.pl -indir rodout -pat '\.html$' -outdir rodeohtml
~~~

The options shown above are the defaults. *-outdir* may be specified
in *local.conf* as *rodeohtmldir*. Value in the configuration file
takes precedence.
