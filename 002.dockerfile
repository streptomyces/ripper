FROM streptomyces/stage001
# FROM bioperl/bioperl
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
ENV DEBIAN_FRONTEND noninteractive

# ADD hhsuite-linux-sse2.tar.gz /usr/local/
# ADD hhsuite.tar.gz /usr/local/
ADD psipred.4.02.tar.gz /usr/local/
# The two below are from
# https://ftp.ncbi.nlm.nih.gov/blast/executables/legacy.NOTSUPPORTED/2.2.26/
ADD blast-2.2.26-x64-linux.tar.gz /usr/local/
ADD ncbi.tar.gz /usr/local/

# export PATH="$(pwd)/bin:$(pwd)/scripts:$PATH"

# PSIPred
WORKDIR /usr/local/psipred/src
RUN make
RUN make install

# legacy BLAST
WORKDIR /usr/local
RUN ./ncbi/make/makedis.csh

ENV PATH="/usr/local/psipred/bin:/usr/local/ncbi/bin:${PATH}"

WORKDIR /home/work

############################################################
############################################################
############################################################

# docker buildx build --platform linux/arm64,linux/amd64 \
# -t streptomyces/ripdock003 --push -f 003.dockerfile .

# docker pull streptomyces/ripdock003
# docker run --rm -it -v ${PWD}:/home/mnt streptomyces/ripdock003

# python rodeo_main.py -out /home/mnt/rodout /home/mnt/minitest.txt

# vim: filetype=dockerfile
