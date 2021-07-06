#########################################################################################
# Modified from:
# M. Herman - https://github.com/testdrivenio/spark-docker-swarm
#########################################################################################

FROM debian:buster

# Get system utilities.
RUN apt-get update \
  && apt-get install -y software-properties-common curl unzip git cmake autoconf flex bison ca-certificates lsb-release wget build-essential \
        pkg-config zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev \
        libffi-dev libsqlite3-dev wget libbz2-dev \
  && apt-get clean 

# Build Python3.8
RUN wget https://www.python.org/ftp/python/3.8.3/Python-3.8.3.tgz \
    && tar xf Python-3.8.3.tgz \
    && cd Python-3.8.3 \ && ./configure --enable-optimizations \
    && make install 

ENV PYTHONHASHSEED 0
ENV PYTHONIOENCODING UTF-8
ENV PIP_DISABLE_PIP_VERSION_CHECK 1

#### Install Apache Arrow
###RUN wget https://apache.bintray.com/arrow/$(lsb_release --id --short | tr 'A-Z' 'a-z')/apache-arrow-archive-keyring-latest-$(lsb_release --codename --short).deb \
###    && apt install -y -V ./apache-arrow-archive-keyring-latest-$(lsb_release --codename --short).deb \
###    && apt update \
###    && apt-get install -y libjemalloc-dev libboost-dev libboost-filesystem-dev libboost-system-dev libboost-regex-dev \
###    && apt-get install -y libarrow-dev libarrow-glib-dev libarrow-dataset-dev libarrow-flight-dev \
###        libarrow-python-dev

# JAVA (Try using openjdk-8 as installation of SystemDs seems to require it.)
#RUN apt-get update && apt-get install -y openjdk-11-jre-headless
RUN apt-add-repository 'deb http://security.debian.org/debian-security stretch/updates main' \
    && apt update \
    && apt install -y openjdk-8-jdk-headless \
    && apt install -y maven

# HADOOP
ENV HADOOP_VERSION 3.2.2
ENV HADOOP_HOME /usr/hadoop-$HADOOP_VERSION
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV PATH $PATH:$HADOOP_HOME/bin
RUN curl -sL --retry 3 \
  "http://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz" \
  | gunzip \
  | tar -x -C /usr/ \
 && rm -rf $HADOOP_HOME/share/doc \
 && chown -R root:root $HADOOP_HOME

# SPARK
ENV SPARK_VERSION 3.1.1
ENV SPARK_PACKAGE spark-${SPARK_VERSION}-bin-without-hadoop
ENV SPARK_HOME /usr/spark-${SPARK_VERSION}
ENV SPARK_DIST_CLASSPATH="$HADOOP_HOME/etc/hadoop/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/tools/lib/*"
ENV PATH $PATH:${SPARK_HOME}/bin
RUN curl -sL --retry 3 \
  "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_PACKAGE}.tgz" \
  | gunzip \
  | tar x -C /usr/ \
 && mv /usr/$SPARK_PACKAGE $SPARK_HOME \
 && chown -R root:root $SPARK_HOME

# Install python packages. 
RUN python3.8 -m pip install numpy==1.16.6 py4j==0.10.9 h5py==2.10.0 matplotlib scipy==1.4.1 pandas sklearn pyspark spark-nlp\
    && apt-get install -y python-opencv  \
    && apt-get install -y vim-python-jedi \
    && python3.8 -c 'import sparknlp; sparknlp.start()' 

# Point to spark user's home directory.
WORKDIR $SPARK_HOME

#ENV SPARK_CLASSPATH /root/.ivy2/jars/com.johnsnowlabs.nlp_spark-nlp_2.12-3.1.0.jar
