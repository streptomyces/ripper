#!/bin/bash
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
pnadir="/home/mnt/pna";
if [[ ! -d $pnadir ]]; then
mkdir $pnadir
fi
cp ${outfaa} ${distfaa} $pnadir

cyat=${pnadir}/cytoattrib.txt;
$perlbin ${ripperdir}/make_cytoscape_attribute_file.pl \
-outfile ${cyat} -- ${outfile}

$perlbin ${ripperdir}/make_cytoscape_attribute_file.pl \
-outfile ${cyat} -append -- ${distfile}


pushd $pnadir;
for gd in $(ls -d --color=never GENENET*); do
  rm -rf $gd
done
$perlbin ${ripperdir}/egn_ni.pl -task all
pushd

