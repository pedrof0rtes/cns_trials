-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Quality
-- MAGIC

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Bronze quality analysis.
-- MAGIC
-- MAGIC The cells below (originally cells 4-22 of the post-bronze notebook) document the
-- MAGIC quality investigation performed on the Bronze layer: MeSH term exploration,
-- MAGIC completeness, uniqueness, consistency, accuracy, and outliers.
-- MAGIC
-- MAGIC **Context note:** these queries use the *wide* CNS filter (the two MeSH ancestor
-- MAGIC terms `Mental Disorders` and `Nervous System Diseases`), which was the
-- MAGIC exploratory scope used during this investigation — not the final project scope.
-- MAGIC The final scope (78,272 studies across 31 diagnostic frameworks) was decided
-- MAGIC afterward and is implemented in Silver (`ref_mesh_disorder` + `study_disorder`).
-- MAGIC Numbers here (e.g. the CNS study counts) should not be confused with the final
-- MAGIC post-Silver numbers reported in the post-Silver quality section.
-- MAGIC

-- COMMAND ----------

-- Status distribution
SELECT overall_status, COUNT(*) AS n
FROM cns_trials.`1_bronze`.studies
GROUP BY overall_status ORDER BY n DESC;

-- COMMAND ----------

-- Actual group_type values (to derive the placebo flag)
SELECT group_type, COUNT(*) AS n
FROM cns_trials.`1_bronze`.design_groups GROUP BY group_type ORDER BY n DESC;


-- COMMAND ----------

-- Size of the CNS universe by the two broad MeSH groups
SELECT mesh_term, COUNT(DISTINCT nct_id) AS studies
FROM cns_trials.`1_bronze`.browse_conditions
WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases')
GROUP BY mesh_term;

-- COMMAND ----------

-- Status of CNS interventional studies (union of the two branches, without duplicating)
WITH snc AS (
  SELECT DISTINCT nct_id
  FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases')
)
SELECT s.overall_status, COUNT(*) AS n
FROM cns_trials.`1_bronze`.studies s
JOIN snc USING (nct_id)
WHERE s.study_type = 'INTERVENTIONAL'   -- confirm the exact value
GROUP BY s.overall_status
ORDER BY n DESC;

-- COMMAND ----------

SELECT
  g.group_type,
  COUNT(*)                AS n_groups,
  COUNT(DISTINCT g.nct_id) AS n_studies
FROM cns_trials.`1_bronze`.design_groups g
WHERE g.nct_id IN (
  SELECT nct_id
  FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases')
)
GROUP BY g.group_type
ORDER BY n_groups DESC

-- COMMAND ----------

WITH snc AS (
  SELECT DISTINCT nct_id
  FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases')
)
SELECT
  b.mesh_term,
  COUNT(DISTINCT b.nct_id) AS studies
FROM cns_trials.`1_bronze`.browse_conditions b
JOIN snc USING (nct_id)
WHERE b.mesh_type = 'mesh-list'
GROUP BY b.mesh_term
ORDER BY studies DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Bronze: summary of quality concerns and solutions.
-- MAGIC
-- MAGIC After exploratory analysis performed on the bronze layer tables (`cns_trials.1_bronze`).
-- MAGIC
-- MAGIC
-- MAGIC #### Summary
-- MAGIC
-- MAGIC | # | Issue | Dimension | Treatment |
-- MAGIC |---|---|---|---|
-- MAGIC | 1 | Synonyms and subtypes at the same level as MeSH terms | Consistency | Grouping into 31 diagnostic frameworks |
-- MAGIC | 2 | Generic, non-diagnostic, or other-specialty terms | Accuracy | Scope by a predefined list of diagnoses |
-- MAGIC | 3 | Null values in `design_groups.group_type` | Completeness | Placebo flag derived at the study level |
-- MAGIC
-- MAGIC
-- MAGIC ---
-- MAGIC
-- MAGIC
-- MAGIC #### 1. Synonyms and subtypes at the same level
-- MAGIC
-- MAGIC **Dimension:** Consistency
-- MAGIC
-- MAGIC **Description:** Equivalent or hierarchically related terms appear as separate categories.
-- MAGIC
-- MAGIC **Evidence:**
-- MAGIC - Depression: `Depression` (5,559), `Depressive Disorder, Major` (2,941), `Depressive Disorder` (851), `Depression, Postpartum` (556), `Depressive Disorder, Treatment-Resistant` (438).
-- MAGIC - Autism: `Autism Spectrum Disorder` (1,690) and `Autistic Disorder` (1,009).
-- MAGIC - Stroke: `Stroke` (7,745) and `Ischemic Stroke` (2,513).
-- MAGIC - Similar situation in traumatic brain injury and multiple sclerosis.
-- MAGIC
-- MAGIC **Impact:** Counting by term fragments the same condition and prevents comparisons between disorders.
-- MAGIC
-- MAGIC **Treatment (silver):** Terms will be grouped into 31 diagnostic frameworks, materialized in the reference table `ref_mesh_disorder` (manual mapping).
-- MAGIC
-- MAGIC ---
-- MAGIC
-- MAGIC
-- MAGIC #### 2. Generic, non-diagnostic, or other-specialty terms
-- MAGIC
-- MAGIC **Dimension:** Accuracy (scope)
-- MAGIC
-- MAGIC **Description:** Part of the direct terms does not represent a specific CNS or mental health diagnosis.
-- MAGIC
-- MAGIC **Evidence:**
-- MAGIC - Generic: `Mental Disorders` (1,719), `Nervous System Diseases` (751), `Disease` (449).
-- MAGIC - Non-diagnostic: `Behavior` (346), `Recurrence` (373), `Inflammation` (561), `Frailty`, `Psychological Well-Being`.
-- MAGIC - Other specialties: `Breast Neoplasms`, `Obesity`, `Hypertension`, `COVID-19`, `Diabetes Mellitus`, among others.
-- MAGIC
-- MAGIC **Impact:** Including them would dilute the scope and mix very different populations and study designs.
-- MAGIC
-- MAGIC **Treatment (silver):** Exclude from scope. Only terms from the defined list of diagnoses are included.
-- MAGIC
-- MAGIC ---
-- MAGIC
-- MAGIC
-- MAGIC #### 3. Null values in `design_groups.group_type`
-- MAGIC
-- MAGIC **Dimension:** Completeness
-- MAGIC
-- MAGIC **Description:** The field that identifies the study arm type (basis of the placebo flag) has many null values.
-- MAGIC
-- MAGIC **Impact:** Studies without `group_type` cannot be classified as with or without placebo by the direct field.
-- MAGIC
-- MAGIC **Treatment (silver):** The placebo flag is derived at the study level (at least one `PLACEBO_COMPARATOR` group), separate from the `SHAM_COMPARATOR` flag. Studies without classifiable groups remain with an unknown value, and not as "without placebo".

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## **2. Post-bronze: Essential profiling of CNS studies.**

