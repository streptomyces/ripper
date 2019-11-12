#!/bin/bash

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


perlbin="perl"
pythonbin="python"

########################################################
### Users should not need to make changes below this ###
########################################################

# Run the postprocessing scripts

$perlbin ${ripperdir}/pfam_sqlite.pl
$perlbin ${ripperdir}/mergeRidePfam.pl -out ${outfile}
$perlbin ${ripperdir}/gbkNameAppendOrg.pl -indir $ripoutdir
$perlbin ${ripperdir}/collectFiles.pl ${rodoutdir} ${rodeohtmldir} '\.html$'

