FROM ubuntu
# FROM bioperl/bioperl
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -yqq apt-utils
RUN apt-get install -yqq build-essential wget \
git curl zip unzip ghostscript gsfonts parallel \
cmake csh vim

RUN apt-get install -yqq sqlite3 bioperl ncbi-blast+
# RUN apt-get install -yqq hmmer

RUN apt-get install -yqq python3 python3-dev
RUN apt-get install -yqq python3-pip

RUN ln -s /usr/bin/python3 /usr/bin/python

# RUN apt-get install python3-wheel # already present.
RUN apt-get install -yqq python3-biopython python3-zipp \
python3-sklearn-lib
# python3-zipp might provide pathlib.
RUN pip3 install --break-system-packages pathlib

#=======================================
# Dependencies for MEME
RUN apt-get update && apt-get install -yqq \
libfile-which-perl libhtml-template-perl libjson-perl \
libxml2-dev liblog-log4perl-perl libxml-compile-soap-perl \
libxml-compile-wsdl11-perl libxslt1-dev zlib1g-dev \
libopenmpi-dev

# MEME
WORKDIR /home/work
ADD meme-5.5.5.tar.gz /home/work/
WORKDIR /home/work/meme-5.5.5
RUN ./configure --prefix=/usr/local --with-url="http://meme-suite.org"
RUN make && make install
ENV PATH="/usr/local/libexec/meme-5.5.4:${PATH}"

# HMMER
WORKDIR /home/work
ADD hmmer-3.4.tar.gz /home/work/
WORKDIR /home/work/hmmer-3.4
RUN ./configure --prefix=/usr/local
RUN make
RUN make check
RUN make install


# Prodigal (prodigal-short)
# rsync -virtn --exclude ".git/" ~/github/Prodigal ./
WORKDIR /home/work
ADD Prodigal/ /home/work/Prodigal
WORKDIR /home/work/Prodigal
RUN make install
#=======================================

WORKDIR /home/work
RUN mkdir -p /home/work/sqlite
RUN mkdir -p /home/work/pfamscan
RUN mkdir -p /home/work/blastdb

# See builds.sh
# vim: filetype=dockerfile
