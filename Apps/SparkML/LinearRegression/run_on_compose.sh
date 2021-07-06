#!/bin/bash

########################################################################################################################
# Runs linear regression on Spark x Docker compose on local machine
########################################################################################################################

compose_yaml=$SPARK_ON_SWARM_DIR/Core/Docker/ComposeYAMLs/docker-compose.yml

py_script_name=linear_regression.py
py_script=$SPARK_ON_SWARM_DIR/Apps/SparkML/LinearRegression/$py_script_name
dataset=$SPARK_ON_SWARM_DIR/Apps/SparkML/LinearRegression/boston_housing.csv

# Set the SPARK_PUBLIC_DNS environment variable to either localhost or the IP address of the Docker Machine
# (The SPARK_PUBLIC_DNS sets the public DNS name of the Spark master and workers.)
export EXTERNAL_IP=localhost

# Run a single container for spark.
docker-compose -f $compose_yaml --verbose up -d --build
export MASTER_CONTAINER_ID=$(docker ps --filter name=master --format "{{.ID}}")
export WORKER_CONTAINER_ID=$(docker ps --filter name=worker --format "{{.ID}}")

# Run test script
docker cp $dataset $MASTER_CONTAINER_ID:/tmp
docker cp $dataset $WORKER_CONTAINER_ID:/tmp
docker cp $py_script $MASTER_CONTAINER_ID:/tmp
docker exec $MASTER_CONTAINER_ID bin/spark-submit --master spark://master:7077 --class endpoint /tmp/$py_script_name

# Spin down container
docker-compose -f $compose_yaml down
