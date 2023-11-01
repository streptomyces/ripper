FROM ubuntu
# FROM bioperl/bioperl
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -yqq \
build-essential git curl zip unzip parallel

WORKDIR /home/work

############################################################
############################################################
############################################################

# docker buildx build --platform linux/arm64,linux/amd64 \
# -t streptomyces/stage001 --push -f 001.dockerfile .

# vim: filetype=dockerfile
