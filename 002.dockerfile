FROM streptomyces/stage001
# FROM bioperl/bioperl
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
ENV DEBIAN_FRONTEND noninteractive

RUN python -m pip install "pathlib"
RUN python -m pip install "scikit-learn"

# RODEO
WORKDIR /home/work
RUN mkdir -p /home/work/sqlite
RUN mkdir -p /home/work/pfamscan
RUN mkdir -p /home/work/blastdb

WORKDIR /home/work

############################################################
############################################################
############################################################

# docker buildx build --platform linux/arm64,linux/amd64 \
# -t streptomyces/ripdock002 --push -f 002.dockerfile .

# docker build -f 002.dockerfile -t "streptomyces/ripp002" . 2>&1 | tee build002.std
# docker build --no-cache -f 002.dockerfile -t "streptomyces/ripp002" . 2>&1 | tee build002.std

# docker run --rm -it -v ${PWD}:/home/mnt streptomyces/ripp002


# vim: filetype=dockerfile

