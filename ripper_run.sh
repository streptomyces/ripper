# This file should be in the directory from where it
# will be run as
#
#  source ripper_run.sh
#
#


homedir="/home/sco";
queryfn="minitest.txt";
ripperdir=${homedir}/fromgithub/ripper;
rodeodir=${homedir}/fromgithub/rodeo2;
pfamdir=${homedir}/blast_databases/pfam

# output dirs
rodoutdir=rodout;
ripoutdir=ripout;


# $perlbin and $pythonbin. Both these should have BioPerl and Biopython
# (respectively) installed for them. It is not uncommon to have more than one
# versions of perl and python installed on the same machine. Hence the need for
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

