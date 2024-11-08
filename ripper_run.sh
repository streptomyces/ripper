#!/bin/bash
#
# This file is the bash script that provides a full RiPPER analysis that
# encompasses a number of related Perl scripts. Final outputs are found in
# orgnamegbk (GenBank files featuring RiPPER annotations), out.txt
# (tab-delimited table containing retrieved peptides and associated data).
#
# This script should be in the directory from where it will be run. The
# local.conf file (featuring any parameter modifications) should also be placed
# in this directory.
#
# Protein network analysis results are in placed in /home/mnt/pna/.



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

# Tab delimited output file for results including pfam hits.
outfile=/home/mnt/out.txt
outfaa=/home/mnt/out.faa
distfaa=/home/mnt/distant.faa
distfile=/home/mnt/distant.txt

# mkcooc.pl output directory
coocoutdir=/home/mnt/coocout;

# ripper output directory. Contains gbk files.
ripoutdir=/home/mnt/ripout;

# ripper output directory. Contains gbk files where filenames
# have the organism name prepended for convenience. 
orgnamegbkdir=/home/mnt/orgnamegbk;

perlbin="perl"
pythonbin="python3"


# Make the various directories where output will be placed.
for hcd in $coocoutdir $ripoutdir sqlite gbkcache $orgnamegbkdir; do
if [[ ! -d $hcd ]]; then
  mkdir $hcd
fi
done

### Set up complete. Actual run below.

for acc in $(${perlbin} ${ripperdir}/cat.pl $queryfn); do 
# for acc in $(cat $queryfn); do 
  $perlbin ${ripperdir}/mkcooc.pl -outdir ${coocoutdir}/${acc} ${acc}
  echo $perlbin ${ripperdir}/ripper.pl -outdir $ripoutdir -- ${coocoutdir}/${acc}/main_co_occur.csv
  $perlbin ${ripperdir}/ripper.pl -outdir $ripoutdir -- ${coocoutdir}/${acc}/main_co_occur.csv
done

# Run the postprocessing scripts

$perlbin ${ripperdir}/pfam_sqlite.pl
$perlbin ${ripperdir}/mergeRidePfam.pl -out ${outfile} -faa ${outfaa} \
-distfile ${distfile} -distfaa ${distfaa} 
$perlbin ${ripperdir}/gbkNameAppendOrg.pl -indir $ripoutdir
pnadir="/home/mnt/pna";
if [[ ! -d $pnadir ]]; then
mkdir $pnadir
fi
cp ${outfaa} ${distfaa} $pnadir

# Note change in working directory below.
pushd $pnadir;
for gd in $(ls -d --color=never GENENET* 2> /dev/null); do
  rm -rf $gd
done
$perlbin ${ripperdir}/egn_ni.pl -task all

pnafasdir=$(find . -type d -name 'FASTA')

cyat="cytoattrib.txt";
$perlbin ${ripperdir}/make_cytoscape_attribute_file.pl \
-outfile ${cyat} -pnafasdir $pnafasdir -- ${outfile} ${distfile}

# Collect EGN networks files.

$perlbin ${ripperdir}/collect_network_genbanks.pl

pushd