-- COMMAND ----------

-- 1) Scope size
SELECT
  COUNT(DISTINCT nct_id) AS cns_studies,
  (SELECT COUNT(*) FROM cns_trials.`1_bronze`.studies) AS all_studies
FROM cns_trials.`1_bronze`.browse_conditions
WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases')

-- COMMAND ----------

-- 2.1) COMPLETENESS: Key clumns in 'studies' table
-- (why_stopped is expected to have many null values, for all studies that succeeded)
SELECT column,
       COUNT(*) AS total,
       SUM(CASE WHEN value IS NULL OR trim(value) = '' THEN 1 ELSE 0 END) AS null,
       ROUND(100.0 * SUM(CASE WHEN value IS NULL OR trim(value) = '' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_null
FROM (
  SELECT stack(9,
    'overall_status', overall_status,
    'why_stopped', why_stopped,
    'phase', phase,
    'study_type', study_type,
    'enrollment', enrollment,
    'start_date', start_date,
    'completion_date', completion_date,
    'primary_completion_date', primary_completion_date,
    'has_dmc', has_dmc
  ) AS (column, value)
  FROM cns_trials.`1_bronze`.studies
  WHERE nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
    WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
)
GROUP BY column
ORDER BY pct_null DESC

-- COMMAND ----------

-- 2.2) COMPLETENESS: columns of interest across all tables
-- (why_stopped is naturally null in studies that were not stopped)
SELECT table_name, column_name,
       COUNT(*) AS total,
       SUM(CASE WHEN value IS NULL OR trim(value) = '' THEN 1 ELSE 0 END) AS nulls,
       ROUND(100.0 * SUM(CASE WHEN value IS NULL OR trim(value) = '' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_nulls
FROM (
  SELECT 'studies' AS table_name,
         stack(5,
           'overall_status', overall_status,
           'why_stopped', why_stopped,
           'start_date', start_date,
           'completion_date', completion_date,
           'has_dmc', has_dmc) AS (column_name, value)
  FROM cns_trials.`1_bronze`.studies
  WHERE nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
    WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
  UNION ALL
  SELECT 'conditions', stack(1, 'name', name) AS (column_name, value)
  FROM cns_trials.`1_bronze`.conditions
  WHERE nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
    WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
  UNION ALL
  SELECT 'browse_conditions',
         stack(2, 'mesh_term', mesh_term, 'mesh_type', mesh_type) AS (column_name, value)
  FROM cns_trials.`1_bronze`.browse_conditions
  WHERE nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
    WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
  UNION ALL
  SELECT 'facilities', stack(1, 'country', country) AS (column_name, value)
  FROM cns_trials.`1_bronze`.facilities
  WHERE nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
    WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
  UNION ALL
  SELECT 'countries', stack(2, 'name', name, 'removed', removed) AS (column_name, value)
  FROM cns_trials.`1_bronze`.countries
  WHERE nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
    WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
  UNION ALL
  SELECT 'calculated_values',
         stack(5,
           'number_of_facilities', number_of_facilities,
           'actual_duration', actual_duration,
           'number_of_primary_outcomes_to_measure', number_of_primary_outcomes_to_measure,
           'number_of_secondary_outcomes_to_measure', number_of_secondary_outcomes_to_measure,
           'number_of_other_outcomes_to_measure', number_of_other_outcomes_to_measure) AS (column_name, value)
  FROM cns_trials.`1_bronze`.calculated_values
  WHERE nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
    WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
  UNION ALL
  SELECT 'design_groups', stack(1, 'group_type', group_type) AS (column_name, value)
  FROM cns_trials.`1_bronze`.design_groups
  WHERE nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
    WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
  UNION ALL
  SELECT 'interventions', stack(1, 'name', name) AS (column_name, value)
  FROM cns_trials.`1_bronze`.interventions
  WHERE nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
    WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
  UNION ALL
  SELECT 'designs',
         stack(2, 'allocation', allocation, 'masking', masking) AS (column_name, value)
  FROM cns_trials.`1_bronze`.designs
  WHERE nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
    WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
  UNION ALL
  SELECT 'design_outcomes', stack(1, 'outcome_type', outcome_type) AS (column_name, value)
  FROM cns_trials.`1_bronze`.design_outcomes
  WHERE nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
    WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
)
GROUP BY table_name, column_name
ORDER BY table_name, pct_nulls DESC

-- COMMAND ----------

-- 2.3) COMPLETENESS: scope studies without any listed site
-- (absence of information in facilities, not necessarily zero sites)
SELECT COUNT(*) AS cns_studies,
       SUM(CASE WHEN f.nct_id IS NULL THEN 1 ELSE 0 END) AS no_sites,
       ROUND(100.0 * SUM(CASE WHEN f.nct_id IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_no_sites
FROM (
  SELECT DISTINCT nct_id FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases')
) s
LEFT JOIN (SELECT DISTINCT nct_id FROM cns_trials.`1_bronze`.facilities) f
  ON s.nct_id = f.nct_id

-- COMMAND ----------

-- 3) UNIQUENESS: duplicate keys (expected: 0)
SELECT 'studies (nct_id)' AS check_name, COUNT(*) AS duplicate_keys FROM (
  SELECT nct_id FROM cns_trials.`1_bronze`.studies
  WHERE nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
    WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
  GROUP BY nct_id HAVING COUNT(*) > 1)
UNION ALL
SELECT 'conditions (nct_id, downcase_name)', COUNT(*) FROM (
  SELECT nct_id, downcase_name FROM cns_trials.`1_bronze`.conditions
  WHERE nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
    WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
  GROUP BY nct_id, downcase_name HAVING COUNT(*) > 1)
UNION ALL
SELECT 'browse_conditions (nct_id, mesh_term, mesh_type)', COUNT(*) FROM (
  SELECT nct_id, mesh_term, mesh_type FROM cns_trials.`1_bronze`.browse_conditions
  WHERE nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
    WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
  GROUP BY nct_id, mesh_term, mesh_type HAVING COUNT(*) > 1)

-- COMMAND ----------

-- 4.1) CONSISTENCY: distinct values of categorical fields
-- (note the casing: group_type is uppercase vs. outcome_type is lowercase)
SELECT 'studies.overall_status' AS column_name, overall_status AS value, COUNT(*) AS n
FROM cns_trials.`1_bronze`.studies
WHERE nct_id IN (
  SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
GROUP BY overall_status
UNION ALL
SELECT 'studies.phase', phase, COUNT(*)
FROM cns_trials.`1_bronze`.studies
WHERE nct_id IN (
  SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
GROUP BY phase
UNION ALL
SELECT 'studies.study_type', study_type, COUNT(*)
FROM cns_trials.`1_bronze`.studies
WHERE nct_id IN (
  SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
GROUP BY study_type
UNION ALL
SELECT 'design_groups.group_type', group_type, COUNT(*)
FROM cns_trials.`1_bronze`.design_groups
WHERE nct_id IN (
  SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
GROUP BY group_type
UNION ALL
SELECT 'design_outcomes.outcome_type', outcome_type, COUNT(*)
FROM cns_trials.`1_bronze`.design_outcomes
WHERE nct_id IN (
  SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
GROUP BY outcome_type
ORDER BY column_name, n DESC

-- COMMAND ----------

-- 4.2) CONSISTENCY: date format (expected: YYYY-MM-DD)
SELECT 'start_date' AS column, COUNT(*) AS total,
       SUM(CASE WHEN start_date IS NULL OR trim(start_date) = '' THEN 1 ELSE 0 END) AS nulls,
       SUM(CASE WHEN start_date RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN 1 ELSE 0 END) AS iso_format,
       SUM(CASE WHEN start_date IS NOT NULL AND trim(start_date) <> ''
                 AND NOT start_date RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN 1 ELSE 0 END) AS other_format
FROM cns_trials.`1_bronze`.studies
WHERE nct_id IN (
  SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
UNION ALL
SELECT 'completion_date', COUNT(*),
       SUM(CASE WHEN completion_date IS NULL OR trim(completion_date) = '' THEN 1 ELSE 0 END),
       SUM(CASE WHEN completion_date RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN 1 ELSE 0 END),
       SUM(CASE WHEN completion_date IS NOT NULL AND trim(completion_date) <> ''
                 AND NOT completion_date RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN 1 ELSE 0 END)
FROM cns_trials.`1_bronze`.studies
WHERE nct_id IN (
  SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))

-- COMMAND ----------

-- 5.1) ACCURACY: dates and enrollment (try_cast returns null instead of an error)
SELECT
  COUNT(*) AS studies,
  SUM(CASE WHEN try_cast(completion_date AS DATE) < try_cast(start_date AS DATE) THEN 1 ELSE 0 END) AS end_before_start,
  SUM(CASE WHEN enrollment IS NOT NULL AND trim(enrollment) <> ''
            AND try_cast(enrollment AS DOUBLE) IS NULL THEN 1 ELSE 0 END) AS enrollment_non_numeric,
  SUM(CASE WHEN try_cast(enrollment AS DOUBLE) < 0 THEN 1 ELSE 0 END) AS enrollment_negative
FROM cns_trials.`1_bronze`.studies
WHERE nct_id IN (
  SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))

-- COMMAND ----------

-- 5.2) ACCURACY: why_stopped by status (should only exist for stopped studies)
SELECT overall_status,
       COUNT(*) AS total,
       SUM(CASE WHEN why_stopped IS NULL OR trim(why_stopped) = '' THEN 1 ELSE 0 END) AS no_reason,
       SUM(CASE WHEN why_stopped IS NOT NULL AND trim(why_stopped) <> '' THEN 1 ELSE 0 END) AS with_reason
FROM cns_trials.`1_bronze`.studies
WHERE nct_id IN (
  SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
GROUP BY overall_status
ORDER BY total DESC

-- COMMAND ----------

-- 6.1) OUTLIERS: Enrollment
SELECT
  MIN(try_cast(enrollment AS DOUBLE)) AS mininum,
  percentile_approx(try_cast(enrollment AS DOUBLE), 0.5) AS p50,
  percentile_approx(try_cast(enrollment AS DOUBLE), 0.95) AS p95,
  percentile_approx(try_cast(enrollment AS DOUBLE), 0.99) AS p99,
  MAX(try_cast(enrollment AS DOUBLE)) AS maximum,
  SUM(CASE WHEN try_cast(enrollment AS DOUBLE) = 0 THEN 1 ELSE 0 END) AS zero_enrollment
FROM cns_trials.`1_bronze`.studies
WHERE nct_id IN (
  SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
  WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))

-- COMMAND ----------

-- 6.2) OUTLIERS: number of sites per study (only studies with listed sites)
SELECT
  COUNT(*) AS studies_with_sites,
  MIN(n_sites) AS minimum,
  percentile_approx(n_sites, 0.5) AS p50,
  percentile_approx(n_sites, 0.95) AS p95,
  percentile_approx(n_sites, 0.99) AS p99,
  MAX(n_sites) AS maximum
FROM (
  SELECT nct_id, COUNT(*) AS n_sites
  FROM cns_trials.`1_bronze`.facilities
  WHERE nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.browse_conditions
    WHERE mesh_term IN ('Mental Disorders', 'Nervous System Diseases'))
  GROUP BY nct_id
)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Silver quality analysis.
-- MAGIC

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 1. Scope: MeSH mapping and framework overlap
-- MAGIC

