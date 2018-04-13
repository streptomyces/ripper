
for hcd in rodout rideout sqlite gbkcache orgnamegbk; do
if [[ -d $hcd ]]; then
  rm -r $hcd/*
else
  mkdir $hcd
fi
done

asdir=/Users/nouser;
codedir=${asdir}/code/ride;
if [[ ! -e hmm_dir ]]; then
  ln -s ${asdir}/databases/pfam ./hmm_dir
fi
if [[ ! -e confs ]]; then
  ln -s ${asdir}/github/rodeo2/confs ./
fi
queryfn="supermini.txt";
for acc in $(cat $queryfn); do 
  echo python ${asdir}/github/rodeo2/rodeo_main.py -out rodout/${acc} ${acc}
  python ${asdir}/github/rodeo2/rodeo_main.py -out rodout/${acc} ${acc}
  echo perl ${codedir}/test_ride_sp.pl -outdir rideout -- rodout/${acc}/main_co_occur.csv
  perl ${codedir}/test_ride_sp.pl -outdir rideout -- rodout/${acc}/main_co_occur.csv
  # break;
done

  
perl ${codedir}/pfam_sqlite.pl
perl ${codedir}/mergeRidePfam.pl -out out.txt
perl ${codedir}/gbkNameAppendOrg.pl -indir rideout
perl ${codedir}/collectFiles.pl rodout '\.html'

