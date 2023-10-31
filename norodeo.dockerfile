FROM ubuntu
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -yqq apt-utils
RUN apt-get install -yqq build-essential wget \
git curl zip unzip ghostscript gsfonts parallel

RUN apt-get install -yqq sqlite3 bioperl ncbi-blast+

# RiPPER
WORKDIR /home/work
RUN git clone https://github.com/streptomyces/ripper.git
WORKDIR /home/work/ripper
RUN git checkout norodeo

WORKDIR /home/work
# RUN ln -s rodeo2/hmm_dir ./pfam
RUN cp ripper/norod.sh ripper/minitest.txt ripper/local.conf ./
RUN cp ripper/postprocess.sh ripper/rodconf.pl ./

WORKDIR /home/work

############################################################
############################################################
############################################################

# ./nopep.sh /home/mnt/minitest.txt



# docker login
# docker buildx ls
# docker buildx create --name strepbuilder
# docker buildx use strepbuilder
# docker buildx inspect --bootstrap
# # Create a new repository in dockerhub e.g. streptomyces/norodeo_ma
# docker buildx build --platform linux/amd64,linux/arm64 \
# -f norodeo.dockerfile -t streptomyces/norodeo_ma:latest --push .

# vim: filetype=dockerfile