-- COMMAND ----------

-- CHECK 1) studies per framework (distinct studies each)
SELECT r.disorder, COUNT(DISTINCT b.nct_id) AS studies
FROM cns_trials.`1_bronze`.browse_conditions b
JOIN cns_trials.`2_silver`.ref_mesh_disorder r ON b.mesh_term = r.mesh_term
WHERE b.mesh_type = 'mesh-list'
GROUP BY r.disorder
ORDER BY studies DESC

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2. Scope: bridge table and postoperative pain exclusion.

-- COMMAND ----------

-- CHECK 1) size of the scope and average frameworks per study
SELECT COUNT(*) AS study_disorder_pairs,
       COUNT(DISTINCT nct_id) AS distinct_studies,
       ROUND(COUNT(*) / COUNT(DISTINCT nct_id), 3) AS avg_disorders_per_study
FROM cns_trials.`2_silver`.study_disorder

-- COMMAND ----------

-- CHECK 2) distinct studies per framework
SELECT disorder, COUNT(*) AS studies
FROM cns_trials.`2_silver`.study_disorder
GROUP BY disorder
ORDER BY studies DESC

-- COMMAND ----------

-- CHECK 3) overlap, in how many frameworks does each study appear?
SELECT n_disorders, COUNT(*) AS studies
FROM (
  SELECT nct_id, COUNT(*) AS n_disorders
  FROM cns_trials.`2_silver`.study_disorder
  GROUP BY nct_id
)
GROUP BY n_disorders
ORDER BY n_disorders

