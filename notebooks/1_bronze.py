# Databricks notebook source
# MAGIC %md
# MAGIC ### **1. Unzip raw data.**

# COMMAND ----------

import zipfile
import os

# Define catalog, volume path, schema and snapshot date
VOL = "/Volumes/cns_trials/1_bronze/raw_data"
SNAPSHOT = "2026-09"

# List files in volume
files = os.listdir(VOL)
print("Files in volume:", files, "\n")

# Find .zip file and unzip
zip_file = [f for f in files if f.endswith('.zip')]


if zip_file:

    zip_path = os.path.join(VOL, zip_file[0])
    with zipfile.ZipFile(zip_path, 'r') as z:
        z.extractall(VOL)
    print(f"Unzipped: {zip_file[0]}\n")
    
    # List files in volume after unzip
    files_after = os.listdir(VOL)
    print("Files after unzip:", files_after)

# COMMAND ----------

# MAGIC %md
# MAGIC ### **2. Extract tables of interest from raw data.**

# COMMAND ----------

from pyspark.sql import functions as F

# Specify catalog
spark.sql("USE CATALOG cns_trials")

# Define tables of interest
tables = ["studies", "conditions", "browse_conditions", "sponsors",
           "facilities", "countries", "designs", "design_groups",
           "interventions", "design_outcomes", "calculated_values"]

# Create dataframes from .txt tables
for t in tables:
    df = (spark.read
          .option("header", True).option("sep", "|").option("quote", '"')
          .option("inferSchema", False)
          .csv(f"{VOL}/{t}.txt"))
    df = (df.withColumn("_source_file", F.col("_metadata.file_path"))
            .withColumn("_ingested_at", F.current_timestamp())
            .withColumn("_aact_snapshot", F.lit(SNAPSHOT)))
    
    df.createOrReplaceTempView(f"temp_{t}")
    spark.sql(f"CREATE OR REPLACE TABLE cns_trials.`1_bronze`.{t} AS SELECT * FROM temp_{t}")
    print(f"Created: cns_trials.`1_bronze`.{t}")

# COMMAND ----------

for t in ["studies", "conditions", "browse_conditions", "sponsors", "facilities",
          "countries", "designs", "design_groups", "interventions",
          "design_outcomes", "calculated_values"]:
    print(f"\n{t}:")
    spark.table(f"cns_trials.`1_bronze`.{t}").printSchema()