# norod.sh

## Pull the docker image

~~~ {.sh}
docker pull streptomyces/norodeo
~~~

Following installation, run the container using the following command, where
your input accession list file is stored in `/home/tom/rippwork` on Linux and
MacOS systems or `C:/Users/tom/rippwork` on a MS Windows system. (substitute your
relevant directories in place of these):

~~~ {.sh}
# Example usage on Linux
docker run -it -v /home/tom/rippwork:/home/mnt streptomyces/norodeo

# Example usage on MS Windows.
docker run -it -v C:/Users/tom/rippwork:/home/mnt streptomyces/norodeo
~~~

Do not change the `/home/mnt` part. This refers to a directory in the container and scripts in the container expect to find this directory. The host directory you mount on `/home/mnt` in the container is where the output directories and files are written to. You can place your input list in the mounted host directory on the host side and access it in /home/mnt/ on the container side. See the example **Run on your own list** below.

### Carrying out an analysis in the running container

Following the docker run command above, to ensure RiPPER is working correctly, you can run a small test analysis on 3 accessions that are included in a test file named *minitest.txt*. Use the following command:

~~~ {.sh}
./norod.sh minitest.txt
~~~

#### Run on your own list

Use the following command to analyse your own list, substituting in a relevant filename for *te_accessions.txt*:

~~~ {.sh}
./norod.sh /home/mnt/te_accessions.txt
~~~

### Modification of analysis parameters

Currently, *local.conf* needs to be directly modified to change the above parameters, although a future update will allow for parameters to be directly set in the command line. If Docker is used, the *local.conf* file is automatically present in the RiPPER container with the above defaults. To modify this, once the container is running, copy it into the host directory on your computer:

~~~ {.sh}
cp local.conf /home/mnt
~~~

Modify and save the file using a text editor and then use the following command to copy it back into the working directory for RiPPER:

~~~ {.sh}
cp /home/mnt/local.conf /home/work
~~~

## Output files

The RiPPER output consists of a series of output files and folders:

#### orgnamegbk
A folder containing Genbank files for all retrieved gene clusters. These files are named by the host organism and the input accession number

