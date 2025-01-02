FROM streptomyces/stage002
# FROM bioperl/bioperl
MAINTAINER Govind Chandra <govind.chandra@jic.ac.uk>
ENV DEBIAN_FRONTEND noninteractive

# HHSuite
WORKDIR /usr/local
ADD hh-suite /usr/local/hh-suite/
# RUN git clone https://github.com/soedinglab/hh-suite.git
RUN mkdir -p hh-suite/build
WORKDIR hh-suite/build
RUN cmake -DCMAKE_INSTALL_PREFIX=. ..
RUN make -j 1
RUN make install


ENV HHLIB="/usr/local/hh-suite"
ENV PATH="/usr/local/hh-suite/build/bin:/usr/local/hh-suite/build/scripts:${PATH}"

COPY HHPaths.pm /usr/local/hh-suite/scripts/

WORKDIR /home/work

# See builds.sh
# vim: filetype=dockerfile

