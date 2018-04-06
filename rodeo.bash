#!/usr/bin/bash
    
export PFAMDB=/home/sco/installs/rodeo
export rodeodir=/home/sco/installs/rodeo
export rodeozip=rodeo_source_v20160603.zip
export rwb=rodeowork
if [[ ! -d $rwb ]]
  then
  mkdir $rwb
fi 
# listfn=minitest
export listfn=TfuA_Actino_Accessions_080217.txt

fp-clean () {
for iline in $(cat $listfn); do
  line=$(basenameNoex.pl $iline);
  rwd=${rwb}"/"${line}
  if [[ -e $rwd ]]
    then
    rm -rf $rwd
  fi
done
}

#{{{ fp-rwd()
fp-rwd () {
for iline in $(cat $listfn); do
  line=$(basenameNoex.pl $iline);
  rwd=${rwb}"/"${line}
  if [[ -e $rwd ]]
    then
    rm -rf $rwd
  fi
  mkdir $rwd
  cwd=$(pwd);
  rwdd=$cwd"/"$rwd;
  zip=$rodeodir"/"$rodeozip;
  cp $zip $rwd
  cp rodeo.conf $rwd;
  unzip $rwdd"/"$rodeozip -d $rwd;
  uid=$(perl code/acc2uid.pl -- $line);
  echo $uid > $rwd/list;
done
}
#}}}

#   echo cd $rwd '&&' perl rodeo.pl -l $rwd/list -o $rwd/out.html \
#   -c $rwd/rodeo.conf -x \
#   -csv $rwd/out.csv -csva $rwd/outarch.csv '&&' cd -

#{{{ fp-rodeo
fp-rodeo () {
for iline in $(cat $cwd/$listfn); do
  line=$(basenameNoex.pl $iline);
  rwd=${rwb}"/"${line}
  echo cd $rwd '&&' perl rodeo.pl -l list -o out.html \
  -c rodeo.conf -x \
  -csv out.csv -csva outarch.csv '&&' cd -
done
}
#}}}

fp-clean
fp-rwd

fp-rodeo

fp-rodeo | parallel --jobs 2

# Wait here till the above is done. Then proceed below.

# export listfn=re.list
fp-ride () {
  listbn=$(basenameNoex.pl $listfn);
  ofn=${listbn}.csv
    for iline in $(cat $listfn); do
      line=$(basenameNoex.pl $iline);
      incsv=$rwb"/"${line}"/outarch.csv"
      echo perl code/ride.pl -- $incsv
    done
}

export rwb=rodeowork
listfn=minitest
fp-ride

export listfn=TfuA_Actino_Accessions_080217.txt
fp-ride
fp-ride | parallel --jobs 3

# The above produces outarch.gbk and outarch.faa

