#!/bin/bash

########################################################################################################################
# Script to set up machine for running Docker images on SparkOnSwarm. 
#
# create_env_vars.sh should be sourced first before this script is run.
########################################################################################################################

apt-get update && apt-get install -y curl

# Install docker
tmp_dir='./tmp'
mkdir $tmp_dir
pushd $tmp_dir
curl https://download.docker.com/linux/debian/dists/stretch/pool/stable/amd64/docker-ce_19.03.8~3-0~debian-stretch_amd64.deb --output docker-ce.deb
curl https://download.docker.com/linux/debian/dists/stretch/pool/stable/amd64/docker-ce-cli_19.03.8~3-0~debian-stretch_amd64.deb --output docker-ce-cli.deb
curl https://download.docker.com/linux/debian/dists/stretch/pool/stable/amd64/containerd.io_1.4.3-1_amd64.deb --output containerd.io.deb
dpkg -i containerd.io.deb && rm containerd.io.deb
dpkg -i docker-ce-cli.deb && rm docker-ce-cli.deb
dpkg -i docker-ce.deb && rm docker-ce.deb
popd
rmdir $tmp_dir

# Install docker-machine
# https://docs.docker.com/machine/install-machine/
base=https://github.com/docker/machine/releases/download/v0.16.0 \
	&& curl -L $base/docker-machine-$(uname -s)-$(uname -m) >/tmp/docker-machine \
	&& sudo mv /tmp/docker-machine /usr/local/bin/docker-machine \
	&& chmod +x /usr/local/bin/docker-machine

# Install docker-compose
# https://docs.docker.com/compose/install/
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Build docker image for SparkOnSwarm.
pushd $SPARK_ON_SWARM_DIR/Core/Docker/DockerFiles
docker build -t $SPARK_ON_SWARM_IMAGE_TAG - < $SPARK_ON_SWARM_DOCKERFILE
popd

