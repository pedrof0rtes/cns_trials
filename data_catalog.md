# Data Catalog

_CNS clinical trials pipeline_

Catalog `cns_trials`

schemas `1_bronze`, `2_silver`, `3_gold`

Source: AACT (Clinical Trials Transformation Initiative), flat files, snapshot 2026-09.

<br>

---

## BRONZE (`1_bronze`)

Raw AACT tables. Every column is `string` except `_ingested_at` (`timestamp`).
No transformation applied. Every table has three metadata columns appended at
ingestion: `_source_file`, `_ingested_at`, `_aact_snapshot`.

### studies (74 columns)
* nct_id
* nlm_download_date_description
* study_first_submitted_date
* results_first_submitted_date
* disposition_first_submitted_date
* last_update_submitted_date
* study_first_submitted_qc_date
* study_first_posted_date
* study_first_posted_date_type
* results_first_submitted_qc_date
* results_first_posted_date
* results_first_posted_date_type
* disposition_first_submitted_qc_date
* disposition_first_posted_date
* disposition_first_posted_date_type
* last_update_submitted_qc_date
* last_update_posted_date
* last_update_posted_date_type
* start_month_year
* start_date_type
* start_date
* verification_month_year
* verification_date
* completion_month_year
* completion_date_type
* completion_date
* primary_completion_month_year
* primary_completion_date_type
* primary_completion_date
* target_duration
* study_type
* acronym
* baseline_population
* brief_title
* official_title
* overall_status
* last_known_status
* phase
* enrollment
* enrollment_type
* source
* limitations_and_caveats
* number_of_arms
* number_of_groups
* why_stopped
* has_expanded_access
* expanded_access_type_individual
* expanded_access_type_intermediate
* expanded_access_type_treatment
* has_dmc
* is_fda_regulated_drug
* is_fda_regulated_device
* is_unapproved_device
* is_ppsd
* is_us_export
* biospec_retention
* biospec_description
* ipd_time_frame
* ipd_access_criteria
* ipd_url
* plan_to_share_ipd
* plan_to_share_ipd_description
* created_at
* updated_at
* source_class
* delayed_posting
* expanded_access_nctid
* expanded_access_status_for_nctid
* fdaaa801_violation
* baseline_type_units_analyzed
* patient_registry
* _source_file
* _ingested_at
* _aact_snapshot

Key columns used downstream: nct_id (PK), overall_status, why_stopped, phase, study_type, start_date, completion_date, completion_date_type, primary_completion_date, enrollment, enrollment_type, has_dmc, is_fda_regulated_drug.

### conditions (7 columns)
* id
* nct_id
* name
* downcase_name
* _source_file
* _ingested_at
* _aact_snapshot

Used only to build the MeSH mapping; not carried into Silver.

### browse_conditions (8 columns)
* id
* nct_id
* mesh_term
* downcase_mesh_term
* mesh_type
* _source_file
* _ingested_at
* _aact_snapshot

mesh_type domain: "mesh-list" (direct term) or "mesh-ancestor" (inherited). Used only to build the MeSH mapping; not carried into Silver.

### sponsors (8 columns)
* id
* nct_id
* agency_class
* lead_or_collaborator
* name
* _source_file
* _ingested_at
* _aact_snapshot

### facilities (13 columns)
* id
* nct_id
* status
* name
* city
* state
* zip
* country
* latitude
* longitude
* _source_file
* _ingested_at
* _aact_snapshot

### countries (7 columns)
* id
* nct_id
* name
* removed
* _source_file
* _ingested_at
* _aact_snapshot

removed domain: "t" / "f".

### designs (17 columns)
* id
* nct_id
* allocation
* intervention_model
* observational_model
* primary_purpose
* time_perspective
* masking
* masking_description
* intervention_model_description
* subject_masked
* caregiver_masked
* investigator_masked
* outcomes_assessor_masked
* _source_file
* _ingested_at
* _aact_snapshot

### design_groups (8 columns)
* id
* nct_id
* group_type
* title
* description
* _source_file
* _ingested_at
* _aact_snapshot

### interventions (8 columns)
* id
* nct_id
* intervention_type
* name
* description
* _source_file
* _ingested_at
* _aact_snapshot

### design_outcomes (10 columns)
* id
* nct_id
* outcome_type
* measure
* time_frame
* population
* description
* _source_file
* _ingested_at
* _aact_snapshot

### calculated_values (22 columns)
* id
* nct_id
* number_of_facilities
* number_of_nsae_subjects
* number_of_sae_subjects
* registered_in_calendar_year
* nlm_download_date
* actual_duration
* were_results_reported
* months_to_report_results
* has_us_facility
* has_single_facility
* minimum_age_num
* maximum_age_num
* minimum_age_unit
* maximum_age_unit
* number_of_primary_outcomes_to_measure
* number_of_secondary_outcomes_to_measure
* number_of_other_outcomes_to_measure
* _source_file
* _ingested_at
* _aact_snapshot

Not carried into Silver - recomputed independently from source tables instead (see duration_months, time_frame_months in Silver), because this table had high null rates on key fields (e.g. actual_duration ~40% null).

<br>

