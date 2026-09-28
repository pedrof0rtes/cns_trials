-- Databricks notebook source
-- MAGIC %md
-- MAGIC ## **Post-silver: Structural checks**

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 1. MeSH terms checks.
-- MAGIC

-- COMMAND ----------

-- CHECK 1) 31 frameworks, and no MeSH term mapped twice (terms = distinct_terms)
SELECT COUNT(*) AS terms,
       COUNT(DISTINCT mesh_term) AS distinct_terms,
       COUNT(DISTINCT disorder) AS frameworks
FROM cns_trials.`2_silver`.ref_mesh_disorder

-- COMMAND ----------

-- CHECK 2) mapped terms that do not exist in bronze (expected: empty)
SELECT r.disorder, r.mesh_term
FROM cns_trials.`2_silver`.ref_mesh_disorder r
LEFT ANTI JOIN (
  SELECT DISTINCT mesh_term
  FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_type = 'mesh-list'
) b ON r.mesh_term = b.mesh_term

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2. Study-disorder bridge table check.

-- COMMAND ----------

-- CHECK 1) uniqueness of the (nct_id, disorder) key (expected: 0)
SELECT COUNT(*) AS duplicated_pairs FROM (
  SELECT nct_id, disorder
  FROM cns_trials.`2_silver`.study_disorder
  GROUP BY nct_id, disorder HAVING COUNT(*) > 1)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 3. Refined 'studies' table checks.

-- COMMAND ----------

-- CHECK 1) one row per study, same size as the scope (duplicate_keys expected: 0)
SELECT
  COUNT(*) AS silver_studies,
  (SELECT COUNT(DISTINCT nct_id) FROM cns_trials.`2_silver`.study_disorder) AS scope_studies,
  COUNT(*) - COUNT(DISTINCT nct_id) AS duplicate_keys
FROM cns_trials.`2_silver`.studies

-- COMMAND ----------

-- CHECK 2) outcome universe
SELECT outcome_group, overall_status, COUNT(*) AS studies
FROM cns_trials.`2_silver`.studies
GROUP BY outcome_group, overall_status
ORDER BY outcome_group, studies DESC

-- COMMAND ----------

-- CHECK 3) typed columns and quality flags
SELECT
  COUNT(*) AS studies,
  SUM(CASE WHEN start_date IS NULL THEN 1 ELSE 0 END) AS null_start_date,
  SUM(CASE WHEN completion_date IS NULL THEN 1 ELSE 0 END) AS null_completion_date,
  SUM(CASE WHEN invalid_dates THEN 1 ELSE 0 END) AS invalid_dates,
  SUM(CASE WHEN enrollment IS NULL THEN 1 ELSE 0 END) AS null_enrollment,
  SUM(CASE WHEN has_dmc IS NULL THEN 1 ELSE 0 END) AS null_has_dmc,
  SUM(CASE WHEN is_fda_regulated_drug IS NULL THEN 1 ELSE 0 END) AS null_is_fda_regulated_drug
FROM cns_trials.`2_silver`.studies

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 4. Child tables checks.
-- MAGIC

-- COMMAND ----------

-- CHECK 1) rows in scope (bronze) vs. rows kept (silver); differences must be explained by the rules above...
SELECT 'design_groups' AS table_name,
  (SELECT COUNT(*) FROM cns_trials.`1_bronze`.design_groups WHERE nct_id IN (SELECT nct_id FROM cns_trials.`2_silver`.studies)) AS bronze_rows_in_scope,
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.design_groups) AS silver_rows
UNION ALL
SELECT 'design_outcomes',
  (SELECT COUNT(*) FROM cns_trials.`1_bronze`.design_outcomes WHERE nct_id IN (SELECT nct_id FROM cns_trials.`2_silver`.studies)),
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.design_outcomes)
UNION ALL
SELECT 'designs',
  (SELECT COUNT(*) FROM cns_trials.`1_bronze`.designs WHERE nct_id IN (SELECT nct_id FROM cns_trials.`2_silver`.studies)),
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.designs)
UNION ALL
SELECT 'interventions',
  (SELECT COUNT(*) FROM cns_trials.`1_bronze`.interventions WHERE nct_id IN (SELECT nct_id FROM cns_trials.`2_silver`.studies)),
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.interventions)
UNION ALL
SELECT 'sponsors',
  (SELECT COUNT(*) FROM cns_trials.`1_bronze`.sponsors WHERE nct_id IN (SELECT nct_id FROM cns_trials.`2_silver`.studies)),
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.sponsors)
UNION ALL
SELECT 'facilities',
  (SELECT COUNT(*) FROM cns_trials.`1_bronze`.facilities WHERE nct_id IN (SELECT nct_id FROM cns_trials.`2_silver`.studies)),
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.facilities)
UNION ALL
SELECT 'countries',
  (SELECT COUNT(*) FROM cns_trials.`1_bronze`.countries WHERE nct_id IN (SELECT nct_id FROM cns_trials.`2_silver`.studies)),
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.countries)