-- COMMAND ----------

-- CHECK 4) effect of the postoperative pain exclusion
-- (interventional studies mapped to the pain framework, before vs. after the exclusion)
SELECT
  (SELECT COUNT(DISTINCT b.nct_id)
   FROM cns_trials.`1_bronze`.browse_conditions b
   JOIN cns_trials.`2_silver`.ref_mesh_disorder r ON b.mesh_term = r.mesh_term
   JOIN cns_trials.`1_bronze`.studies s ON b.nct_id = s.nct_id
   WHERE b.mesh_type = 'mesh-list'
     AND s.study_type = 'INTERVENTIONAL'
     AND r.disorder = 'Pain (excluding postoperative)') AS pain_studies_before,
  (SELECT COUNT(*)
   FROM cns_trials.`2_silver`.study_disorder
   WHERE disorder = 'Pain (excluding postoperative)') AS pain_studies_after

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 3. 'Studies' Table: why_stopped, phase and outliers.

-- COMMAND ----------

-- CHECK 1) why_stopped categories
SELECT outcome_group, why_stopped_category, COUNT(*) AS studies
FROM cns_trials.`2_silver`.studies
WHERE why_stopped_category IS NOT NULL
  AND outcome_group IN ('Terminated', 'Withdrawn')
GROUP BY outcome_group, why_stopped_category
ORDER BY outcome_group, studies DESC

