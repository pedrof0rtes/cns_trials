-- Databricks notebook source
-- MAGIC %md
-- MAGIC ## 1. Dimensions

-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`3_gold`.dim_disorder
COMMENT 'Diagnostic frameworks dimension (31 rows), derived from the manual MeSH mapping.'
AS
SELECT DISTINCT disorder
FROM cns_trials.`2_silver`.ref_mesh_disorder
ORDER BY disorder

-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`3_gold`.dim_intervention_type
COMMENT 'Intervention type dimension. is_pharmacological is a derived attribute.'
AS
SELECT
  intervention_type,
  intervention_type IN ('DRUG', 'BIOLOGICAL', 'COMBINATION_PRODUCT') AS is_pharmacological
FROM (
  SELECT DISTINCT intervention_type
  FROM cns_trials.`2_silver`.interventions
  WHERE intervention_type IS NOT NULL
)


-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`3_gold`.dim_group_type
COMMENT 'Study arm (design group) type dimension.'
AS
SELECT DISTINCT group_type
FROM cns_trials.`2_silver`.design_groups
WHERE group_type IS NOT NULL

-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`3_gold`.dim_country
COMMENT 'Country dimension (Silver countries already excludes removed rows and null names).'
AS
SELECT DISTINCT name AS country
FROM cns_trials.`2_silver`.countries

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Bridges (study x dimension)

-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`3_gold`.bridge_study_disorder
COMMENT 'Study x disorder bridge (N:N). Reuses the Silver scope-defining bridge as is.'
AS
SELECT nct_id, disorder
FROM cns_trials.`2_silver`.study_disorder

-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`3_gold`.bridge_study_intervention_type
COMMENT 'Study x intervention type bridge (N:N).'
AS
SELECT DISTINCT nct_id, intervention_type
FROM cns_trials.`2_silver`.interventions
WHERE intervention_type IS NOT NULL

-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`3_gold`.bridge_study_group_type
COMMENT 'Study x arm type bridge (N:N). Excludes rows with unknown group_type -- see fact_study for the has_placebo/n_arms ternary treatment, computed directly from Silver design_groups instead of from this bridge.'
AS
SELECT DISTINCT nct_id, group_type
FROM cns_trials.`2_silver`.design_groups
WHERE group_type IS NOT NULL

-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`3_gold`.bridge_study_country
COMMENT 'Study x country bridge (N:N).'
AS
SELECT DISTINCT nct_id, name AS country
FROM cns_trials.`2_silver`.countries


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Fact table

-- COMMAND ----------

CREATE OR REPLACE TABLE cns_trials.`3_gold`.fact_study
COMMENT 'One row per study (final scope, 78,272 studies).'
AS
WITH sites AS (
  SELECT nct_id, COUNT(*) AS n_sites
  FROM cns_trials.`2_silver`.facilities
  GROUP BY nct_id
),
countries_agg AS (
  SELECT nct_id, COUNT(*) AS n_countries
  FROM cns_trials.`3_gold`.bridge_study_country
  GROUP BY nct_id
),
arms AS (
  -- computed from Silver design_groups directly (not from bridge_study_group_type),
  -- because the bridge excludes rows with unknown group_type and we need those
  -- rows to tell "no placebo" apart from "placebo status unknown"
  SELECT
    nct_id,
    COUNT(*) AS n_arms,
    MAX(CASE WHEN group_type = 'PLACEBO_COMPARATOR' THEN 1 ELSE 0 END) AS any_placebo,
    SUM(CASE WHEN group_type IS NOT NULL THEN 1 ELSE 0 END) AS n_typed_arms
  FROM cns_trials.`2_silver`.design_groups
  GROUP BY nct_id
),
outcomes AS (
  SELECT
    nct_id,
    SUM(CASE WHEN outcome_type = 'PRIMARY' THEN 1 ELSE 0 END) AS n_primary_outcomes,
    SUM(CASE WHEN outcome_type = 'SECONDARY' THEN 1 ELSE 0 END) AS n_secondary_outcomes,
    SUM(CASE WHEN outcome_type = 'OTHER' THEN 1 ELSE 0 END) AS n_other_outcomes,
    MAX(time_frame_months) AS time_frame_months
  FROM cns_trials.`2_silver`.design_outcomes
  GROUP BY nct_id
),
drug AS (
  SELECT DISTINCT nct_id, true AS has_drug_intervention
  FROM cns_trials.`3_gold`.bridge_study_intervention_type
  WHERE intervention_type = 'DRUG'
),
lead_sponsor AS (
  -- assumes at most one LEAD sponsor per study; MAX arbitrarily breaks ties if more than one is found
  SELECT nct_id, MAX(agency_class) AS lead_sponsor_class
  FROM cns_trials.`2_silver`.sponsors
  WHERE lead_or_collaborator = 'LEAD'
  GROUP BY nct_id
)
SELECT
  s.nct_id,
  s.overall_status,
  s.outcome_group,
  s.early_termination,
  s.why_stopped_category,
  s.phase_group,
  s.enrollment,
  s.start_year,
  YEAR(s.completion_date) AS stop_year,
  s.has_dmc,
  s.is_fda_regulated_drug,
  COALESCE(dg.has_drug_intervention, false) AS has_drug_intervention,
  ls.lead_sponsor_class,

  st.n_sites,
  co.n_countries,

  ar.n_arms,
  CASE WHEN ar.any_placebo = 1 THEN true
       WHEN ar.n_typed_arms = 0 OR ar.n_typed_arms IS NULL THEN NULL
       ELSE false END AS has_placebo,

  ou.n_primary_outcomes,
  ou.n_secondary_outcomes,
  ou.n_other_outcomes,
  ou.time_frame_months

FROM cns_trials.`2_silver`.studies s
LEFT JOIN sites         st ON s.nct_id = st.nct_id
LEFT JOIN countries_agg co ON s.nct_id = co.nct_id
LEFT JOIN arms          ar ON s.nct_id = ar.nct_id
LEFT JOIN outcomes      ou ON s.nct_id = ou.nct_id
LEFT JOIN drug          dg ON s.nct_id = dg.nct_id
LEFT JOIN lead_sponsor  ls ON s.nct_id = ls.nct_id