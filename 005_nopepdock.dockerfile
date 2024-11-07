FROM streptomyces/ripp004
# FROM bioperl/bioperl
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
ENV DEBIAN_FRONTEND noninteractive

# RiPPER
WORKDIR /home/work
RUN git clone https://github.com/streptomyces/ripper.git
WORKDIR /home/work/ripper
RUN git checkout nopepdock

WORKDIR /home/work
RUN ln -s rodeo2/hmm_dir ./pfam
RUN cp ripper/nopep.sh ripper/minitest.txt ripper/local.conf ./
RUN cp ripper/postprocess.sh ripper/rodconf.pl ./
RUN rm meme*.gz
RUN rm -rf meme-5.5.1

WORKDIR /home/work

############################################################
############################################################
############################################################

# docker buildx build -f 005_nopepdock.dockerfile -t "streptomyces/nopepdock" . 2>&1 | tee nopepdock.std
# docker buildx build --no-cache -f 005_nopepdock.dockerfile -t "streptomyces/nopepdock" . 2>&1 | tee nopepdock.std

# docker run --rm -it -v ${PWD}:/home/mnt streptomyces/nopepdock
# docker push streptomyces/nopepdock:latest

# ./nopep.sh /home/mnt/minitest.txt

# vim: filetype=dockerfile