-- COMMAND ----------

-- CHECK 2) most frequent texts classified as 'Other' (tuning the keywords above)
SELECT lower(why_stopped) AS why_stopped_text, COUNT(*) AS studies
FROM cns_trials.`2_silver`.studies
WHERE why_stopped_category = 'Other'
  AND outcome_group IN ('Terminated', 'Withdrawn')
GROUP BY lower(why_stopped)
ORDER BY studies DESC
LIMIT 100

-- COMMAND ----------

-- CHECK 3) phase groups
SELECT phase_group, COUNT(*) AS studies
FROM cns_trials.`2_silver`.studies
GROUP BY phase_group
ORDER BY studies DESC

-- COMMAND ----------

-- CHECK 4a) intervention types by phase group (one study can have several types)
SELECT
  CASE WHEN s.phase_group = 'Not applicable' THEN 'Not applicable' ELSE 'Phase 1-4' END AS phase_type,
  i.intervention_type,
  COUNT(DISTINCT s.nct_id) AS studies
FROM cns_trials.`2_silver`.studies s
JOIN cns_trials.`1_bronze`.interventions i ON s.nct_id = i.nct_id
WHERE s.phase_group <> 'Unknown'
GROUP BY 1, 2
ORDER BY phase_type, studies DESC

-- COMMAND ----------

-- CHECK 4b) are these studies FDA-regulated? (studies with a DRUG intervention, by phase type)
SELECT
  CASE WHEN s.phase_group = 'Not applicable' THEN 'Not applicable' ELSE 'Phase 1-4' END AS phase_type,
  b.is_fda_regulated_drug,
  COUNT(DISTINCT s.nct_id) AS studies
FROM cns_trials.`2_silver`.studies s
JOIN cns_trials.`1_bronze`.studies b ON s.nct_id = b.nct_id
WHERE s.phase_group <> 'Unknown'
  AND s.nct_id IN (
    SELECT nct_id FROM cns_trials.`1_bronze`.interventions WHERE intervention_type = 'DRUG')
GROUP BY 1, 2
ORDER BY phase_type, studies DESC

-- COMMAND ----------

-- CHECK 5) enrollment outliers (final scope, 78,272 studies)
SELECT
  MIN(enrollment) AS min_enrollment,
  percentile_approx(enrollment, 0.5) AS p50,
  percentile_approx(enrollment, 0.95) AS p95,
  percentile_approx(enrollment, 0.99) AS p99,
  MAX(enrollment) AS max_enrollment,
  SUM(CASE WHEN enrollment = 0 THEN 1 ELSE 0 END) AS enrollment_zero
FROM cns_trials.`2_silver`.studies

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 4. Child tables: coverage and planned duration.
-- MAGIC

-- COMMAND ----------

-- CHECK 1) coverage, studies in scope with no row in each child table (information gaps, useful for left joins in gold)
SELECT
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.studies) AS studies,
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.studies s LEFT ANTI JOIN cns_trials.`2_silver`.designs d ON s.nct_id = d.nct_id) AS without_design,
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.studies s LEFT ANTI JOIN cns_trials.`2_silver`.design_groups g ON s.nct_id = g.nct_id) AS without_groups,
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.studies s LEFT ANTI JOIN (SELECT DISTINCT nct_id FROM cns_trials.`2_silver`.design_outcomes WHERE outcome_type = 'PRIMARY') o ON s.nct_id = o.nct_id) AS without_primary_outcome,
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.studies s LEFT ANTI JOIN cns_trials.`2_silver`.interventions i ON s.nct_id = i.nct_id) AS without_interventions,
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.studies s LEFT ANTI JOIN cns_trials.`2_silver`.sponsors p ON s.nct_id = p.nct_id) AS without_sponsor,
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.studies s LEFT ANTI JOIN cns_trials.`2_silver`.facilities f ON s.nct_id = f.nct_id) AS without_sites,
  (SELECT COUNT(*) FROM cns_trials.`2_silver`.studies s LEFT ANTI JOIN cns_trials.`2_silver`.countries c ON s.nct_id = c.nct_id) AS without_countries

-- COMMAND ----------

-- CHECK 2) sites per study outliers (only studies with at least one listed site)
SELECT
  COUNT(*) AS studies_with_sites,
  MIN(n_sites) AS min_sites,
  percentile_approx(n_sites, 0.5) AS p50,
  percentile_approx(n_sites, 0.95) AS p95,
  percentile_approx(n_sites, 0.99) AS p99,
  MAX(n_sites) AS max_sites
