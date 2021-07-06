########################################################################################################################
#
# Spark Linear Regression
#
# Taken from:
# https://towardsdatascience.com/apache-spark-mllib-tutorial-ec6f1cb336a9
#
########################################################################################################################

import pyspark
from pyspark import SparkConf
from pyspark.ml.feature import VectorAssembler
from pyspark.ml.regression import LinearRegression
from pyspark.sql import SparkSession

##############################
# Create Spark session.
##############################

spark_session = \
    SparkSession.builder\
    .config(conf=\
        SparkConf()\
            .setAppName('Spark Linear Regression')\
            .set('spark.sql.shuffle.partitions', '10')\
            .setMaster("spark://master:7077")
    )\
    .getOrCreate()

##############################
# Load boston housing dataset. 
##############################
# !! For now /tmp is hardcoded
data = spark_session.read.csv('/tmp/boston_housing.csv', header=True, inferSchema=True)

##############################
# Build datasets.
##############################

feature_columns = data.columns[:-1] # here we omit the final column
assembler = VectorAssembler(inputCols=feature_columns,outputCol="features")
data_2 = assembler.transform(data)
train, test = data_2.randomSplit([0.7, 0.3])

##############################
# Train linear regression.
##############################

algo = LinearRegression(featuresCol="features", labelCol="medv")
model = algo.fit(train)

##############################
# Evaluate model on test set.
##############################
 
evaluation_summary = model.evaluate(test)
print(evaluation_summary.meanAbsoluteError)
print(evaluation_summary.rootMeanSquaredError)
print(evaluation_summary.r2)

##############################
# Predict out of sample set.
##############################

predictions = model.transform(test)
predictions.select(predictions.columns[13:]).show()

spark_session.stop()
