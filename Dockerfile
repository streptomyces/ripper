FROM ubuntu:bionic
# FROM bioperl/bioperl
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
# ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -yqq apt-utils \
sqlite3 build-essential python-dev python-pip \
python3-dev python3-pip bioperl ncbi-blast+ hmmer unzip \
wget git

RUN pip3 install numpy scikit-learn biopython


# File::Which missing.
# HTML::Template missing.
# JSON missing.
# Log::Log4perl
# XML::Compile::SOAP11
# XML::Compile::WSDL11
# Math::CDF
# apt-get install libpdl-netcdf-perl

# Requirements for MEME-suite.
RUN apt-get update && apt-get install -yqq \
libfile-which-perl libhtml-template-perl libjson-perl \
libxml2-dev liblog-log4perl-perl libxml-compile-soap-perl \
libxml-compile-wsdl11-perl libxslt1-dev

# Add some files.
RUN mkdir -p /home/work/pfam
ADD ripp.hmm /home/work/pfam/
ADD prodigal-short /usr/local/bin/

WORKDIR /home/work
RUN wget http://meme-suite.org/meme-software/5.1.0/meme-5.1.0.tar.gz
RUN tar -xzvf meme-5.1.0.tar.gz

WORKDIR /home/work/meme-5.1.0
RUN ./configure --prefix=/usr/local --with-url="http://meme-suite.org"
RUN make && make install
RUN echo 'export PATH=/usr/local/libexec/meme-5.1.0:$PATH' \
> /root/.profile
RUN /bin/bash -c 'source /root/.profile'

# Pfam
WORKDIR /home/work/pfam
RUN wget --no-verbose \
ftp://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.hmm.gz
RUN gunzip *.gz
RUN cat ripp.hmm >> Pfam-A.hmm
RUN hmmpress Pfam-A.hmm
RUN hmmpress ripp.hmm


WORKDIR /home/work
RUN git clone https://github.com/streptomyces/ripper.git
WORKDIR /home/work/ripper
RUN git checkout nopepdock

WORKDIR /home/work
RUN git clone https://github.com/the-mitchell-lab/rodeo2.git
RUN mkdir -p /home/work/sqlite
RUN mkdir -p /home/work/pfamscan

RUN cp ripper/ripper_run.sh ripper/minitest.txt ripper/local.conf ./
RUN cp ripper/postprocess.sh ./

RUN apt-get install -yqq vim

RUN rm meme*.gz
WORKDIR /home/work

