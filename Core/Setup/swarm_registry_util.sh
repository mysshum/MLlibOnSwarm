#!/bin/bash

########################################################################################################################
#
# Setting up Docker registry for Swarm cluster. 
#
# This script is a modification of:
#
# https://codeblog.dotsandbrackets.com/private-registry-swarm/
# 
# to be able to push a local image to a swarm.
#
########################################################################################################################

project_dir=$SPARK_ON_SWARM_DIR
source $project_dir/Core/Config/swarm_config.sh

local_docker_cert_dir="/etc/docker/certs.d/$registry_name:5000"

# Generate self-signed SSL certificate for registry.
echo "Generating SSL certificate for registry."
openssl req -newkey rsa:4096 -nodes -sha256 -keyout registry.key -x509 -days 365 -out registry.crt -subj "/CN=$registry_name"

# Copy SSL certificate to local directory, so local recognises the swarm master node as an SSL certified host.
echo "Copying SSL certificate to local certificate directory."
mkdir -p $local_docker_cert_dir
cp ./registry.crt $local_docker_cert_dir/

echo 'Writing registry host name to /etc/hosts.'
if cat /etc/hosts | grep $registry_name; then
	sed -i "/$registry_name/d" /etc/hosts
fi
echo "$(docker-machine ip $master_node_name) $registry_name" >> /etc/hosts
#echo "$(docker-machine ip $master_node_name) $registry_name" >> ~/.hosts    # Does not work at the moment...
#export HOSTALIASES=~/.hosts

# Copy SSL certificate to swarm nodes.
echo "Copying SSL certificate to swarm nodes."
for ((i=1;i<=$num_nodes;i++)); do
    docker-machine ssh node-$i mkdir -p /home/docker
    docker-machine scp registry.crt node-$i:/home/docker/
    docker-machine ssh node-$i mkdir -p /etc/docker/certs.d/$registry_name:5000
    docker-machine ssh node-$i mv /home/docker/registry.crt /etc/docker/certs.d/$registry_name:5000/ca.crt
    docker-machine ssh node-$i "echo '$(docker-machine ip $master_node_name) $registry_name' >> /etc/hosts"
done

# Create registry service (on master...?)
echo "Creating registry on master node."
docker-machine scp registry.crt $master_node_name:/home/docker && docker-machine scp registry.key $master_node_name:/home/docker
docker-machine ssh $master_node_name docker service create \
    --name registry --publish=5000:5000 \
    --constraint=node.role==manager \
    --mount=type=bind,src=/home/docker,dst=/certs \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
    registry:latest

# Clean up
rm registry.crt registry.key
