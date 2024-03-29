#!/bin/bash
# This file is the bash script that provides a full RiPPER analysis
# that encompasses a number of related Perl scripts. Final outputs
# are found in orgnamegbk (GenBank files featuring RiPPER annotations),
# out.txt (tab-delimited table containing retrieved peptides and
# associated data) and rodeohtml (RODEO2 html output).
# This file should be in the directory from where it
# will be run. The local.conf file (featuring any parameter
# modifications) should also be placed in this directory


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
outfaa=/home/mnt/out.faa
distfaa=/home/mnt/distant.faa
distfile=/home/mnt/distant.txt

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
pythonbin="python3"


# Make a couple of symlinks to keep rodeo_main.py happy.
if [[ ! -L hmm_dir ]]; then
ln -s $pfamdir ./hmm_dir
fi

if [[ ! -L confs ]]; then
ln -s ${rodeodir}/confs ./
fi

# Make the various directories where output will be placed.
for hcd in $rodoutdir $ripoutdir sqlite gbkcache $orgnamegbkdir $rodeohtmldir; do
if [[ ! -d $hcd ]]; then
  mkdir $hcd
fi
done

rm sqlite/*

### Setup is now complete. Actual runs below. ###

# rodeo run and ripper.pl run for each query in $queryfn
pcnt=0;
for acc in $(${perlbin} ${ripperdir}/cat.pl $queryfn); do 
# for acc in $(cat $queryfn); do 
  echo $pythonbin ${rodeodir}/rodeo_main.py -out ${rodoutdir}/${acc} ${acc}
  $pythonbin ${rodeodir}/rodeo_main.py -out ${rodoutdir}/${acc} ${acc}
  echo $perlbin ${ripperdir}/ripper.pl -outdir $ripoutdir -- ${rodoutdir}/${acc}/main_co_occur.csv
  $perlbin ${ripperdir}/ripper.pl -outdir $ripoutdir -- ${rodoutdir}/${acc}/main_co_occur.csv
  : $(( ++pcnt ))
  echo; echo Done $pcnt; echo;
done

# Run the postprocessing scripts

$perlbin ${ripperdir}/pfam_sqlite.pl
$perlbin ${ripperdir}/mergeRidePfam.pl -out ${outfile} -faa ${outfaa} \
-distfile ${distfile} -distfaa ${distfaa} 
$perlbin ${ripperdir}/gbkNameAppendOrg.pl -indir $ripoutdir
$perlbin ${ripperdir}/collectFiles.pl ${rodoutdir} ${rodeohtmldir} '\.html$'

# Peptide Network Analysis

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

