#!/bin/bash

########################################################################################################################
#
# Funtionality to bring up or down Digitalocean nodes for KerasSparkSwarm applications.
#
# This script currently takes global parameters from Config/SwarmConfig.sh so, consequently, is not intended to be used 
# as a standalone tool. 
#
# When -u is used, the first node is created separately and in a blocking way, to prevent race conditions for TLS certificates. See response of @oscar-martin in,
# https://github.com/docker/machine/issues/3845
#
########################################################################################################################

project_dir=$SPARK_ON_SWARM_DIR
source $project_dir/Core/Config/swarm_config.sh

function _spin_up_node  {
	node_label=$1
	docker-machine create \
		--driver digitalocean \
		--digitalocean-access-token $do_key \
		--engine-install-url "https://releases.rancher.com/install-docker/19.03.9.sh" \
		--digitalocean-size $node_size \
		--digitalocean-image $do_image \
		$node_label
}

function spin_up_nodes {
    echo "Spinning up nodes."
    _spin_up_node node-1 & first_pid=$!
    wait $first_pid
    for ((i=2;i<=num_nodes;i++)); do
	_spin_up_node node-$i & pids[${i-1}]=$!
    done
    for pid in ${pids[*]}; do
        wait $pid
    done
}

function initialise_swarm {

    # Initialise swarm on $master_node_name. Master node cannot be drained as it runs the image registry for swarm.
    echo "Initialising swarm."
    docker-machine ssh $master_node_name -- docker swarm init --advertise-addr $(docker-machine ip $master_node_name)
    #docker-machine ssh $master_node_name -- docker node update --availability drain $master_node_name
    swarm_worker_token=`docker-machine ssh $master_node_name docker swarm join-token worker | grep token | awk '{ print $5 }'`

    # Add other nodes as workers.
    for ((i=2;i<=$num_nodes;i++)); do
        docker-machine ssh node-$i -- docker swarm join --token $swarm_worker_token $(docker-machine ip $master_node_name):2377;
    done

}

function restart_nodes {
    echo "Stopping service at master node."
    docker-machine ssh $master_node_name 'docker service rm $(docker service list -q)'
    echo "Restarting nodes."
    for ((i=1;i<=num_nodes;i++)); do
        docker-machine restart node-$i &
    done
}

function spin_down_nodes {
    echo "Spinning down nodes."
    for ((i=1;i<=num_nodes;i++)); do
        docker-machine rm -y node-$i
    done
}

while getopts "usrd" opt; do
    case $opt in 
        u) spin_up_nodes;;
        s) initialise_swarm;;
        r) restart_nodes;;
        d) spin_down_nodes;;
        *) echo 'Error: script takes flags -u (spin up nodes), -s (initialise swarm), -r (restart nodes), or -d (spin down nodes).'
           exit 2;;
        ?) echo 'Error: script takes flags -u (spin up nodes), -s (initialise swarm), -r (restart nodes), or -d (spin down nodes).'
           exit 2;;
    esac
done

