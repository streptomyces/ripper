FROM streptomyces/stage001
# FROM bioperl/bioperl
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
ENV DEBIAN_FRONTEND noninteractive

RUN python -m pip install "pathlib"
RUN python -m pip install "scikit-learn"

# RODEO
WORKDIR /home/work
COPY rodeo2 /home/work/rodeo2/
# RUN git clone https://github.com/the-mitchell-lab/rodeo2.git
RUN mkdir -p /home/work/sqlite
RUN mkdir -p /home/work/pfamscan
RUN mkdir -p /home/work/blastdb

# Pfam
WORKDIR /home/work/rodeo2/hmm_dir
# RUN wget --no-verbose \
# ftp://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.hmm.gz
# RUN gunzip *.gz
# # RUN cat ripp.hmm >> Pfam-A.hmm
# RUN hmmpress Pfam-A.hmm
# RUN hmmpress ripp.hmm
# 
# 
# # RiPPER
# WORKDIR /home/work
# RUN git clone https://github.com/streptomyces/ripper.git
# WORKDIR /home/work/ripper
# RUN git checkout master
# 
# WORKDIR /home/work
# RUN cp ripper/ripper_run.sh ripper/minitest.txt ripper/local.conf ./
# RUN cp ripper/postprocess.sh ripper/rodconf.pl ripper/pna.sh ./
# 
# RUN rm meme*.gz
# RUN ln -s rodeo2/confs ./

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

