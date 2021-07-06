########################################################################################################################
#
# Spark-NLP example.
#
# Taken from:
# https://datascienceplus.com/multi-class-text-classification-with-pyspark/
#
########################################################################################################################

import pyspark
from pyspark import SparkConf
from pyspark.ml import Pipeline
from pyspark.ml.classification import LogisticRegression
from pyspark.ml.evaluation import MulticlassClassificationEvaluator
from pyspark.ml.feature import OneHotEncoder, StringIndexer, VectorAssembler
from pyspark.ml.feature import RegexTokenizer, StopWordsRemover, CountVectorizer
from pyspark.sql import SparkSession

##############################
# Create Spark session.
##############################

spark_session = \
    SparkSession.builder\
    .config(conf=\
        SparkConf()\
            .setAppName('Spark Text Classification')\
            .set('spark.sql.shuffle.partitions', '10')\
            .setMaster("spark://master:7077")
    )\
    .getOrCreate()

##############################
# Load dataset. 
##############################
data = spark_session.read.csv('/tmp/train.csv', header=True, inferSchema=True)
data.count()

########################################
# Build and preprocess datasets.
########################################
data = data.select([
    column for column in data.columns 
    if column not in ['Dates', 'DayOfWeek', 'PdDistrict', 'Resolution', 'Address', 'X', 'Y']
])

########################################
# Pipelining for preprocessing 
########################################

# regular expression tokenizer
regexTokenizer = RegexTokenizer(inputCol="Descript", outputCol="words", pattern="\\W")
# stop words
add_stopwords = ["http","https","amp","rt","t","c","the"] 
stopwordsRemover = StopWordsRemover(inputCol="words", outputCol="filtered").setStopWords(add_stopwords)
# bag of words count
countVectors = CountVectorizer(inputCol="filtered", outputCol="features", vocabSize=10000, minDF=5)

label_stringIdx = StringIndexer(inputCol = "Category", outputCol = "label")
preprocessing_pipeline = Pipeline(stages=[regexTokenizer, stopwordsRemover, countVectors, label_stringIdx])

########################################
# Preprocess data
########################################

data_preprocessed = preprocessing_pipeline.fit(data).transform(data)
(train_data, test_data) = data_preprocessed.randomSplit([0.7, 0.3], seed = 100)

########################################
# Fit model
########################################

lr = LogisticRegression(maxIter=20, regParam=0.3, elasticNetParam=0)
lr_model = lr.fit(train_data)

########################################
# Out of sample predictions
########################################

predictions = lr_model.transform(test_data)

########################################
# Accuracy, precision, recall
########################################

evaluator = MulticlassClassificationEvaluator(
    labelCol="label", predictionCol="prediction", metricName="accuracy")
accuracy = evaluator.evaluate(predictions)
print("Accuracy = %g" % (accuracy))

evaluator = MulticlassClassificationEvaluator(
    labelCol="label", predictionCol="prediction", metricName="weightedPrecision")
precision = evaluator.evaluate(predictions)
print("Precision = %g" % (precision))

evaluator = MulticlassClassificationEvaluator(
    labelCol="label", predictionCol="prediction", metricName="weightedRecall")
recall = evaluator.evaluate(predictions)
print("Recall = %g" % (recall))

spark_session.stop()
