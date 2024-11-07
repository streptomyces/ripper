#!/usr/bin/bash
# docker buildx calls

# arch="linux/arm64,linux/amd64";
arch="linux/amd64";
stagepre="stage";
buildcmd="docker buildx build"
nc="--no-cache"
# nc=""
lorp="--load"; # load or push


# {{{ Stage Zero for testing only.
# $buildcmd --platform $arch \
# -t streptomyces/stage000 $lorp -f 000.dockerfile .
# 
# docker pull streptomyces/stage000
# docker run --rm -it -v ${PWD}:/home/mnt streptomyces/stage000
# }}}

sts=$(date +%s);

$buildcmd $nc --platform $arch \
-t streptomyces/${stagepre}001 $lorp -f 001.dockerfile .

sleep 10
$buildcmd $nc --platform $arch \
-t streptomyces/${stagepre}002 $lorp -f 002.dockerfile .

sleep 10
$buildcmd $nc --platform $arch \
-t streptomyces/${stagepre}003 $lorp -f 003.dockerfile .

sleep 10
$buildcmd $nc --platform $arch \
-t streptomyces/${stagepre}004 $lorp -f 004.dockerfile .

sleep 10
$buildcmd $nc --platform $arch \
-t streptomyces/rippertest $lorp -f ripper.dockerfile .

ets=$(date +%s);

els=$(( ets - sts ));
ss=$(( els % 60 ));
mm=$(( els / 60 ));
hh=$(( mm / 60 ));
mm=$(( mm % 60 ))

printf "%s\n" "Finished at $(date)";
printf "In: %02d:%02d:%02d\n" $hh $mm $ss;


# docker pull streptomyces/norodeodock
# docker run --rm -it -v ${PWD}:/home/mnt streptomyces/norodeodock
# ved 00{1,2,3,4}.dockerfile norodeodock.dockerfile
