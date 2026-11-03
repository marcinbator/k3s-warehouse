import os

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import (DateType, DoubleType, IntegerType, StringType,
                               StructField, StructType)

S3_ENDPOINT = os.environ["S3_ENDPOINT"]
S3_ACCESS_KEY = os.environ["S3_ACCESS_KEY"]
S3_SECRET_KEY = os.environ["S3_SECRET_KEY"]
SOURCE = os.environ.get("SOURCE_PATH", "s3a://raw/*.csv")

PG_URL = os.environ["PG_URL"]
PG_USER = os.environ["PG_USER"]
PG_PASSWORD = os.environ["PG_PASSWORD"]
TARGET_TABLE = os.environ.get("TARGET_TABLE", "dwh.sales_daily")

REGIONS = [
    "dolnoslaskie", "kujawsko-pomorskie", "lubelskie", "lubuskie", "lodzkie",
    "malopolskie", "mazowieckie", "opolskie", "podkarpackie", "podlaskie",
    "pomorskie", "slaskie", "swietokrzyskie", "warminsko-mazurskie",
    "wielkopolskie", "zachodniopomorskie",
]

SCHEMA = StructType([
    StructField("order_id", IntegerType()),
    StructField("order_date", DateType()),
    StructField("region", StringType()),
    StructField("product", StringType()),
    StructField("quantity", IntegerType()),
    StructField("unit_price", DoubleType()),
    StructField("_corrupt_record", StringType()),
])

spark = (
    SparkSession.builder.appName("sales-etl")
    .config("spark.hadoop.fs.s3a.endpoint", S3_ENDPOINT)
    .config("spark.hadoop.fs.s3a.access.key", S3_ACCESS_KEY)
    .config("spark.hadoop.fs.s3a.secret.key", S3_SECRET_KEY)
    .config("spark.hadoop.fs.s3a.path.style.access", "true")
    .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "true")
    .config("spark.hadoop.fs.s3a.aws.credentials.provider",
            "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider")
    .getOrCreate()
)

raw = (
    spark.read.schema(SCHEMA)
    .option("header", "true")
    .option("mode", "PERMISSIVE")
    .option("columnNameOfCorruptRecord", "_corrupt_record")
    .option("dateFormat", "yyyy-MM-dd")
    .csv(SOURCE)
    .cache()
)

valid = raw.filter(
    F.col("_corrupt_record").isNull()
    & F.col("order_id").isNotNull()
    & F.col("order_date").isNotNull()
    & F.col("region").isin(REGIONS)
    & (F.col("quantity") > 0)
    & (F.col("unit_price") > 0)
).drop("_corrupt_record")

orders = valid.dropDuplicates(["order_id"]).cache()

daily = (
    orders.withColumn("revenue", F.col("quantity") * F.col("unit_price"))
    .groupBy("order_date", "region")
    .agg(
        F.countDistinct("order_id").alias("orders"),
        F.sum("quantity").cast("long").alias("units"),
        F.round(F.sum("revenue"), 2).alias("revenue"),
    )
    .withColumn("loaded_at", F.current_timestamp())
    .orderBy("order_date", "region")
    .cache()
)

total, accepted, unique = raw.count(), valid.count(), orders.count()
print(f"Wiersze: {total}, odrzucone: {total - accepted}, duplikaty: {accepted - unique}")

(
    daily.write.format("jdbc")
    .option("url", PG_URL)
    .option("dbtable", TARGET_TABLE)
    .option("user", PG_USER)
    .option("password", PG_PASSWORD)
    .option("driver", "org.postgresql.Driver")
    .option("truncate", "true")
    .mode("overwrite")
    .save()
)

print(f"Zaladowano {daily.count()} wierszy z {SOURCE} do {TARGET_TABLE}")
spark.stop()
