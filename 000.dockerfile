FROM ubuntu
# FROM bioperl/bioperl
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -yqq \
build-essential git curl zip unzip parallel

RUN apt-get install -yqq zlib1g-dev

WORKDIR /home/work

ADD Prodigal/ /home/work/Prodigal
WORKDIR /home/work/Prodigal
RUN make install


############################################################
############################################################
############################################################

# docker buildx build --platform linux/arm64,linux/amd64 \
# -t streptomyces/stage000 --push -f 000.dockerfile .

# docker run --rm -it -v ${PWD}:/home/mnt streptomyces/stage000

# vim: filetype=dockerfile
