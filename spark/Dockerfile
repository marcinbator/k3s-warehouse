# syntax=docker/dockerfile:1.7
FROM spark:3.5.7-scala2.12-java17-python3-ubuntu@sha256:9ec659a98c6a11096c4ea18742af2f2e3963186ba3e958d132e59a78b6f584d0

USER root

RUN apt-get update \
 && apt-get -y upgrade \
 && apt-get -y purge linux-libc-dev \
 && apt-get -y autoremove \
 && rm -rf /var/lib/apt/lists/*

RUN cd /opt/spark \
 && rm -rf examples data \
 && rm -f jars/derby-*.jar jars/zookeeper-*.jar jars/mesos-*.jar jars/spark-mesos_*.jar \
          jars/hive-*.jar jars/spark-hive*.jar jars/libthrift-*.jar

ADD --chmod=644 --checksum=sha256:53f9ae03c681a30a50aa17524bd9790ab596b28481858e54efd989a826ed3a4a \
    https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar /opt/spark/jars/
ADD --chmod=644 --checksum=sha256:251115656f2b66ad644b6fc69152db5275ed26d8747fecabe59ac59bc1a4b42b \
    https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.797/aws-java-sdk-bundle-1.12.797.jar /opt/spark/jars/
ADD --chmod=644 --checksum=sha256:73914527305a40cce504b0d3d90b23caf565136912d607ae8ae7c5895512332c \
    https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.14/postgresql-42.7.14.jar /opt/spark/jars/

COPY --chmod=644 job.py /opt/spark/work-dir/job.py

USER 185
