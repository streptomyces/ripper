FROM streptomyces/ripp004
# FROM bioperl/bioperl
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
ENV DEBIAN_FRONTEND noninteractive

# RiPPER
WORKDIR /home/work
RUN git clone https://github.com/streptomyces/ripper.git
WORKDIR /home/work/ripper
RUN git checkout master

WORKDIR /home/work
RUN ln -s rodeo2/hmm_dir ./pfam
RUN cp ripper/ripper_run.sh ripper/minitest.txt ripper/local.conf ./
RUN cp ripper/postprocess.sh ripper/rodconf.pl ripper/pna.sh ./
RUN rm meme*.gz

WORKDIR /home/work

############################################################
############################################################
############################################################

# docker buildx build -f 005.dockerfile -t "streptomyces/ripp005" . 2>&1 | tee build005.std
# docker buildx build --no-cache -f 005.dockerfile -t "streptomyces/ripp005" . 2>&1 | tee build005.std

# docker run --rm -it -v ${PWD}:/home/mnt streptomyces/ripp005

# ./ripper_run.sh /home/mnt/minitest.txt

# vim: filetype=dockerfile