FROM (
  SELECT nct_id, COUNT(*) AS n_sites
  FROM cns_trials.`2_silver`.facilities
  GROUP BY nct_id
)

-- COMMAND ----------

-- CHECK 3) planned duration feasibility, share of primary outcomes with an extractable time in time_frame
-- (patterns like '12 weeks', '6-month', 'week 8')
SELECT COUNT(*) AS primary_outcomes,
       SUM(CASE WHEN time_frame IS NULL THEN 1 ELSE 0 END) AS null_time_frame,
       SUM(CASE WHEN lower(time_frame) RLIKE '[0-9]+ *-? *(day|week|month|year)|(day|week|month|year)s? *[0-9]+' THEN 1 ELSE 0 END) AS extractable_time
FROM cns_trials.`2_silver`.design_outcomes
WHERE outcome_type = 'PRIMARY'

-- COMMAND ----------

-- CHECK 4) most frequent time_frame texts of primary outcomes (to see how the text is written)
SELECT lower(time_frame) AS time_frame_text, COUNT(*) AS n
FROM cns_trials.`2_silver`.design_outcomes
WHERE outcome_type = 'PRIMARY'
GROUP BY lower(time_frame)
ORDER BY n DESC
LIMIT 40

-- COMMAND ----------

-- CHECK 5) coverage of the stored column time_frame_months
WITH per_study AS (
  SELECT nct_id,
         MAX(CASE WHEN outcome_type = 'PRIMARY' THEN time_frame_months END) AS primary_months,
         MAX(time_frame_months) AS any_outcome_months
  FROM cns_trials.`2_silver`.design_outcomes
  GROUP BY nct_id
)
SELECT s.outcome_group,
       COUNT(*) AS studies,
       ROUND(100.0 * SUM(CASE WHEN p.primary_months IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_primary,
       ROUND(100.0 * SUM(CASE WHEN p.any_outcome_months IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_any_outcome
FROM cns_trials.`2_silver`.studies s
LEFT JOIN per_study p ON s.nct_id = p.nct_id
GROUP BY s.outcome_group
ORDER BY studies DESC

-- COMMAND ----------

-- CHECK 6) planned follow-up bands by outcome group (longest time across all outcomes of the study)
WITH per_study AS (
  SELECT nct_id, MAX(time_frame_months) AS months
  FROM cns_trials.`2_silver`.design_outcomes
  GROUP BY nct_id
)
SELECT s.outcome_group,
       CASE WHEN p.months IS NULL THEN '5. no information'
            WHEN p.months <= 1  THEN '1. up to 1 month'
            WHEN p.months <= 6  THEN '2. more than 1 to 6 months'
            WHEN p.months <= 12 THEN '3. more than 6 to 12 months'
            ELSE '4. more than 12 months' END AS followup_band,
       COUNT(*) AS studies
FROM cns_trials.`2_silver`.studies s
LEFT JOIN per_study p ON s.nct_id = p.nct_id
GROUP BY 1, 2
ORDER BY 1, 2

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 5. Completeness.
-- MAGIC

-- COMMAND ----------

-- CHECK 1) Completeness of columns
SELECT tabela AS table_name, coluna AS column_name,
       COUNT(*) AS total,
       SUM(CASE WHEN valor IS NULL OR trim(valor) = '' THEN 1 ELSE 0 END) AS nulls,
       ROUND(100.0 * SUM(CASE WHEN valor IS NULL OR trim(valor) = '' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_nulls
FROM (
  SELECT 'studies' AS tabela,
         stack(10,
           'overall_status', overall_status,
           'why_stopped', why_stopped,
           'why_stopped_category', why_stopped_category,
           'phase_group', phase_group,
           'start_date', CAST(start_date AS STRING),
           'completion_date', CAST(completion_date AS STRING),
           'duration_months', CAST(duration_months AS STRING),
           'enrollment', CAST(enrollment AS STRING),
           'has_dmc', CAST(has_dmc AS STRING),
           'is_fda_regulated_drug', CAST(is_fda_regulated_drug AS STRING)
         ) AS (coluna, valor)
  FROM cns_trials.`2_silver`.studies
  UNION ALL
  SELECT 'sponsors', stack(1, 'agency_class', agency_class) AS (coluna, valor)
  FROM cns_trials.`2_silver`.sponsors
  UNION ALL
  SELECT 'facilities', stack(1, 'country', country) AS (coluna, valor)
  FROM cns_trials.`2_silver`.facilities
  UNION ALL
  SELECT 'designs', stack(3,
           'allocation', allocation,
           'masking', masking,
           'intervention_model', intervention_model) AS (coluna, valor)
  FROM cns_trials.`2_silver`.designs
  UNION ALL
  SELECT 'design_groups', stack(1, 'group_type', group_type) AS (coluna, valor)
  FROM cns_trials.`2_silver`.design_groups
  UNION ALL
  SELECT 'design_outcomes', stack(2,
           'outcome_type', outcome_type,
           'time_frame_months', CAST(time_frame_months AS STRING)) AS (coluna, valor)
  FROM cns_trials.`2_silver`.design_outcomes
)
GROUP BY tabela, coluna
ORDER BY tabela, pct_nulls DESC

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Silver: summary of quality concerns and fixes.
-- MAGIC
-- MAGIC Quality investigation carried out on the Silver layer. Each item refers to the
-- MAGIC query results shown above, in the order they appear in this section.
-- MAGIC
-- MAGIC | # | Problem | Dimension | Treatment |
-- MAGIC |---|---|---|---|
-- MAGIC | 1 | A study can belong to more than one diagnostic framework | Uniqueness (granularity) | Bridge table; counts use `DISTINCT nct_id`; overlap kept as a documented limitation |
-- MAGIC | 2 | Postoperative pain could enter the "Pain" framework | Accuracy | Excluded at study level in the bridge table |
-- MAGIC | 3 | `why_stopped` is free text, no categories | Consistency | Classified into 7 categories by keyword matching, tuned against false positives |
-- MAGIC | 4 | ~65% of studies have `phase = Not applicable`, incl. 3,360 with a `DRUG` intervention | Accuracy (interpretation) | Not a defect — documented; `phase_group` kept as covariate, not a drug-trial filter |
-- MAGIC | 5 | Gaps in child-table coverage (design, groups, outcomes, sites, countries) | Completeness | No imputation; gaps become "unknown" categories in Gold |
-- MAGIC | 6 | Missing site info concentrated in `Withdrawn` studies (30.8% vs. 3.4% Terminated) | Accuracy (bias) | No correction; question 3 answered in two versions (with/without Withdrawn) |
-- MAGIC | 7 | `duration_months` is circular for Terminated studies | Accuracy | `time_frame_months` added as an approximation from outcome `time_frame` |
-- MAGIC
-- MAGIC #### 1-2. Scope: framework overlap and postoperative pain
-- MAGIC
-- MAGIC A study can map to more than one of the 31 frameworks (overlap distribution
-- MAGIC above). Summing per-framework counts overestimates the total; overall counts
-- MAGIC use `DISTINCT nct_id`. The `Pain (excluding postoperative)` framework excludes,
-- MAGIC at study level, any study also carrying `Pain, Postoperative` (before/after
-- MAGIC comparison above).
-- MAGIC
-- MAGIC #### 3. `why_stopped` classification
-- MAGIC
-- MAGIC Free text, classified into 7 categories (Safety, Efficacy / futility, COVID-19,
-- MAGIC Recruitment, Funding / business, Operational / logistics, Regulatory / ethics)
-- MAGIC plus `Not reported` for uninformative text (empty, points to another field,
-- MAGIC repeats the status, or "never started"). Keyword lists were tuned against real
-- MAGIC false positives (e.g. a loose `investigator` match wrongly caught
-- MAGIC `investigator decision`). This is keyword matching over free text, not manual
-- MAGIC review — a meaningful share of `Other`/`Not reported` gives no real reason,
-- MAGIC which is a property of the source data.
-- MAGIC
-- MAGIC #### 4. "Not applicable" phase and drug studies
-- MAGIC
-- MAGIC `phase_group = 'Not applicable'`: 51,247 of 78,272 studies (65.5%), including
-- MAGIC 3,360 with a `DRUG` intervention (vs. 21,705 across phases 1-4). Among
-- MAGIC "Not applicable" drug studies with a known `is_fda_regulated_drug` value,
-- MAGIC 99.8% (1,610/1,613) are not FDA-regulated; among phases 1-4, 59.5% (5,778/9,719)
-- MAGIC are regulated. "Not applicable" mostly reflects drug studies run outside the
-- MAGIC FDA phase framework, not the absence of a drug. `phase_group` is unchanged;
-- MAGIC a drug-trial flag, if needed, should use the `DRUG`/`BIOLOGICAL` intervention
-- MAGIC type in Gold, not phase.
-- MAGIC
-- MAGIC #### 5-6. Coverage gaps and the `Withdrawn` site bias
-- MAGIC
-- MAGIC Coverage gaps (studies without a matching child-table row): 32 without design,
-- MAGIC 3,644 (4.7%) without groups, 873 (1.1%) without a primary outcome, 6,246 (8.0%)
-- MAGIC without sites, 6,247 (8.0%) without countries; 0 without interventions or
-- MAGIC sponsors. No imputation applied.
-- MAGIC
-- MAGIC Missing sites are concentrated in `Withdrawn` studies: 30.8% (669/2,171)
-- MAGIC vs. 3.4% (144/4,260) in Terminated and 5.8% (2,626/45,589) in Completed.
-- MAGIC Because Withdrawn studies never started, "no site info" looks like a stronger
-- MAGIC early-termination risk factor when Withdrawn is included (23.6% vs. 11.6%)
-- MAGIC than when it isn't (Terminated vs. Completed: 5.2% vs. 8.7%). No correction
-- MAGIC applied; question 3 will be answered both with and without Withdrawn studies.
-- MAGIC
-- MAGIC #### 7. Circular duration and `time_frame_months`
-- MAGIC
-- MAGIC For Terminated studies, `duration_months` measures time-to-stop, not planned
-- MAGIC duration. `time_frame_months` (longest time mentioned across a study's
-- MAGIC outcomes, capped at 120 months, null when not extractable) was added as an
-- MAGIC approximation. Coverage after tuning the extraction rule (removing age
-- MAGIC mentions and study-code false positives): Completed 84.2%, Not final 89.4%,
-- MAGIC Terminated 87.7%, Withdrawn 86.6% — balanced enough across outcome groups to
-- MAGIC use. It is a lower bound on planned duration, but unlike `duration_months` it
-- MAGIC is not contaminated by early termination.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Gold quality analysis.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 1. Completeness of aggregated measures.

-- COMMAND ----------

-- CHECK 1) null share of measures computed in the Gold aggregation
SELECT column_name,
       COUNT(*) AS total,
       SUM(CASE WHEN value IS NULL THEN 1 ELSE 0 END) AS nulls,
       ROUND(100.0 * SUM(CASE WHEN value IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_nulls
FROM (
  SELECT stack(8,
    'n_sites', CAST(n_sites AS STRING),
    'n_countries', CAST(n_countries AS STRING),
    'n_arms', CAST(n_arms AS STRING),
    'has_placebo', CAST(has_placebo AS STRING),
    'n_primary_outcomes', CAST(n_primary_outcomes AS STRING),
    'n_secondary_outcomes', CAST(n_secondary_outcomes AS STRING),
    'time_frame_months', CAST(time_frame_months AS STRING),
    'lead_sponsor_class', CAST(lead_sponsor_class AS STRING)
  ) AS (column_name, value)
  FROM cns_trials.`3_gold`.fact_study
)
GROUP BY column_name
ORDER BY pct_nulls DESC


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2. Outliers: sites and arms per study.

-- COMMAND ----------

-- CHECK 1) distribution of n_sites and n_arms in the final fact table
SELECT 'n_sites' AS measure,
       COUNT(n_sites) AS studies_with_value,
       MIN(n_sites) AS min_value,
       percentile_approx(n_sites, 0.5) AS p50,
       percentile_approx(n_sites, 0.95) AS p95,
       percentile_approx(n_sites, 0.99) AS p99,
       MAX(n_sites) AS max_value
FROM cns_trials.`3_gold`.fact_study
UNION ALL
SELECT 'n_arms',
       COUNT(n_arms),
       MIN(n_arms),
       percentile_approx(n_arms, 0.5),
       percentile_approx(n_arms, 0.95),
       percentile_approx(n_arms, 0.99),
       MAX(n_arms)
FROM cns_trials.`3_gold`.fact_study


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 3. `has_placebo` distribution.

-- COMMAND ----------

-- CHECK 1) how many studies have a known placebo arm, a known non-placebo design, or an unknown placebo status
SELECT has_placebo, COUNT(*) AS studies
FROM cns_trials.`3_gold`.fact_study
GROUP BY has_placebo
ORDER BY has_placebo

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 4. `lead_sponsor_class` coverage.

-- COMMAND ----------

-- CHECK 1) distribution of the lead sponsor class, and how many studies have no LEAD sponsor row
SELECT COALESCE(lead_sponsor_class, 'NO LEAD SPONSOR FOUND') AS lead_sponsor_class, COUNT(*) AS studies
FROM cns_trials.`3_gold`.fact_study
GROUP BY lead_sponsor_class
ORDER BY studies DESC

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 5. `has_drug_intervention` cross-check.

-- COMMAND ----------

-- CHECK 1) total studies with a DRUG intervention should match the earlier Silver
SELECT has_drug_intervention, COUNT(*) AS studies
FROM cns_trials.`3_gold`.fact_study
GROUP BY has_drug_intervention


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Gold: summary.
-- MAGIC
-- MAGIC Quality investigation carried out on the Gold layer. Each item refers to the
-- MAGIC query results shown above.
-- MAGIC
-- MAGIC | # | Finding | Status |
-- MAGIC |---|---|---|
-- MAGIC | 1 | Coverage of `n_sites`/`n_countries`/`has_placebo`/`n_arms` matches the documented Silver gaps exactly (6,246 / 6,247 / 3,644 / 3,644) | Confirms the Gold aggregation preserved the same "no information" cases, nothing lost or invented |
-- MAGIC | 2 | `has_drug_intervention` totals (25,065 true / 53,207 false) match the earlier phase investigation exactly (3,360 + 21,705) | Confirms the intervention-type aggregation is correct |
-- MAGIC | 3 | `n_primary_outcomes`/`n_secondary_outcomes` null count (870) is slightly below the earlier "without primary outcome" count (873) | Not an error — null here means zero outcome rows at all; the 3-study gap are studies with some outcomes but none primary, correctly shown as a real 0, not null |
-- MAGIC | 4 | Outliers: `n_sites` up to 1,745, `n_arms` up to 43 | Kept untreated, as with other outliers — plausible for large multi-site or platform trials |
-- MAGIC | 5 | `lead_sponsor_class` is 0% null, but 78.8% of studies fall under `OTHER` | Not a data quality problem — `OTHER` is AACT's catch-all for non-industry, non-government sponsors (universities, hospitals) |