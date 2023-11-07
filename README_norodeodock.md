# norod.sh

## Pull the docker image

~~~ {.sh}
docker pull streptomyces/norodeodock
~~~

Following installation, run the container using the following command, where
your input accession list file is stored in `/home/tom/work` on Linux and
MacOS systems or `C:/Users/tom/work` on a MS Windows system. (substitute your
relevant directories in place of these):

## Get a container

~~~ {.sh}
# Example usage on Linux
docker run -it -v ${PWD}:/home/mnt streptomyces/norodeodock
docker run -it -v /home/tom/work:/home/mnt streptomyces/norodeodock

# Example usage on MS Windows.
docker run -it -v %cd%:/home/mnt streptomyces/norodeodock
docker run -it -v C:/Users/tom/work:/home/mnt streptomyces/norodeodock
~~~

Do not change the `/home/mnt` part. This refers to a directory in the
container and scripts in the container expect to find this directory.
The host directory you mount on `/home/mnt` in the container is where
the output directories and files are written to. You can place your
input list in the mounted host directory on the host side and access
it in /home/mnt/ on the container side. See the example **Run on your
own list** below.

## The Pfam-A database

This image does not include the Pfam-A database which is needed to run
the analyses. Including it would make the image very big and it will
be difficult to keep the database updated to the latest release.

Your directory which appears as `/home/mnt/` on the container side
should contain the Pfam database inside a directory named `pfam`.

From inside a running container you could make the database by
stepping through the commands below. This needs to be done only once
everytime the Pfam-A models are updated.

~~~ 
cd /home/mnt/
mkdir pfam # Only if it does not already exist.
cd pfam
wget \
'https://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.hmm.gz'
gunzip Pfam-A.hmm.gz
hmmpress Pfam-A.hmm
cd /home/work/
~~~

The above should result in the following files in `/home/mnt/pfam/`.

    Pfam-A.hmm
    Pfam-A.hmm.h3f
    Pfam-A.hmm.h3i
    Pfam-A.hmm.h3m
    Pfam-A.hmm.h3p

## Carrying out an analysis in the running container

Following the docker run command above, to ensure that `norod.sh`  is
working correctly, you can run a small test analysis on the accessions
that are included in a test file named *minitest.txt*. There is also
a *microtest.txt* which has just the top three lines
of *minitest.txt*.

~~~ {.sh}
./norod.sh microtest.txt
./norod.sh minitest.txt
~~~

### Run on your own list

Use the following command to analyse your own list, substituting in a
relevant filename for *te_accessions.txt*: 

~~~ {.sh}
./norod.sh /home/mnt/te_accessions.txt
~~~

### Modification of analysis parameters

Some configuration is read from the file `local.conf`. If you have a
NCBI API key then you should place it in this file. Please also put
your email address in this file. It is sent to NCBI along with requests
so they can analyse usage of their services.

## Output files

The output consists of genbank files in the folder `orgnamegbk`. There
should be one genbank file for each protein accession for which a
genbank file was successfully retrieved from Genbank. The output of
`egn_ni.pl` is in the folder named `pna`. 

## Build commands (For Govind only. Others please ignore.)

~~~ 
docker login
docker buildx ls
docker buildx create --name strepbuilder
docker buildx use strepbuilder
docker buildx inspect --bootstrap
# Create a new repository in dockerhub e.g. streptomyces/norodeodock
docker buildx build --platform linux/amd64,linux/arm64 \
-f norodeo.dockerfile -t streptomyces/norodeodock:latest --push .
~~~


