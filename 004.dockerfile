FROM streptomyces/stage003
# FROM bioperl/bioperl
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
ENV DEBIAN_FRONTEND noninteractive

WORKDIR /home/work

ADD RREFinder /home/work/RREFinder/
RUN chmod a+x RREFinder/RRE.py
# RUN ln -s rodeo2/confs ./
# RUN ln -s rodeo2/hmm_dir ./
RUN ln -s RREFinder/data ./

ENV PATH="/home/work/RREFinder:${PATH}"
ENV BLASTMAT="/usr/local/ncbi/data"

WORKDIR /home/work

# See builds.sh
# vim: filetype=dockerfile