-- COMMAND ----------

-- CHECK 2) duplicated ids in each table; designs must also have one row per study (expected: 0)
SELECT 'design_groups (id)' AS check_name, COUNT(*) - COUNT(DISTINCT id) AS duplicates FROM cns_trials.`2_silver`.design_groups
UNION ALL SELECT 'design_outcomes (id)', COUNT(*) - COUNT(DISTINCT id) FROM cns_trials.`2_silver`.design_outcomes
UNION ALL SELECT 'designs (id)', COUNT(*) - COUNT(DISTINCT id) FROM cns_trials.`2_silver`.designs
UNION ALL SELECT 'designs (nct_id)', COUNT(*) - COUNT(DISTINCT nct_id) FROM cns_trials.`2_silver`.designs
UNION ALL SELECT 'interventions (id)', COUNT(*) - COUNT(DISTINCT id) FROM cns_trials.`2_silver`.interventions
UNION ALL SELECT 'sponsors (id)', COUNT(*) - COUNT(DISTINCT id) FROM cns_trials.`2_silver`.sponsors
UNION ALL SELECT 'facilities (id)', COUNT(*) - COUNT(DISTINCT id) FROM cns_trials.`2_silver`.facilities
UNION ALL SELECT 'countries (id)', COUNT(*) - COUNT(DISTINCT id) FROM cns_trials.`2_silver`.countries

-- COMMAND ----------

-- CHECK 3) categorical values are now uppercase and consistent across tables
SELECT 'design_groups.group_type' AS column_name, group_type AS value, COUNT(*) AS n
FROM cns_trials.`2_silver`.design_groups GROUP BY group_type
UNION ALL
SELECT 'design_outcomes.outcome_type', outcome_type, COUNT(*)
FROM cns_trials.`2_silver`.design_outcomes GROUP BY outcome_type
UNION ALL
SELECT 'designs.allocation', allocation, COUNT(*)
FROM cns_trials.`2_silver`.designs GROUP BY allocation
UNION ALL
SELECT 'designs.intervention_model', intervention_model, COUNT(*)
FROM cns_trials.`2_silver`.designs GROUP BY intervention_model
UNION ALL
SELECT 'designs.primary_purpose', primary_purpose, COUNT(*)
FROM cns_trials.`2_silver`.designs GROUP BY primary_purpose
UNION ALL
SELECT 'designs.masking', masking, COUNT(*)
FROM cns_trials.`2_silver`.designs GROUP BY masking
UNION ALL
SELECT 'interventions.intervention_type', intervention_type, COUNT(*)
FROM cns_trials.`2_silver`.interventions GROUP BY intervention_type
UNION ALL
SELECT 'sponsors.agency_class', agency_class, COUNT(*)
FROM cns_trials.`2_silver`.sponsors GROUP BY agency_class
UNION ALL
SELECT 'sponsors.lead_or_collaborator', lead_or_collaborator, COUNT(*)
FROM cns_trials.`2_silver`.sponsors GROUP BY lead_or_collaborator
ORDER BY column_name, n DESC

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 5. Referential integrity (cross-table) check.

-- COMMAND ----------

