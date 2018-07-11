# This file is the bash script that provides a full RiPPER analysis
# that encompasses a number of related Perl scripts. Final outputs
# are found in orgnamegbk (GenBank files featuring RiPPER annotations),
# out.txt (tab-delimited table containing retrieved peptides and
# associated data) and rodeohtml (RODEO2 html output).
# This file should be in the directory from where it
# will be run. The local.conf file (featuring any parameter
# modifications) should also be placed in this directory
#
# Run this file with the following command from the analysis directory:
#
#  source ripper_run.sh
#
#


homedir="/home/work";
queryfn="minitest.txt";
ripperdir=/home/work/ripper;
rodeodir=/home/work/rodeo2;
pfamdir=/home/work/pfam

# output dirs
rodoutdir=/home/mnt/rodout;
ripoutdir=/home/mnt/ripout;


# $perlbin and $pythonbin. Both these should have BioPerl and Biopython
# (respectively) installed for them. It is not uncommon to have more than one
# versions of perl and python installed on the same machine. Hence the need for
# the next two lines.

perlbin="perl"
pythonbin="python"

########################################################
### Users should not need to make changes below this ###
########################################################

# Make a couple of symlinks to keep rodeo_main.py happy.
ln -s $pfamdir ./hmm_dir
ln -s ${rodeodir}/confs ./

# Make the various directories where output will be placed.
for hcd in $rodoutdir $ripoutdir sqlite gbkcache orgnamegbk rodeohtml; do
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
$perlbin ${ripperdir}/mergeRidePfam.pl -out out.txt
$perlbin ${ripperdir}/gbkNameAppendOrg.pl -indir $ripoutdir
$perlbin ${ripperdir}/collectFiles.pl ${rodoutdir} '\.html$'