---

## SILVER (`2_silver`)

Cleaned, typed, and scoped to 78,272 interventional studies across 31 diagnostic
frameworks. Scope defined by `study_disorder`.

### ref_mesh_disorder
Reference table. One row per (MeSH term, diagnostic framework). Manual mapping,
31 frameworks, built by hand from the Bronze MeSH term list.
- disorder — string — one of 31 diagnostic framework names (e.g. "Depression",
  "Stroke and cerebrovascular disease", "Pain (excluding postoperative)")
- mesh_term — string — direct AACT MeSH term mapped to that framework
Lineage: manual curation, source terms from `1_bronze.browse_conditions`
(`mesh_type = 'mesh-list'` only).

### study_disorder
Bridge table (N:N). Defines the project scope. One row per (study, disorder)
that qualifies.
- nct_id — string — FK to studies
- disorder — string — FK to ref_mesh_disorder.disorder
Lineage: `1_bronze.browse_conditions` (mesh-list terms) joined to
`ref_mesh_disorder`, restricted to `1_bronze.studies.study_type = 'INTERVENTIONAL'`,
with postoperative pain studies excluded at study level (a study carrying both
`Pain` and `Pain, Postoperative` does not count toward the "Pain (excluding
postoperative)" framework).

### studies (confirmed via DESCRIBE)
One row per study in scope (78,272 rows).
- nct_id — string — primary key
- overall_status — string — uppercased AACT status
- outcome_group — string — derived: "Completed", "Terminated", "Withdrawn", or
  "Not final"
- early_termination — boolean — true if Terminated/Withdrawn, false if
  Completed, null if Not final (excluded from the analysis denominator)
- why_stopped — string — free text, trimmed, empty strings converted to null
- why_stopped_category — string — derived, keyword classification of
  why_stopped. Domain: Safety, Efficacy / futility, COVID-19, Recruitment,
  Funding / business, Operational / logistics, Regulatory / ethics, Not
  reported, Other. Null unless overall_status is TERMINATED, WITHDRAWN, or
  SUSPENDED.
- phase — string — uppercased AACT phase
- phase_group — string — derived, readable label: Early Phase 1, Phase 1,
  Phase 1/2, Phase 2, Phase 2/3, Phase 3, Phase 4, Not applicable, Unknown
- start_date — date
- start_year — int — YEAR(start_date)
- completion_date — date
- completion_date_type — string — ACTUAL or ESTIMATED, uppercased
- primary_completion_date — date
- invalid_dates — boolean — true if completion_date < start_date
- duration_months — double — months_between(completion_date, start_date),
  rounded; null if invalid_dates. For Terminated studies this is time-to-stop,
  not planned duration (see time_frame_months in design_outcomes for that)
- enrollment — bigint
- enrollment_type — string — uppercased
- has_dmc — boolean — cast from Bronze "t"/"f"; null if unrecognized/missing
- is_fda_regulated_drug — boolean — same casting as has_dmc
Lineage: `1_bronze.studies`, restricted to nct_id in `study_disorder`.

### design_groups
One row per (study, arm), in scope.
- id — bigint
- nct_id — string — FK to studies
- group_type — string — uppercased; null kept as null (unknown, not imputed)
- title — string
Lineage: `1_bronze.design_groups`, filtered to scope.

### design_outcomes
One row per (study, outcome measure), in scope.
- id — bigint
- nct_id — string — FK to studies
- outcome_type — string — uppercased: PRIMARY, SECONDARY, OTHER
- measure — string
- time_frame — string — raw free text, unchanged
- time_frame_months — double — derived: longest time mentioned in time_frame
  (regex-parsed: minutes/hours/days/weeks/months/years, age mentions and study
  codes excluded from parsing), capped at 120 months; null when no time is
  extractable (no imputation)
Lineage: `1_bronze.design_outcomes`, filtered to scope.

### designs
One row per study, in scope.
- id — bigint
- nct_id — string — FK to studies
- allocation — string — uppercased
- intervention_model — string — uppercased
- primary_purpose — string — uppercased
- masking — string — uppercased
Lineage: `1_bronze.designs`, filtered to scope. 32 studies in scope have no row here.

### interventions
One row per (study, intervention), in scope.
- id — bigint
- nct_id — string — FK to studies
- intervention_type — string — uppercased (DRUG, DEVICE, BEHAVIORAL, OTHER,
  PROCEDURE, DIETARY_SUPPLEMENT, DIAGNOSTIC_TEST, COMBINATION_PRODUCT,
  RADIATION, BIOLOGICAL, GENETIC)
- name — string
Lineage: `1_bronze.interventions`, filtered to scope. Every study in scope has
at least one row here.

### sponsors
One row per (study, sponsor/collaborator), in scope.
- id — bigint
- nct_id — string — FK to studies
- name — string
- agency_class — string — uppercased
- lead_or_collaborator — string — uppercased: LEAD or COLLABORATOR
Lineage: `1_bronze.sponsors`, filtered to scope.

### facilities
One row per (study, site), in scope.
- id — bigint
- nct_id — string — FK to studies
- name, city — string
- country — string; rows kept even when country is null
Lineage: `1_bronze.facilities`, filtered to scope. Studies with no row here have
no site information (6,246 studies) — not the same as zero sites.

