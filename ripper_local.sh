#!/bin/bash
# This file is the bash script that provides a full RiPPER analysis
# that encompasses a number of related Perl scripts. Final outputs
# are found in orgnamegbk (GenBank files featuring RiPPER annotations),
# out.txt (tab-delimited table containing retrieved peptides and
# associated data) and rodeohtml (RODEO2 html output).
# This file should be in the directory from where it
# will be run. The local.conf file (featuring any parameter
# modifications) should also be placed in this directory

ripperdir=/home/work/ripper;
pfamdir=/home/work/pfam;
gbkdir=/home/mnt/gbk;
queryfn=/home/mnt/faa/query.faa

# Tab delimited output file for results including pfam hits.
outfile=/home/mnt/out.txt
outfaa=/home/mnt/out.faa
distfaa=/home/mnt/distant.faa
distfile=/home/mnt/distant.txt

# ripper output directory. Contains gbk files.
ripoutdir=/home/mnt/ripout;

# ripper output directory to hold gbk files where filenames
# have the organism name prepended for convenience. 
orgnamegbkdir=/home/mnt/orgnamegbk;


# Below is legacy from the Linux installable version of this script.

perlbin="perl"
pythonbin="python3"



# Make the various directories where output will be placed.
for hcd in $ripoutdir sqlite blastdb $orgnamegbkdir; do
if [[ ! -d $hcd ]]; then
  mkdir $hcd
fi
done

rm sqlite/*

### Setup is now complete. Actual runs below. ###

# ripper_local.pl run for each genbank file in $gbkdir
pcnt=0;
for gbkfn in $(ls --color=never $gbkdir/*.gbk); do 

  echo $perlbin ${ripperdir}/ripper_local.pl -outdir $ripoutdir \
  -queryfn $queryfn -- $gbkfn

  $perlbin ${ripperdir}/ripper_local.pl -outdir $ripoutdir \
  -queryfn $queryfn -- $gbkfn

  : $(( ++pcnt ))
  echo; echo Done $pcnt; echo;
done

# Run the postprocessing scripts

$perlbin ${ripperdir}/pfam_sqlite.pl
$perlbin ${ripperdir}/mergeRidePfam.pl -out ${outfile} -faa ${outfaa} \
-distfile ${distfile} -distfaa ${distfaa} 
$perlbin ${ripperdir}/gbkNameAppendOrg.pl -indir $ripoutdir
# $perlbin ${ripperdir}/collectFiles.pl ${rodoutdir} ${rodeohtmldir} '\.html$'

# Peptide Network Analysis

# pnadir="/home/mnt/pna";
# if [[ ! -d $pnadir ]]; then
# mkdir $pnadir
# fi
# cp ${outfaa} ${distfaa} $pnadir
# 
# # Note change in working directory below.
# pushd $pnadir;
# for gd in $(ls -d --color=never GENENET* 2> /dev/null); do
#   rm -rf $gd
# done
# $perlbin ${ripperdir}/egn_ni.pl -task all
# 
# pnafasdir=$(find . -type d -name 'FASTA')
# 
# cyat="cytoattrib.txt";
# $perlbin ${ripperdir}/make_cytoscape_attribute_file.pl \
# -outfile ${cyat} -pnafasdir $pnafasdir -- ${outfile} ${distfile}
# 
# # Collect EGN networks files.
# 
# $perlbin ${ripperdir}/collect_network_genbanks.pl
# 
# pushd

