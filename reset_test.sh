pushd /home/mnt/
rm -rf Networks
rm -rf distant.faa distant.txt out.faa out.txt
rm -rf orgnamegbk/* pna/* ripout/* rodeohtml/* rodout/*
pushd /home/work/
./norod.sh microtest.txt
