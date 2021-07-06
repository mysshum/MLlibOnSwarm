########################################################################################################################
#
# A wrapper script that runs a pyspark .py script on a spark swarm.
#
# Original source: https://testdriven.io/blog/running-spark-with-docker-swarm-on-digitalocean/#.XMB9XflAmzA.reddit 
# Original author: M. Herman - https://github.com/testdrivenio/spark-docker-swarm
#
# This script serves as annotations and notes of the part of the above tutorial for running on a swarm on a Digitalocean 
# cluster. Some refactoring has been done.
#
# This has been tested on 
# Debian 9, Docker version 19.03.8, build afacb8b7f0, docker-machine version 0.16.0, build 702c267f. 
#
########################################################################################################################

source $SPARK_ON_SWARM_DIR/Core/Config/swarm_config.sh

# Get arguments of script.
dataset_filepath=''
python_filepath=''

while getopts ":p:c:d:" flag; do
    case $flag in
        p)
			python_filepath=$OPTARG ;;
        d)
			dataset_filepath=$OPTARG ;;
        \?)
			echo "Invalid option: -$OPTARG" >&2
			exit 1 ;;
        :)
			echo "Option -$OPTARG requires an argument." >&2
			exit 1 ;; 
	esac
done
if [ -z python_filepath ]; then
	echo 'A python script must be passed with -p. Exiting.';
	exit 1
fi

echo $dataset_filepath
echo $python_filepath

# Process script arguments
#python_filepath=$1
python_file=$(basename $python_filepath)

# Point the Docker daemon at $master_node_name (Swarm master), update the EXTERNAL_IP environment variable.
eval $(docker-machine env $master_node_name)
export EXTERNAL_IP=$(docker-machine ip $master_node_name)
 
# Deploy stack using $master_node_name's Docker daemon.
echo "Deploying stack."
docker stack deploy --compose-file=$SPARK_ON_SWARM_DIR/Core/Docker/ComposeYAMLs/docker-swarm.yml spark     
docker service scale spark_worker=$num_nodes 

# Push datasets if applicable to all nodes.
eval $(docker-machine env -u)
if ! [ -z $dataset_filepath ]; then
	for ((i=1;i<=num_nodes;i++)); do
		#echo "node-$i"
		eval $(docker-machine env node-$i)
		container_ids=$(docker container ls -q)
		for container_id in $container_ids; do
			#echo $container_id
			docker-machine ssh node-$i docker cp $dataset_filepath $container_id:/tmp/
			#docker exec $container_id ls -1 /tmp
			#echo -e "\n"
		done
	done
fi
eval $(docker-machine env -u)
eval $(docker-machine env $master_node_name)

# Point the Docker daemon at the node the Spark master is on.
spark_master_node=$(docker service ps --format "{{.Node}}" spark_master)
echo $spark_master_node
eval $(docker-machine env $spark_master_node)

# Push python script.
echo 'Pushing python script file to swarm.'
spark_master_id=$(docker ps --filter name=master --format "{{.ID}}")
echo $spark_master_id
docker cp $python_filepath $spark_master_id:/tmp

# Run spark-submit.
echo 'Running python script on spark swarm.'
docker exec $spark_master_id \
    bin/spark-submit \
        --master spark://master:7077 \
        --class endpoint \
        /tmp/$python_file

# Point to swarm master and kill stack.
eval $(docker-machine env $master_node_name)
docker stack rm spark

# Unset Docker variables to point daemon back to local Docker.
eval $(docker-machine env -u)