### countries
One row per (study, country), in scope.
- id — bigint
- nct_id — string — FK to studies
- name — string — trimmed
Lineage: `1_bronze.countries`, filtered to scope, excluding rows flagged as
`removed` and rows with a null/empty name. Studies with no row here have no
country information (6,247 studies).

<br>

---

## GOLD (`3_gold`)

Star schema: one fact table, four dimensions, four bridges.

### fact_study (confirmed via DESCRIBE)
One row per study in scope (78,272 rows). Grain: one study.
- nct_id — string — primary key
- overall_status — string — from Silver studies
- outcome_group — string — Completed / Terminated / Withdrawn / Not final
- early_termination — boolean — analysis target variable; null excluded from denominator
- why_stopped_category — string — see Silver studies for domain
- phase_group — string — see Silver studies for domain
- enrollment — bigint
- start_year — int
- stop_year — int — YEAR(completion_date), added for time-series-of-outcome analyses
- has_dmc — boolean
- is_fda_regulated_drug — boolean
- has_drug_intervention — boolean — true if the study has >=1 DRUG intervention
  row; never null (every study has >=1 intervention row)
- lead_sponsor_class — string — agency_class of the sponsor with
  lead_or_collaborator = LEAD; null if none found
- n_sites — bigint — count of rows in Silver facilities; null if none (no info, not zero)
- n_countries — bigint — count of rows in bridge_study_country; null if none
- n_arms — bigint — count of rows in Silver design_groups; null if the study
  has no design_groups rows at all
- has_placebo — boolean — true if >=1 arm is PLACEBO_COMPARATOR; false if the
  study has typed arms and none is placebo; null if no arm has a known
  group_type (ternary, computed directly from Silver design_groups, not from
  bridge_study_group_type, to preserve the "unknown" state)
- n_primary_outcomes, n_secondary_outcomes, n_other_outcomes — bigint — counts
  by outcome_type; 0 is a real value (study has other outcomes, none of that
  type); null only if the study has zero design_outcomes rows at all
- time_frame_months — double — MAX(time_frame_months) across all the study's
  outcomes (not just primary); a lower bound on planned duration, not
  contaminated by early termination (unlike duration_months)
Lineage: built from `2_silver.studies` (base), left-joined to aggregates over
`2_silver.facilities`, `3_gold.bridge_study_country`, `2_silver.design_groups`,
`2_silver.design_outcomes`, `3_gold.bridge_study_intervention_type`, and
`2_silver.sponsors`.

### dim_disorder
31 rows. One row per diagnostic framework.
- disorder — string — primary key
Lineage: `SELECT DISTINCT disorder FROM ref_mesh_disorder`.

### dim_intervention_type
11 rows. One row per intervention type.
- intervention_type — string — primary key
- is_pharmacological — boolean — derived, fixed per type (true for DRUG,
  BIOLOGICAL, COMBINATION_PRODUCT)
Lineage: `SELECT DISTINCT intervention_type FROM 2_silver.interventions`.

### dim_group_type
6 rows. One row per study-arm type.
- group_type — string — primary key (EXPERIMENTAL, ACTIVE_COMPARATOR,
  PLACEBO_COMPARATOR, NO_INTERVENTION, OTHER, SHAM_COMPARATOR)
Lineage: `SELECT DISTINCT group_type FROM 2_silver.design_groups WHERE group_type IS NOT NULL`.

### dim_country
167 rows. One row per country.
- country — string — primary key
Lineage: `SELECT DISTINCT name FROM 2_silver.countries`.

### bridge_study_disorder
N:N. One row per (study, disorder) in scope. Reused as-is from Silver.
- nct_id — string
- disorder — string — FK to dim_disorder
Lineage: `2_silver.study_disorder`, unchanged.

### bridge_study_intervention_type
N:N. One row per (study, intervention type).
- nct_id — string
- intervention_type — string — FK to dim_intervention_type
Lineage: `SELECT DISTINCT nct_id, intervention_type FROM 2_silver.interventions
WHERE intervention_type IS NOT NULL`.

### bridge_study_group_type
N:N. One row per (study, known arm type). Excludes studies with no typed arm
(see fact_study.n_arms/has_placebo, computed separately to preserve that gap).
- nct_id — string
- group_type — string — FK to dim_group_type
Lineage: `SELECT DISTINCT nct_id, group_type FROM 2_silver.design_groups WHERE
group_type IS NOT NULL`.

### bridge_study_country
N:N. One row per (study, country).
- nct_id — string
- country — string — FK to dim_country
Lineage: `SELECT DISTINCT nct_id, name FROM 2_silver.countries`.

<br>

---

## Notes on nulls

Across Silver and Gold, null consistently means "no information available",
never "zero" or "false". This applies especially to: n_sites, n_countries,
n_arms, has_placebo, why_stopped_category (outside Terminated/Withdrawn/
Suspended), has_dmc, is_fda_regulated_drug, lead_sponsor_class, and
time_frame_months. No imputation is applied anywhere in the pipeline.