# MLlibOnSwarm

Integrated pipelining for running Spark MLlib on Docker Swarm on Digitalocean

# Introduction

MLlibOnSwarm allows users to run Spark code in a containerised and reproducible manner on a cloud by bringing together (Py)Spark MLlib, Docker and DigitalOcean via docker-machine. This project came out of play around with the codebase found at,

https://github.com/testdrivenio/spark-docker-swarm

by M. Herman. Apart from documenting my learning, some additional functionalities are added for my own curiosity and use.

* The controlling machine (e.g. the machine from which one calls the application and controls the Spark cluster) is intended to also be a node hosted in the same cloud as the cluster. To my mind, this has the following benefits for the individual user aside from the usual advantages of cloud computing.
  * The hardware and software at the entrypoint of the pipeline can be standardised and replicated. (From painful experiences, I decided to separate machines critical for my work with my personal laptop as much as possible to avoid kernel/drivers/package management/dependency hell.) 
  * Hosting the main machine on cloud also allows one to leverage the cloud's storage services to streamline the practice of backing up.
  * It is sometimes faster to use the cloud's internet connection to download large files, and it is definitely faster for the main node and cluster to communicate such files within the cloud's local network. 
  * One can also easily scale up the computing power of the non-cluster parts (such as for plotting results returned by the cluster, which may be heavy but undistributable without significant dev work).
* The Swarm cluster has its own private Docker image repository. 
  * This is necessary should the cluster be scaled across networks and clouds. This is more of a point of curiosity at the moment, but it may be built upon in the future.

Citations to other parts used in this project can be found in *Citations* below, and in the header of the relevant source code. This is intended to be a proof-of-concept: the software is currently not production-grade, nor is it supported by me in any way.

# Example

*Currently, MLlibOnSwarm assumes that the user has root access on the Linux machine controlling the Spark nodes (mainly to write to /etc/hosts for some network settings). It is therefore **highly recommended** that everything be done on a DigitalOcean machine to avoid MLlibOnSwarm overwriting important settings on one's personal computer.*

As an example, we will setup MLlibOnSwarm on a freshly created DigitalOcean Droplet (virtual machine) and run the linear regression application in Apps/SparkML/LinearRegression.

* Create a [DigitalOcean](www.digitalocean.com) account. Obtain an [API token](https://docs.digitalocean.com/reference/api/create-personal-access-token/), say <code>\<API_TOKEN\></code>. Spin up a Droplet: this will be the machine used to control the swarm.  *The code has been tested on a Droplet with 8 Gb of RAM and 4 vCPU's running Debian 9.* Start a bash session to control this machine (for example using ssh).

* Choose a location to install MLlibOnSwarm, say <code>\<MLlibOnSwarmLocation\></code>. Download MLlibOnSwarm. It is recommended to use git for this:
  ```
  apt-get update && apt-get install git
  cd <MLlibOnSwarmLocation>
  git clone https://github.com/mysshum/MLlibOnSwarm.git
  cd MLlibOnSwarm
  ```

* Set up the environment variables of this Droplet. In the shell script <code>env_vars.sh</code>, change the variable <code>SPARK_ON_SWARM_DIR</code> variable to the full path of <code>\<MLlibOnSwarmLocation\></code>. Source the variables:
  ```
  source env_vars.sh
  ```

* Install Docker, docker-compose, docker-machine and build the Spark docker image. This is done by running 
  ```
  ./setup.sh
  ``` 
  *Note that creating the image will take a few minutes.*

* Configure Swarm cluster. This can be done through the following shell variables;
  
  <code>do_key</code>: sets the DigitalOcean API token. This should be <code>\<API_TOKEN\></code>.
  
  <code>node_size</code>: sets the type of virtual machine used for each node of the Spark cluster. A list of valid types can be accessed as described [here](https://developers.digitalocean.com/documentation/v2/#sizes).
  
  <code>do_image</code>: sets the Docker image used for each node of the Spark cluster. A list of valid types can be accessed as described [here](https://developers.digitalocean.com/documentation/v2/#images).
  
  <code>num_nodes</code>: sets the total number of nodes in the Spark cluster. The total number of nodes is the number of worker nodes plus a single spark master node.

* Create the node machines for the Spark cluster. This can be done by:
  ```
  ./Core/Setup/nodes_util.sh -u
  ./Core/Setup/nodes_util.sh -s
  ```
  The flag <code>-u</code> creates the nodes Droplets on DigitalOcean, and the flag <code>-s</code> initialises Swarm mode over the created nodes.
  
* Create a private Swarm registry. This registry is created on the Spark master node to which the Spark image is pushed and from which Spark worker nodes pull this image. The registry is created using:
  ```
  ./Core/Setup/swarm_registry_util.sh
  ```
  *Note that this step writes the registry node's IP address to /etc/hosts.*

* Run the application. To run the linear regression application, run,
  ```
  ./Apps/SparkML/LinearRegression/run_on_swarm.sh
  ```
  In brief, the application script wraps the PySpark Python script <code>Apps/SparkML/LinearRegression/linear_regression.py</code> and passes it to the core functionality of MLlibOnSwarm. (See below.)
  
  (At this point, before destroying the cluster, one can run other similarly wrapped PySpark applications such as <code>Apps/SparkML/RandomForestClassifier/run_on_swarm.sh</code> and <code>Apps/SparkML/NLP/run_on_swarm.sh</code>.)

* Destroy the cluster:
  ```
  ./Core/Setup/nodes_util.sh -d
  ```
  
# Wrapping a PySpark Python application

As seen above, a PySpark script such as <code>Apps/SparkML/LinearRegression/linear_regression.py</code> is run by wrapping it in a shell script, in this case <code>Apps/SparkML/LinearRegression/run_on_swarm.sh</code>. On a high level, this shell script is performs two functionalities: it uses Docker to push the necessary image (the Spark image, in this case) to the cluster registry and to pass the PySpark python file (and any necessary input files) to <code>Core/run_spark_on_swarm.sh</code>, which in turn sends these files to the cluster and tells the Spark master run a PySpark session on the python script.

One can copy and boilerplate any of the <code>run_on_swarm.sh</code> scripts to wrap any similar PySpark python script. 
  
# Using cloud service providers other than DigitalOcean 
  
In principle, MLlibOnSwarm can be run on any other cloud that is compatible with docker-machine: one merely has to tweak the implementation in <code>Core/Setup/nodes_utils.sh</code>. However, MLlibOnSwarm has only been tested on DigitalOcean clusters.

# Potential future fixes

* Install Apache Arrow: (apache.bintray.com/arrow/debian/apache-arrow-archive-keyring-latest-buster.deb returns a 403 Forbidden at this time).

* docker-machine sometimes throw <code>tls: bad certificate</code> errors when creating nodes. Not really sure what to do with that yet...

* Remove the need for root access.

# References
  
  The following are citations to pieces of code from other sources used and modified for this project. They also appear in the header of the file where they are used.
  
  Apps:
  * https://towardsdatascience.com/apache-spark-mllib-tutorial-ec6f1cb336a9
  * https://datascienceplus.com/multi-class-text-classification-with-pyspark/
  * https://towardsdatascience.com/apache-spark-mllib-tutorial-part-3-complete-classification-workflow-a1eb430ad069
  
  Core:
  * https://github.com/testdrivenio/spark-docker-swarm
  * https://testdriven.io/blog/running-spark-with-docker-swarm-on-digitalocean/
  * https://codeblog.dotsandbrackets.com/private-registry-swarm/
  
