########################################################################################################################
# Utilities
########################################################################################################################

import numpy
import pandas
from keras.datasets import mnist

from pyspark.ml.feature import OneHotEncoder, VectorAssembler

# Returns the MNIST dataset as a Spark dataframe. 
def make_mnist_spark_dataframe(
    spark_session, get_labels :  bool = True, use_csv_intermediate : bool = True, sample_prop : float = 1.0
):

    # Make MNIST pandas dataframe.
    (x_train, y_train), (x_test, y_test) = mnist.load_data()
    x_train = ((x_train.astype(numpy.float32) - 127.5)/127.5).reshape(60000, 28*28)
    x_test = ((x_test.astype(numpy.float32) - 127.5)/127.5).reshape(10000, 28*28)
    np_features = numpy.concatenate([x_train, x_test], axis=0)
    features_df = pandas.DataFrame(np_features)
    if get_labels:
        np_labels = numpy.concatenate([y_train, y_test], axis=0)
        labels_ser = pandas.Series(np_labels, name='label')
        dataset_df = pandas.concat([features_df, labels_ser], axis=1)
    else:
        dataset_df = features_df

    # Do random sampling if on..
    if sample_prop < 1.0:
        num_sample = int(numpy.ceil(sample_prop * dataset_df.shape[0]))
        dataset_df = dataset_df.iloc[numpy.random.choice(range(dataset_df.shape[0]), size=(num_sample,), replace=False)]

    # Make Spark dataframe
    if use_csv_intermediate:
        dataset_df.to_csv('mnist.csv', index=False)
        spark_df = spark_session.read.csv('mnist.csv', header=True, inferSchema=True)
    else:
        spark_df = spark_session.createDataFrame(dataset_df)
    
    # Make features.
    spark_df = VectorAssembler(inputCols=list(map(str, features_df.columns)), outputCol="features").transform(spark_df)

    # Make labels: One-hot encode labels into SparseVectors
    encoder = OneHotEncoder(inputCols=['label'], outputCols=['label_vec'], dropLast=False)
    model = encoder.fit(spark_df)
    spark_df = model.transform(spark_df)

    return spark_df

