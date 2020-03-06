#!/bin/bash
dir="pna";
ecp="10,40,40,14,5,50";

while getopts "e:d:" opts; do
case ${opts} in
  e)
   ecp=${OPTARG}
   ;;
  d)
   dir=${OPTARG}
   ;;
esac
done


if [[ $dir == "" ]]; then
  echo "Option -d (directory) is required".
  exit;
fi

echo  $dir$'\t'$ecp

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


# Peptide Network Analysis

pnadir=$dir;
if [[ ! -d $pnadir ]]; then
mkdir $pnadir
fi
cp ${outfaa} ${distfaa} $pnadir

# Note change in working directory below.
pushd $pnadir;
for gd in $(ls -d --color=never GENENET*); do
  rm -rf $gd
done
$perlbin ${ripperdir}/egn_ni.pl -task all

pnafasdir=$(find . -type d -name 'FASTA')

cyat="cytoattrib.txt";
$perlbin ${ripperdir}/make_cytoscape_attribute_file.pl \
-outfile ${cyat} -pnafasdir $pnafasdir -- ${outfile} ${distfile}

pushd


