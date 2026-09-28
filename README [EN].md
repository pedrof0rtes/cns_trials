# CNS Clinical Trials Early Termination Pipeline (MVP)

Data pipeline (Databricks / Spark SQL) analyzing early termination in central nervous system (CNS) clinical trials, based on the AACT/ClinicalTrials.gov registry.

<br>

---

<br>

## Context and Questions

### Problem

I want to understand which design and execution characteristics of central
nervous system (CNS) clinical trials, including neurological and
psychiatric conditions, are associated with early termination (stopping
before planned) or study failure.

### Questions

**Main question:** Which design and execution characteristics are
associated with early termination or failure in CNS clinical trials?

<br>

**Original questions (defined before data collection):**

1. What are the reasons for failure in CNS clinical trials?
2. What is the early termination rate by clinical condition?
3. Does the number of sites influence early termination?
4. Do placebo design, number of arms, or long duration influence early
   termination?
5. Does the number of outcome measures influence early termination?


**Cross-cutting questions added along the way:**

* Do placebo and number of arms interact with each other in their
  association with early termination? (crossing the two variables from
  question 4)
* Does the intervention type (drug, device, behavioral, biological...)
  influence early termination?

**Longitudinal questions added along the way (the time dimension was not
part of the original scope):**

* How has study volume evolved over time, by disorder?
* Does the early termination rate by disorder vary over time?
* Does the composition of early termination reasons change over time
  (e.g., is the impact of the COVID-19 pandemic visible and concentrated
  in the correct period)?

<br>


### Data source

**AACT** (Aggregate Analysis of ClinicalTrials.gov), maintained by CTTI
(Clinical Trials Transformation Initiative, Duke University), is a
relational mirror of the **ClinicalTrials.gov** registry, maintained by
the U.S. National Library of Medicine (NLM). Monthly snapshot, downloaded
in 2026-09.


* Site: https://aact.ctti-clinicaltrials.org
* License: **public and free** data. ClinicalTrials.gov data is produced
  by a U.S. government agency and is, in general, public domain; AACT
  makes the mirror freely available for download, under the terms of use
  published on its own site. No academic-use restriction was identified
  in AACT's public documentation at the time of collection. It is
  recommended to check the terms currently in effect on the site before
  any use outside the scope of this MVP.

* Citation:
_Aggregate Analysis of ClinicalTrials.gov (AACT) Database. Clinical Trials Transformation Initiative (CTTI). Available at: https://aact.ctti-clinicaltrials.org/ (Accessed: 2026-09)._

<br>

### Raw data structure

11 relational tables extracted from the AACT snapshot (`.txt` files
delimited by `|`):

`studies`, `conditions`, `browse_conditions`,
`sponsors`, `facilities`, `countries`, `designs`, `design_groups`,
`interventions`, `design_outcomes`, `calculated_values`.

All columns arrive as text (`string`), untyped.

**Full column detail in
[`data_catalog.md`](./data_catalog.md).**

<br>

---

<br>

## Data Loading

Manual download of the monthly AACT snapshot (`.zip` file
with pipe-delimited `.txt` files), upload to a Unity Catalog Volume in
Databricks (`/Volumes/cns_trials/1_bronze/raw_data`), unzipping and
reading via PySpark, with control metadata (`_source_file`,
`_ingested_at`, `_aact_snapshot`) added at ingestion time.

**Script: [`notebooks/1_bronze.py`](./notebooks/1_bronze.py).**

<br>

---

<br>

## Data Modeling and Catalog

### Architecture

Medallion architecture in three layers, mapped to three schemas in the
same Unity Catalog catalog (`cns_trials`):

* `1_bronze` - raw data, as it came from AACT.
* `2_silver` - cleaned, typed, standardized data, restricted to the
  project's scope (78,272 interventional studies across 31 CNS
  diagnostic frameworks).
* `3_gold` - dimensional model (star schema) ready for analysis.

<br>

### Star schema (Gold)

One fact table and four dimensions, linked by four bridge tables (the
relationships are N:N, i.e. a study can belong to more than one disorder,
have more than one intervention type, etc.):

