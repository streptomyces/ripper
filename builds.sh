# docker buildx calls

# arch="linux/arm64,linux/amd64";
arch="linux/amd64";
stagepre="stage";
buildcmd="docker buildx build"

$buildcmd --platform $arch \
-t streptomyces/ubcheck -f 001.dockerfile .

$buildcmd --platform $arch \
-t streptomyces/${stagepre}001 --push -f 001.dockerfile .

$buildcmd --platform $arch \
-t streptomyces/${stagepre}002 --push -f 002.dockerfile .

$buildcmd --platform $arch \
-t streptomyces/${stagepre}003 --push -f 003.dockerfile .

$buildcmd --platform $arch \
-t streptomyces/${stagepre}004 --push -f 004.dockerfile .
