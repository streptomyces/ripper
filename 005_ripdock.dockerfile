FROM streptomyces/ripdock004
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
RUN rm -rf meme-5.5.4

WORKDIR /home/work

############################################################
############################################################
############################################################

# docker buildx build --platform linux/arm64,linux/amd64 \
# -t streptomyces/ripdock005 --push -f 005_ripdock.dockerfile .

# docker pull streptomyces/ripdock005
# docker run --rm -it -v ${PWD}:/home/mnt streptomyces/ripdock005


# ./ripper_run.sh /home/mnt/minitest.txt

# vim: filetype=dockerfile
