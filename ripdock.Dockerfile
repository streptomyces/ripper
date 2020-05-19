FROM streptomyces/pre-ripdock
# FROM bioperl/bioperl
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
# ENV DEBIAN_FRONTEND noninteractive
# ripdock


# RiPPER
WORKDIR /home/work
RUN git clone https://github.com/streptomyces/ripper.git
WORKDIR /home/work/ripper
RUN git checkout master

WORKDIR /home/work
RUN cp ripper/ripper_run.sh ripper/minitest.txt ripper/local.conf ./
RUN cp ripper/postprocess.sh ripper/rodconf.pl ripper/pna.sh ./


# docker build -f ripdock.Dockerfile -t "streptomyces/twostep" .
# docker build --no-cache -f ripdock.Dockerfile -t "streptomyces/twostep" .

