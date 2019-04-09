FROM bioperl/bioperl
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
# ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -yqq ncbi-blast+ hmmer unzip wget git
RUN apt-get install -yqq sqlite3 build-essential python-dev python-pip
RUN apt-get install -yqq bioperl
RUN pip install -q biopython

# The Pfam database
RUN mkdir -p /home/work/pfam
ADD ripp.hmm /home/work/pfam/
ADD prodigal-short /usr/local/bin/


WORKDIR /home/work
RUN git clone https://github.com/streptomyces/ripper.git
WORKDIR /home/work/ripper
RUN git checkout master



WORKDIR /home/work/pfam
RUN wget --no-verbose ftp://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.hmm.gz
# RUN wget --no-verbose ftp://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.hmm.dat.gz
RUN gunzip *.gz

# && rm Pfam-A.hmm

# RUN cat /home/work/ripper/ripp.hmm >> Pfam-A.hmm
RUN cat ripp.hmm >> Pfam-A.hmm
RUN hmmpress Pfam-A.hmm
RUN hmmpress ripp.hmm


WORKDIR /home/work

RUN mkdir -p /home/work/sqlite
RUN mkdir -p /home/work/pfamscan
# RUN mkdir -p /home/work/ripper

#

WORKDIR /home/work
RUN git clone https://github.com/thedamlab/rodeo2.git

RUN cp ripper/ripper_run.sh ripper/minitest.txt ripper/local.conf ./
RUN cp ripper/postprocess.sh ./

WORKDIR /home/work