* `fact_study` — grain of one study (78,272 rows): outcome, early
  termination, reason for stopping, sites, countries, arms, placebo,
  monitored outcomes, planned duration, lead sponsor.
* `dim_disorder` + `bridge_study_disorder` — 31 diagnostic frameworks.
* `dim_intervention_type` + `bridge_study_intervention_type` — 11
  intervention types.
* `dim_group_type` + `bridge_study_group_type` — 6 study arm types.
* `dim_country` + `bridge_study_country` — 167 countries.

<br>

### Data catalog

**Full catalog (table by table, column by column: type, value domain,
lineage) in [`data_catalog.md`](./data_catalog.md).**

Catalog Explorer screenshots evidencing the structure and column types,
in the `screenshots/` folder:

* `data_collection_aact_flat` — data origin (AACT site)
* `databricks_repository` — repository connected to Databricks
* `bronze_catalog_structure_step_1`, `bronze_catalog_structure_step_2` —
  Bronze layer structure
* `bronze_studies_table_types` — column types, Bronze (all string)
* `silver_catalog_structure_step_3`, `silver_catalog_structure_step_4`
  — Silver layer structure
* `silver_studies_table_types` — column types, `studies` (Silver)
* `silver_mesh_table_types` — column types, `ref_mesh_disorder`
* `silver_study_disorder_table_types` — column types, `study_disorder`
* `gold_catalog_structure_step_5`, `gold_catalog_structure_step_6`,
  `gold_catalog_structure_step_7` — Gold layer structure
* `gold_fact_study_table_types` — column types, `fact_study`

---

<br>

## Data Pipeline

One notebook per pipeline refinement stage, in the order they should be
executed:

1. [`1_bronze.py`](./notebooks/1_bronze.py) — unzip and load of the
   11 raw tables.
2. [`2_post_bronze_checks.py`](./notebooks/2_post_bronze_checks.py) —
   structural checks (column existence, row counts).
3. [`3_silver.sql`](./notebooks/3_silver.sql) — MeSH mapping →
   31 diagnostic frameworks, scope bridge table, refined `studies` table
   (typing, reason-for-stopping classification, duration), 7 cleaned
   child tables.
4. [`4_post_silver_checks.sql`](./notebooks/4_post_silver_checks.sql) —
   structural checks (key uniqueness, referential integrity).
5. [`5_gold.sql`](./notebooks/5_gold.sql) — 4 dimensions, 4 bridges, 1
   fact table (star schema).
6. [`6_post_gold_checks.sql`](./notebooks/6_post_gold_checks.sql) - structural checks for the gold layer.
7. [`7_quality.sql`](./notebooks/6_quality.sql) — quality
   investigation across the three layers (see next section).
8. [`8_analysis.py`](./notebooks/7_analysis.py) — answers to the
   project's questions, with statistical tests and visualizations.

Every relevant transformation has its purpose documented as a SQL comment
in the notebook cell itself.


<br>

---

<br>

## Data Quality

Full quality investigation in the notebook
[`7_quality.sql`](./notebooks/7_quality.sql), covering completeness,
consistency, uniqueness, accuracy, and outliers across the three layers.
Main issues found and how they were treated:

**Bronze**

* Synonymous/subtype MeSH terms at the same level (e.g. "Depression",
  "Depressive Disorder, Major", and 3 more variants for the same
  disorder): manually grouped into 31 diagnostic frameworks
  (`ref_mesh_disorder`).
