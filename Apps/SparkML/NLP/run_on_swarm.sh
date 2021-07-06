#!/bin/bash

########################################################################################################################
#
# Spark x Docker Swarm on Digitalocean.
# 
########################################################################################################################

source $SPARK_ON_SWARM_DIR/Core/Config/swarm_config.sh

python_file=$SPARK_ON_SWARM_DIR/Apps/SparkML/NLP/nlp.py
dataset_file=train.csv
dataset_filepath=$SPARK_ON_SWARM_DIR/Apps/SparkML/NLP/$dataset_file

# Push image to registry.
echo 'Pushing Spark image to registry on master node.'
docker image tag $SPARK_ON_SWARM_IMAGE_TAG $SPARK_ON_SWARM_REGISTRY:5000/$SPARK_ON_SWARM_IMAGE_TAG 
docker push $SPARK_ON_SWARM_REGISTRY:5000/$SPARK_ON_SWARM_IMAGE_TAG 

# Push datasets to docker machines
for ((i=1;i<=num_nodes;i++)); do
	docker-machine scp $dataset_filepath node-$i:/tmp/
done

# Run on spark swarm.
$SPARK_ON_SWARM_DIR/Core/run_spark_on_swarm.sh -p $python_file -d '/tmp/'$dataset_file
