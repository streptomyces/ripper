FROM ubuntu
# FROM bioperl/bioperl
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -yqq apt-utils
RUN apt-get install -yqq build-essential wget \
git curl zip unzip ghostscript gsfonts parallel

RUN apt-get install -yqq sqlite3 bioperl ncbi-blast+
# RUN apt-get install -yqq hmmer

RUN apt-get install -yqq python3 python3-dev
RUN apt-get install -yqq python3-pip

RUN ln -s /usr/bin/python3 /usr/bin/python
# RUN ln -s /usr/bin/pip3 /usr/bin/pip
# Above commented out because /usr/bin/pip exists.

RUN python -m pip install "wheel"
RUN python -m pip install "biopython"

# For Meme
RUN apt-get update && apt-get install -yqq \
libfile-which-perl libhtml-template-perl libjson-perl \
libxml2-dev liblog-log4perl-perl libxml-compile-soap-perl \
libxml-compile-wsdl11-perl libxslt1-dev zlib1g-dev \
libopenmpi-dev

# RUN apt-get install -yqq python3 python3-pip


WORKDIR /home/work
RUN wget http://meme-suite.org/meme-software/5.5.4/meme-5.5.4.tar.gz
RUN tar -xzvf meme-5.5.4.tar.gz

WORKDIR /home/work/meme-5.5.4
RUN ./configure --prefix=/usr/local --with-url="http://meme-suite.org"
RUN make && make install
# RUN echo 'export PATH=/usr/local/libexec/meme-5.5.1:$PATH' \
# > /root/.profile
# RUN /bin/bash -c 'source /root/.profile'
ENV PATH="/usr/local/libexec/meme-5.5.4:${PATH}"

# hmmer has to be built from source for arm64

WORKDIR /home/work
RUN wget http://eddylab.org/software/hmmer/hmmer.tar.gz
RUN tar -xzvf hmmer.tar.gz
WORKDIR /home/work/hmmer-3.4
RUN ./configure --prefix=/usr/local
RUN make
RUN make check
RUN make install


WORKDIR /home/work

############################################################
############################################################
############################################################

# docker buildx build --platform linux/arm64,linux/amd64 \
# -t streptomyces/ripdock001 --push -f 001.dockerfile .

# vim: filetype=dockerfile
