########################################################################################################################
#
# Spark random forest classifier
#
# Taken from:
# https://towardsdatascience.com/apache-spark-mllib-tutorial-part-3-complete-classification-workflow-a1eb430ad069
#
########################################################################################################################

import pyspark
from pyspark import SparkConf
from pyspark.ml.classification import RandomForestClassifier
from pyspark.ml.evaluation import BinaryClassificationEvaluator
from pyspark.ml.feature import StringIndexer, VectorAssembler
from pyspark.ml.feature import Imputer
from pyspark.sql import SparkSession

##############################
# Create Spark session.
##############################

spark_session = \
    SparkSession.builder\
    .config(conf=\
        SparkConf()\
            .setAppName('Spark random forest classifier')\
            .set('spark.sql.shuffle.partitions', '10')\
            .setMaster("spark://master:7077")
    )\
    .getOrCreate()

##############################
# Load boston housing dataset. 
##############################

# !! For now /tmp is hardcoded
data = spark_session.read.csv('/tmp/titanic.csv', header=True, inferSchema=True)

##############################
# Build datasets.
##############################

data = data.select(['Survived', 'Pclass', 'Gender', 'Age', 'SibSp', 'Parch', 'Fare'])

# Age needs to be imputed.
imputer = Imputer(strategy='mean', inputCols=['Age'], outputCols=['AgeImputed'])
imputer_model = imputer.fit(data)
data = imputer_model.transform(data)

# Index categorical features.
gender_indexer = StringIndexer(inputCol='Gender', outputCol='GenderIndexed')
gender_indexer_model = gender_indexer.fit(data)
data = gender_indexer_model.transform(data)

# Assemble features.
assembler = VectorAssembler(inputCols=['Pclass', 'SibSp', 'Parch', 'Fare', 'AgeImputed', 'GenderIndexed'], outputCol='features')
data = assembler.transform(data)

##############################
# Build and train random 
# forest classifier.
##############################
algo = RandomForestClassifier(featuresCol='features', labelCol='Survived')
model = algo.fit(data)

##############################
# In-sample evaluation
##############################
predictions = model.transform(data)
predictions.select(['Survived','prediction', 'probability']).show()
evaluator = BinaryClassificationEvaluator(labelCol='Survived', metricName='areaUnderROC')
print()
print()
print(evaluator.evaluate(predictions))
print()
print()

spark_session.stop()