-- CHECK 1) referential integrity across Silver tables (all rows expected 0)
SELECT 'design_groups -> studies' AS check_name, COUNT(*) AS orphans
FROM cns_trials.`2_silver`.design_groups g
LEFT ANTI JOIN cns_trials.`2_silver`.studies s ON g.nct_id = s.nct_id
UNION ALL
SELECT 'design_outcomes -> studies', COUNT(*)
FROM cns_trials.`2_silver`.design_outcomes o
LEFT ANTI JOIN cns_trials.`2_silver`.studies s ON o.nct_id = s.nct_id
UNION ALL
SELECT 'designs -> studies', COUNT(*)
FROM cns_trials.`2_silver`.designs d
LEFT ANTI JOIN cns_trials.`2_silver`.studies s ON d.nct_id = s.nct_id
UNION ALL
SELECT 'interventions -> studies', COUNT(*)
FROM cns_trials.`2_silver`.interventions i
LEFT ANTI JOIN cns_trials.`2_silver`.studies s ON i.nct_id = s.nct_id
UNION ALL
SELECT 'sponsors -> studies', COUNT(*)
FROM cns_trials.`2_silver`.sponsors p
LEFT ANTI JOIN cns_trials.`2_silver`.studies s ON p.nct_id = s.nct_id
UNION ALL
SELECT 'facilities -> studies', COUNT(*)
FROM cns_trials.`2_silver`.facilities f
LEFT ANTI JOIN cns_trials.`2_silver`.studies s ON f.nct_id = s.nct_id
UNION ALL
SELECT 'countries -> studies', COUNT(*)
FROM cns_trials.`2_silver`.countries c
LEFT ANTI JOIN cns_trials.`2_silver`.studies s ON c.nct_id = s.nct_id
UNION ALL
SELECT 'study_disorder -> studies', COUNT(*)
FROM cns_trials.`2_silver`.study_disorder sd
LEFT ANTI JOIN cns_trials.`2_silver`.studies s ON sd.nct_id = s.nct_id
UNION ALL
SELECT 'studies -> study_disorder (every study has >=1 disorder)', COUNT(*)
FROM cns_trials.`2_silver`.studies s
LEFT ANTI JOIN cns_trials.`2_silver`.study_disorder sd ON s.nct_id = sd.nct_id
UNION ALL
SELECT 'study_disorder -> ref_mesh_disorder (disorder names match)', COUNT(*)
FROM (SELECT DISTINCT disorder FROM cns_trials.`2_silver`.study_disorder) sd
LEFT ANTI JOIN (SELECT DISTINCT disorder FROM cns_trials.`2_silver`.ref_mesh_disorder) r
  ON sd.disorder = r.disorder


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 6. Internal consistency ('studies') check.
-- MAGIC

-- COMMAND ----------

-- CHECK 1) logical consistency between derived columns (all rows expected 0)
SELECT 'early_termination null only for Not final' AS rule, COUNT(*) AS violations
FROM cns_trials.`2_silver`.studies
WHERE (early_termination IS NULL) <> (outcome_group = 'Not final')
UNION ALL
SELECT 'why_stopped_category filled only for Terminated/Withdrawn/Suspended', COUNT(*)
FROM cns_trials.`2_silver`.studies
WHERE (why_stopped_category IS NOT NULL) <> (overall_status IN ('TERMINATED', 'WITHDRAWN', 'SUSPENDED'))
UNION ALL
SELECT 'invalid_dates implies duration_months is null', COUNT(*)
FROM cns_trials.`2_silver`.studies
WHERE invalid_dates AND duration_months IS NOT NULL
UNION ALL
SELECT 'outcome_group matches overall_status mapping', COUNT(*)
FROM cns_trials.`2_silver`.studies
WHERE (outcome_group = 'Completed')  <> (overall_status = 'COMPLETED')
   OR (outcome_group = 'Terminated') <> (overall_status = 'TERMINATED')
   OR (outcome_group = 'Withdrawn')  <> (overall_status = 'WITHDRAWN')
UNION ALL
SELECT 'all studies are interventional (bronze study_type)', COUNT(*)
FROM cns_trials.`2_silver`.studies s
JOIN cns_trials.`1_bronze`.studies b ON s.nct_id = b.nct_id
WHERE b.study_type <> 'INTERVENTIONAL'
UNION ALL
SELECT 'duration_months is negative', COUNT(*)
FROM cns_trials.`2_silver`.studies
WHERE duration_months < 0
UNION ALL
SELECT 'time_frame_months out of the 0-120 range', COUNT(*)
FROM cns_trials.`2_silver`.design_outcomes
WHERE time_frame_months < 0 OR time_frame_months > 120