# Databricks notebook source
# MAGIC %md
# MAGIC ## **Post-bronze: Structural checks**

# COMMAND ----------

# Check if columns of interest exist in 'studies' table

columns_of_interest = [
    "overall_status", "why_stopped", "phase", "study_type",
    "start_date", "completion_date", "has_dmc"
]

columns  = set(spark.table("cns_trials.`1_bronze`.studies").columns)
missing    = [c for c in columns_of_interest if c not in columns]
present   = [c for c in columns_of_interest if c in columns]

print("Present:")
for c in present:
    print(f"   {c}")

print("\nMISSING:")
for c in missing:
    print(f"   {c}")

# COMMAND ----------

# Check all columns for tables of interest 

# Define tables of interest
tables = ["studies", "conditions", "browse_conditions", "sponsors",
           "facilities", "countries", "designs", "design_groups",
           "interventions", "design_outcomes", "calculated_values"]
           
for t in tables:
    cols = spark.table(f"cns_trials.`1_bronze`.{t}").columns
    print(f"\n{t} ({len(cols)} columns):")
    for c in cols:
        print(f"   {c}")

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Study count
# MAGIC SELECT COUNT(*) AS rows, COUNT(DISTINCT nct_id) AS studies
# MAGIC FROM cns_trials.`1_bronze`.studies;