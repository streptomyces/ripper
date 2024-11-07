FROM streptomyces/stage004
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get install -yqq libbio-searchio-hmmer-perl

# RiPPER
WORKDIR /home/work
RUN git clone https://github.com/streptomyces/ripper.git
WORKDIR /home/work/ripper
RUN git checkout norodeodock

WORKDIR /home/work
RUN cp ripper/norod.sh ripper/minitest.txt ripper/local.conf ./
RUN cp ripper/microtest.txt ./
RUN cp ripper/postprocess.sh ripper/rodconf.pl ./

RUN mkdir /home/work/pfam
RUN cp /home/work/ripper/ripp.hmm /home/work/pfam/
WORKDIR /home/work/pfam
RUN hmmpress ripp.hmm

WORKDIR /home/work

############################################################
############################################################
############################################################

# vim: filetype=dockerfile
