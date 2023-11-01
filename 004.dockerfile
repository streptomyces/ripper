FROM streptomyces/ripdock003
# FROM bioperl/bioperl
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
ENV DEBIAN_FRONTEND noninteractive

WORKDIR /home/work

ADD RREFinder /home/work/RREFinder/
RUN chmod a+x RREFinder/RRE.py
RUN ln -s rodeo2/confs ./
RUN ln -s rodeo2/hmm_dir ./
RUN ln -s RREFinder/data ./

ENV PATH="/home/work/RREFinder:${PATH}"
# ENV BLASTMAT="/usr/local/blast-2.2.26/data"
ENV BLASTMAT="/usr/local/ncbi/data"


WORKDIR /home/work

############################################################
############################################################
############################################################

# docker buildx build --platform linux/arm64,linux/amd64 \
# -t streptomyces/ripdock004 --push -f 004.dockerfile .

# docker pull streptomyces/ripdock004
# docker run --rm -it -v ${PWD}:/home/mnt streptomyces/ripdock004


# python rodeo2/rodeo_main.py -out /home/mnt/rodout /home/mnt/minitest.txt

# vim: filetype=dockerfile
