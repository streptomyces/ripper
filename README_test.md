# RiPPer test version

## Pull the docker image

~~~ {.sh}
docker pull streptomyces/rippertest
~~~

Following installation, run the container using the following command, where
your input accession list file is stored in `/home/tom/work` on Linux and
MacOS systems or `C:/Users/tom/work` on a MS Windows system. (substitute your
relevant directories in place of these):

## Get a container

Below, the environment variable NCBI_API_KEY in the host environment
is being added to the container environment and, NCBI_API_EMAIL is
being explicitly set in the container environment to the email address
specified.

~~~ {.sh}
docker run --rm -it -v $PWD:/home/mnt \
-v $HOME/databases/pfam:/mnt/pfam \
--env NCBI_API_KEY
--env NCBI_API_EMAIL=govind.chandra@jic.ac.uk \
streptomyces/rippertest
~~~

Do not change the `/home/mnt` part or the `/mnt/pfam` part.
`/home/mnt` refers to a directory in the
container and scripts in the container expect to find this directory.
The host directory you mount on `/home/mnt` in the container is where
the output directories and files are written to. You can place your
input list in the mounted host directory on the host side and access
it in `/home/mnt/` on the container side. See the example **Run on your
own list** below.

## The Pfam-A database

This image does not include the Pfam-A database which is needed to run
the analyses. Including it would make the image very big and it will
be difficult to keep the database updated to the latest release.

Your directory which appears as `/mnt/pfam` on the container side
should contain the Pfam database inside a directory named `pfam`.

From inside a running container you could make the database by
stepping through the commands below. This needs to be done only once
everytime the Pfam-A models are updated.

~~~ 
cd /mnt
mkdir pfam # Only if it does not already exist.
cd pfam
wget \
'https://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.hmm.gz'
gunzip Pfam-A.hmm.gz
hmmpress Pfam-A.hmm
cd /home/work/
~~~

The above should result in the following files in `/mnt/pfam/`.

    Pfam-A.hmm
    Pfam-A.hmm.h3f
    Pfam-A.hmm.h3i
    Pfam-A.hmm.h3m
    Pfam-A.hmm.h3p

## Carrying out an analysis in the running container

Following the docker run command above, to ensure that `ripper_run` is
working correctly, you can run a small test analysis on the accessions
that are included in a test file named *minitest.txt*. There is also
a *microtest.txt* which has just the top three lines
of *minitest.txt*.

~~~ {.sh}
./ripper_run microtest.txt
./ripper_run minitest.txt
~~~

### Run on your own list

Use the following command to analyse your own list, substituting in a
relevant filename for *te_accessions.txt*: 

~~~ {.sh}
./ripper_run /home/mnt/te_accessions.txt
~~~

### Options

The defaults of some options are mentioned below.

    --minPPlen             =      20;
    --maxPPlen             =     120;
    --prodigalScoreThresh  =     7.5;
    --maxDistFromTE        =    8000;
    --fastaOutputLimit     =       3;
    --sameStrandReward     =       5;
    --flankLen             =   40000;
    --scan_signif_thresh   =    0.05;

These can be changes when invoking `ripper_run`. For example, to
change the maximum distance from the TE to the precursor peptide
(`maxDistFromTE`) `--maxDistFromTE 7000` can be used. Note that
capitalisation is significant. All lower-case form of the option
should also work but wrong mixture of upper and lower case will not
work.

Two other options are `--ncbiapikey` and `--email` both of which are unset by
default (unless provided as environment variables at the time of instantiating
the container). If you provide these then the values are sent along with
requests to NCBI and they use these for the analysis of the usage of their
services. It is best to provide these as environment variables (see *Get a
container* above) so you need not use these options.

## Output files

The output consists of genbank files in the folder `orgnamegbk`. There
should be one genbank file for each protein accession for which a
genbank file was successfully retrieved from Genbank. The output of
`egn_ni.pl` is in the folder named `pna`. 