* Generic MeSH terms or terms from other specialties (e.g. "Mental
  Disorders", "Obesity"): excluded from scope via a predefined list.
* Null values in `design_groups.group_type` (~16%): placebo flag derived
  at the study level, with an "unknown" state kept separate from
  "no placebo".

**Silver**

* A study can belong to more than one diagnostic framework (N:N
  granularity): bridge table, counts always via `DISTINCT nct_id`.
* Postoperative pain studies contaminating the "Pain" framework: excluded
  at the study level within the bridge table itself.
* `why_stopped` is free text, with no categories: manual classification
  assisted by an LLM into 7 categories by keyword matching, iteratively
  refined against hundreds of real false positives.
* ~65% of studies have `phase = Not applicable`, including 3,360 with a
  `DRUG` intervention type: not a bug, but rather drug studies conducted
  outside the FDA regulatory process; documented, not corrected.
* Coverage gaps in child tables (design, arms, outcomes, sites,
  countries): no imputation; they become an "unknown" category in Gold.
* Missing sites concentrated in `Withdrawn` studies (30.8% vs. 3.4% in
  `Terminated`): documented bias; the sites question is answered in two
  versions (with and without `Withdrawn` studies).
* Actual duration (`duration_months`) is circular for terminated studies
  (it measures time to stop, not planned duration): additional variable
  `time_frame_months`, extracted from the study's outcome text, used as
  an uncontaminated approximation.

**Gold**

* Cross-validation: coverage of `n_sites`/`n_countries`/`has_placebo`/
  `n_arms` matches exactly the gaps documented in Silver, confirming that
  the aggregation neither lost nor invented information.
* `has_drug_intervention` matches exactly the "Not applicable" phase
  investigation (25,065 = 3,360 + 21,705), confirming the correctness of
  the intervention bridge aggregation.
* Outliers left untreated throughout the pipeline (e.g. `n_sites` up to
  1,745, `enrollment` up to 12 million): may be real data from large
  studies; no cut was applied without specific investigation.

General convention: **null is never treated as zero or false** at any
stage. It always represents "no information", explicitly kept separate
from the real value whenever ambiguity exists.

<br>

---

<br>

## Data Analysis

**Notebook [`8_analysis.py`](./notebooks/8_analysis.py).**

Scope: the
78,272 studies in `fact_study`; the early termination denominator is
restricted to `outcome_group IN ('Completed', 'Terminated', 'Withdrawn')`
(studies still ongoing are excluded).

**Statistical tests:** two-proportion Z-test for comparisons between
exactly 2 groups; chi-square test of independence for comparisons between
more than 2 categories (with a minimum sample filter of 30 per category).
No multiple-testing correction was applied, so p-values should be read as
exploratory, not confirmatory.

**Questions answered:**

* **Reasons for stopping** - Recruitment is the most common reason in
  both `Terminated` (34.9%) and `Withdrawn` (24.7%), followed by
  Funding/business. The composition changes over time: COVID-19 accounts
  for ~39% of reasons in 2020-2021 and disappears outside that window.
* **Rate by disorder** - significant variation (chi-square,
  p < 0.0001); ALS/motor neuron disease, Epilepsy, and Traumatic brain
  injury have the highest early termination rates (~19-20%); Personality
  disorders and OCD, the lowest.
* **Sites** - more sites is associated with a higher early termination
  rate (20+ sites: 16.5% vs. 1 site: 11.0%).
* **Placebo, arms, and duration** - studies with placebo have a higher
  rate than studies without placebo (16.2% vs. 11.4%); studies with 1 arm
  have a higher rate than studies with 2 or 3+; crossing the two
  variables shows the effects are independent (placebo raises the risk
  within each arm-count band). Longer planned durations (12+ months) have
  a higher rate (18.6%).
* **Number of monitored outcomes** - significant but weak association;
  studies with few outcomes (1-2) have a slightly higher rate (14.0%)
  than the rest.
* **Intervention type** - strong variation (chi-square, p < 0.0001):
  Radiation and Genetic have the highest rates (23-26%); Behavioral and
  Other, the lowest (7-9%).


<br>

### General discussion

**All tested associations are statistically significant**
(alpha = 0.01): disorder,
number of sites, placebo, number of arms, planned duration, number of
monitored outcomes, and intervention type. No multiple-testing correction
was applied, but the magnitude of the p-values makes it unlikely that the
findings are noise.

Taken together, the results suggest that early termination in CNS trials
is explained both by operational and recruitment factors and by the
disorder being studied itself. It is worth noting that **"Recruitment"
dominates the reasons for stopping across virtually every breakdown**
(disorder, sites, arms, duration, outcomes).

**Placebo and number of arms do not follow a simple "more complexity,
more risk" relationship.** Crossing the two variables shows that the
2 arms + placebo combination has the highest early termination rate
(17.5%), but right behind it comes **1 arm without placebo** (15.7%), a
much simpler design. Only after that do 3+ arms + placebo (13.4%), 2 arms
without placebo (10.2%), and 3+ arms without placebo (10.1%) appear. In
other words, both the simplest design (1 arm) and the more rigorous
comparative design (2 arms + placebo) concentrate risk.

**The early termination rate varies markedly by clinical condition.**
At the top of the risk range are ALS and motor neuron disease (20.4%),
Epilepsy (19.3%), Traumatic brain injury (19.0%), and Multiple sclerosis
and demyelinating diseases (16.6%). At the other extreme, with the lowest
rates, are Neurodevelopmental disorders and intellectual disability
(7.8%), Anxiety (8.4%), Sleep (excluding apnea) (9.8%), Other substance
use and addiction (9.8%), and Depression (11.3%).

**Study volume grew very unevenly across disorders over the last 20
years** (comparing the 2005-2009 average with the 2021-2025 average). The
ones that grew proportionally the most: Suicidality and self-harm (almost
10x), Cerebral palsy (almost 9x), and Neurodevelopmental disorders and
intellectual disability (8.5x). Practically stagnant over the same
period: Bipolar disorder (no growth, 1.0x), Schizophrenia and psychoses
(1.0x), and ADHD (1.5x, well below the median for the remaining
disorders).

In absolute volume, however, the current picture (2021-2025 sum) is
dominated by three other conditions: Pain (excluding postoperative)
(6,061 studies), Depression (3,276), and Anxiety (3,178), which were
already large from the start of the series and do not appear among the
ones that grew the most proportionally. In other words, the sharpest
relative growth happens in conditions that started from a small base, not
in the ones that today concentrate the largest volume of research.

**The recruitment problem does not appear to have improved over time.**
Looking at the composition of reasons for stopping by year (among
`Terminated` studies), Recruitment remains the dominant or near-dominant
category in almost all 21 years analyzed, oscillating between ~28% and
~46% — with no clear downward trend. The only visible exceptions are
precisely the peak COVID-19 years (2020-2021), when the pandemic
temporarily displaced Recruitment as the most cited reason.

This answers, even if only partially, the MVP's main question: study
design and the disorder being studied both matter, but the main factor
associated with failure remains the challenge of recruiting and retaining
patients.

**Visual evidence of the results:** screenshots of the main charts
(bars with confidence intervals, temporal trend lines) in the
`screenshots/` folder, prefix `analysis_`.

<br>

---

<br>

## Self-Assessment

I believe I succeeded in building a data pipeline with a good deal of
rigor and care. By the end of the data modeling stage — the most
time-consuming and labor-intensive part of the project — it was still
possible to extract real, practically meaningful insight from the
analyses performed. I wish I had had more time to carry out the project,
which was not possible due to other work commitments. For that reason, I
still intend to further refine the modeling pipeline and the analyses
going forward.

**Objectives achieved:** the original questions were answered in full,
with statistical tests and visualization. The main question (reasons for
failure) received richer treatment than originally planned, becoming its
own analysis in addition to appearing as a complementary answer in nearly
every other question.

**Difficulties:** most of the project's effort was centered on data
quality, in particular two extensive manual coding efforts. The first was
classifying the `why_stopped` field (free text, reason for stopping) into
7 categories, which required several rounds of refinement with the help
of LLMs against real false positives (e.g. "corona radiata", a brain
structure, being mistakenly captured by the COVID-19 rule). The second
was mapping MeSH terms into 31 diagnostic frameworks, which required
extensive investigation due to automatic mapping errors and high
redundancy in the source itself.

**Future work:**

* Multivariate statistical model (e.g. logistic regression) controlling
  simultaneously for all covariates, instead of isolated bivariate tests.
* Multiple-testing correction (e.g. Bonferroni or FDR) on the p-values
  from the 7+ tests performed.
* Expand the `why_stopped` classification to languages other than
  English/the occasional French already found in the data.
