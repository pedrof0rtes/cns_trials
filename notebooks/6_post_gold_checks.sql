-- Databricks notebook source
-- MAGIC %md
-- MAGIC ## **Post-gold: Structural checks**

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 1. Dimensions: row count and key uniqueness

-- COMMAND ----------

-- CHECK 1) each dimension's row count should equal its distinct key count
SELECT 'dim_disorder' AS table_name, COUNT(*) AS rows, COUNT(DISTINCT disorder) AS distinct_keys
FROM cns_trials.`3_gold`.dim_disorder
UNION ALL
SELECT 'dim_intervention_type', COUNT(*), COUNT(DISTINCT intervention_type)
FROM cns_trials.`3_gold`.dim_intervention_type
UNION ALL
SELECT 'dim_group_type', COUNT(*), COUNT(DISTINCT group_type)
FROM cns_trials.`3_gold`.dim_group_type
UNION ALL
SELECT 'dim_country', COUNT(*), COUNT(DISTINCT country)
FROM cns_trials.`3_gold`.dim_country


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2. Fact table: uniqueness and scope size

-- COMMAND ----------

-- CHECK 1) one row per study, matching the Silver scope size
SELECT
  COUNT(*) AS fact_rows,
  COUNT(DISTINCT nct_id) AS distinct_studies,
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.studies) AS silver_studies
FROM cns_trials.`3_gold`.fact_study


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 3. Bridges: uniqueness of (study, key) pairs

-- COMMAND ----------

-- CHECK 1) no duplicated (nct_id, key) pair in any bridge (expected 0 duplicates)
SELECT 'bridge_study_disorder' AS table_name, COUNT(*) AS duplicated_pairs FROM (
  SELECT nct_id, disorder FROM cns_trials.`3_gold`.bridge_study_disorder
  GROUP BY nct_id, disorder HAVING COUNT(*) > 1)
UNION ALL
SELECT 'bridge_study_intervention_type', COUNT(*) FROM (
  SELECT nct_id, intervention_type FROM cns_trials.`3_gold`.bridge_study_intervention_type
  GROUP BY nct_id, intervention_type HAVING COUNT(*) > 1)
UNION ALL
SELECT 'bridge_study_group_type', COUNT(*) FROM (
  SELECT nct_id, group_type FROM cns_trials.`3_gold`.bridge_study_group_type
  GROUP BY nct_id, group_type HAVING COUNT(*) > 1)
UNION ALL
SELECT 'bridge_study_country', COUNT(*) FROM (
  SELECT nct_id, country FROM cns_trials.`3_gold`.bridge_study_country
  GROUP BY nct_id, country HAVING COUNT(*) > 1)


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 4. Referential integrity: bridges -> dimensions and bridges -> fact

-- COMMAND ----------

-- CHECK 1) every bridge key exists in its dimension, and every bridge study exists in fact_study
-- (expected 0 orphans)
SELECT 'bridge_study_disorder -> dim_disorder' AS check_name, COUNT(*) AS orphans
FROM cns_trials.`3_gold`.bridge_study_disorder b
LEFT ANTI JOIN cns_trials.`3_gold`.dim_disorder d ON b.disorder = d.disorder
UNION ALL
SELECT 'bridge_study_intervention_type -> dim_intervention_type', COUNT(*)
FROM cns_trials.`3_gold`.bridge_study_intervention_type b
LEFT ANTI JOIN cns_trials.`3_gold`.dim_intervention_type d ON b.intervention_type = d.intervention_type
UNION ALL
SELECT 'bridge_study_group_type -> dim_group_type', COUNT(*)
FROM cns_trials.`3_gold`.bridge_study_group_type b
LEFT ANTI JOIN cns_trials.`3_gold`.dim_group_type d ON b.group_type = d.group_type
UNION ALL
SELECT 'bridge_study_country -> dim_country', COUNT(*)
FROM cns_trials.`3_gold`.bridge_study_country b
LEFT ANTI JOIN cns_trials.`3_gold`.dim_country d ON b.country = d.country
UNION ALL
SELECT 'bridge_study_disorder -> fact_study', COUNT(*)
FROM cns_trials.`3_gold`.bridge_study_disorder b
LEFT ANTI JOIN cns_trials.`3_gold`.fact_study f ON b.nct_id = f.nct_id
UNION ALL
SELECT 'bridge_study_intervention_type -> fact_study', COUNT(*)
FROM cns_trials.`3_gold`.bridge_study_intervention_type b
LEFT ANTI JOIN cns_trials.`3_gold`.fact_study f ON b.nct_id = f.nct_id
UNION ALL
SELECT 'bridge_study_group_type -> fact_study', COUNT(*)
FROM cns_trials.`3_gold`.bridge_study_group_type b
LEFT ANTI JOIN cns_trials.`3_gold`.fact_study f ON b.nct_id = f.nct_id
UNION ALL
SELECT 'bridge_study_country -> fact_study', COUNT(*)
FROM cns_trials.`3_gold`.bridge_study_country b
LEFT ANTI JOIN cns_trials.`3_gold`.fact_study f ON b.nct_id = f.nct_id


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 5. Coverage: does every study have at least one bridge row?

-- COMMAND ----------

-- CHECK 1) fact_study -> bridge coverage.
SELECT 'fact_study -> bridge_study_disorder' AS check_name, COUNT(*) AS studies_without_a_row
FROM cns_trials.`3_gold`.fact_study f
LEFT ANTI JOIN cns_trials.`3_gold`.bridge_study_disorder b ON f.nct_id = b.nct_id
UNION ALL
SELECT 'fact_study -> bridge_study_intervention_type', COUNT(*)
FROM cns_trials.`3_gold`.fact_study f
LEFT ANTI JOIN cns_trials.`3_gold`.bridge_study_intervention_type b ON f.nct_id = b.nct_id
UNION ALL
SELECT 'fact_study -> bridge_study_group_type', COUNT(*)
FROM cns_trials.`3_gold`.fact_study f
LEFT ANTI JOIN cns_trials.`3_gold`.bridge_study_group_type b ON f.nct_id = b.nct_id
UNION ALL
SELECT 'fact_study -> bridge_study_country', COUNT(*)
FROM cns_trials.`3_gold`.fact_study f
LEFT ANTI JOIN cns_trials.`3_gold`.bridge_study_country b ON f.nct_id = b.nct_id
