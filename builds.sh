# docker buildx calls

arch="linux/arm64,linux/amd64";
# arch="linux/amd64";
stagepre="stage";
buildcmd="docker buildx build"
nc="--no-cache"


# {{{ Stage Zero for testing only.
$buildcmd --platform $arch \
-t streptomyces/stage000 --push -f 000.dockerfile .

docker pull streptomyces/stage000
docker run --rm -it -v ${PWD}:/home/mnt streptomyces/stage000
# }}}

$buildcmd $nc --platform $arch \
-t streptomyces/${stagepre}001 --push -f 001.dockerfile .

sleep 10
$buildcmd $nc --platform $arch \
-t streptomyces/${stagepre}002 --push -f 002.dockerfile .

sleep 10
$buildcmd $nc --platform $arch \
-t streptomyces/${stagepre}003 --push -f 003.dockerfile .

sleep 10
$buildcmd $nc --platform $arch \
-t streptomyces/${stagepre}004 --push -f 004.dockerfile .

sleep 10
$buildcmd $nc --platform $arch \
-t streptomyces/norodeodock --push -f norodeo.dockerfile .

docker pull streptomyces/norodeodock
docker run --rm -it -v ${PWD}:/home/mnt streptomyces/norodeodock

