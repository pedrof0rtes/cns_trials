# Databricks notebook source
# /// script
# [tool.databricks.environment]
# environment_version = "6"
# ///
# MAGIC %md
# MAGIC # Analysis
# MAGIC
# MAGIC Scope: `cns_trials.3_gold.fact_study` (78,272 studies). Denominator for all questions below: `early_termination IS NOT NULL`, i.e. `outcome_group IN ('Completed','Terminated','Withdrawn')` - `Not final` studies are excluded.
# MAGIC
# MAGIC No multiple-testing correction is applied, treat p-values as exploratory.

# COMMAND ----------

# MAGIC %md
# MAGIC ## 0. Helper functions

# COMMAND ----------

from scipy import stats
import numpy as np
import pandas as pd

ALPHA = 0.01

def run_chi2(query, label_col="label", min_n=None, sort_by="total"):
    """Runs a SQL query returning (label_col, early, not_early, total) and performs a
    chi-square test of independence. Rows with total < min_n are excluded from the
    test (kept for the descriptive table). sort_by controls how the printed AND
    returned table is ordered ("total" or "rate")."""
    pdf = spark.sql(query).toPandas()
    pdf["rate"] = pdf["early"] / pdf["total"]
    test_pdf = pdf[pdf["total"] >= min_n] if min_n else pdf
    table = test_pdf[["early", "not_early"]].values
    chi2, p, dof, _ = stats.chi2_contingency(table)
    pdf = pdf.sort_values(sort_by, ascending=False).reset_index(drop=True)
    print(pdf.to_string(index=False))
    excluded = len(pdf) - len(test_pdf)
    if excluded:
        print(f"\n{excluded} categories excluded from the test (n < {min_n})")
    print(f"\nChi-square = {chi2:.2f}, dof = {dof}, p-value = {p:.4g}  "
          f"({'significant' if p < ALPHA else 'not significant'} at alpha={ALPHA})")
    return pdf

def run_two_prop(query, label_col="label"):
    """Runs a SQL query returning exactly two rows (label_col, early, not_early, total)
    and performs a two-proportion z-test."""
    pdf = spark.sql(query).toPandas()
    assert len(pdf) == 2, f"expected 2 groups, got {len(pdf)}"
    pdf["rate"] = pdf["early"] / pdf["total"]
    print(pdf.to_string(index=False))
    (x1, n1), (x2, n2) = zip(pdf["early"], pdf["total"])
    p1, p2 = x1 / n1, x2 / n2
    p_pool = (x1 + x2) / (n1 + n2)
    se = np.sqrt(p_pool * (1 - p_pool) * (1 / n1 + 1 / n2))
    z = (p1 - p2) / se
    p_value = 2 * (1 - stats.norm.cdf(abs(z)))
    print(f"\n{pdf[label_col][0]}: {p1:.1%}   {pdf[label_col][1]}: {p2:.1%}   "
          f"diff = {p1 - p2:+.1%}")
    print(f"z = {z:.2f}, p-value = {p_value:.4g}  "
          f"({'significant' if p_value < ALPHA else 'not significant'} at alpha={ALPHA})")
    return pdf

def top_reason(label_expr, extra_from="", extra_where="1=1", rate_lookup=None, top_n=3, order=None):
    """For each category defined by label_expr, finds the top_n most frequent
    why_stopped_category values among the studies in that category that actually
    stopped early (early_termination = true), each with its share within the
    category (pct_of_group) and its rank (1 = most frequent).
    If rate_lookup (a DataFrame with 'label' and 'rate' columns, e.g. the table
    returned by run_chi2 for the same breakdown) is given, the early-termination
    rate is attached and rows are sorted by it (then by rank within each label).
    If order (a list of label values, e.g. ["1", "2-5", "6-20", "20+"]) is given,
    it takes priority and rows are sorted in that fixed sequence instead."""
    query = f"""
    WITH base AS (
      SELECT {label_expr} AS label, f.why_stopped_category
      FROM cns_trials.`3_gold`.fact_study f
      {extra_from}
      WHERE f.early_termination = true AND f.why_stopped_category IS NOT NULL AND ({extra_where})
    ),
    counted AS (
      SELECT label, why_stopped_category, COUNT(*) AS n,
             SUM(COUNT(*)) OVER (PARTITION BY label) AS group_total,
             ROW_NUMBER() OVER (PARTITION BY label ORDER BY COUNT(*) DESC) AS rank
      FROM base
      GROUP BY label, why_stopped_category
    )
    SELECT label, rank, why_stopped_category AS reason, n, group_total,
           ROUND(100.0 * n / group_total, 1) AS pct_of_group
    FROM counted
    WHERE rank <= {top_n}
    ORDER BY group_total DESC, rank
    """
    pdf = spark.sql(query).toPandas()
    if order is not None:
        pdf["label"] = pd.Categorical(pdf["label"], categories=order, ordered=True)
        pdf = pdf.sort_values(["label", "rank"]).reset_index(drop=True)
    elif rate_lookup is not None:
        pdf = pdf.merge(rate_lookup[["label", "rate"]], on="label", how="left")
        pdf = pdf.sort_values(["rate", "rank"], ascending=[False, True]).reset_index(drop=True)
    print(pdf.to_string(index=False))
    return pdf


def plot_rate_bars(pdf, order=None, title="", horizontal=False, bar_width=0.5, color="#3b5b74"):
    """Bar chart of early-termination rate with 95% CI (normal approximation),
    from a DataFrame with 'label', 'rate', 'total' columns (as returned by
    run_chi2 or run_two_prop). order fixes the category sequence, if given.
    bar_width controls bar thickness (0-1); color sets the bar fill color."""
    df = pdf.copy()
    if order is not None:
        df["label"] = pd.Categorical(df["label"], categories=order, ordered=True)
        df = df.sort_values("label")
    se = np.sqrt(df["rate"] * (1 - df["rate"]) / df["total"])
    ci = 1.96 * se

    fig, ax = plt.subplots(figsize=(8, max(4, 0.4 * len(df))) if horizontal else (8, 5))
    if horizontal:
        ax.barh(df["label"], df["rate"], xerr=ci, height=bar_width, color=color, capsize=4)
        ax.set_xlabel("Early-termination rate")
    else:
        ax.bar(df["label"], df["rate"], yerr=ci, width=bar_width, color=color, capsize=4)
        ax.set_ylabel("Early-termination rate")
    ax.set_title(title)
    plt.tight_layout()
    plt.show()

# COMMAND ----------

# MAGIC %md
# MAGIC ## 1) Study distribution per year (per disorder).

# COMMAND ----------

## Timeframe
spark.sql("""
SELECT
  MIN(CASE WHEN start_year <= YEAR(current_date()) THEN start_year END) AS earliest_year,
  MAX(CASE WHEN start_year <= YEAR(current_date()) THEN start_year END) AS latest_year,
  COUNT(CASE WHEN start_year <= YEAR(current_date()) THEN start_year END) AS studies_with_year,
  COUNT(*) AS total_studies,
  COUNT(*) - COUNT(CASE WHEN start_year <= YEAR(current_date()) THEN start_year END) AS studies_without_year
FROM cns_trials.`3_gold`.fact_study
""").toPandas()

# COMMAND ----------

pdf = spark.sql("""
SELECT d.disorder, f.start_year, COUNT(*) AS studies
FROM cns_trials.`3_gold`.fact_study f
JOIN cns_trials.`3_gold`.bridge_study_disorder d ON f.nct_id = d.nct_id
WHERE f.start_year IS NOT NULL AND f.start_year <= YEAR(current_date()) - 1
GROUP BY d.disorder, f.start_year
ORDER BY d.disorder, f.start_year
""").toPandas()

pivot = pdf.pivot_table(index="disorder", columns="start_year", values="studies",
                         fill_value=0, aggfunc="sum")
pivot["total"] = pivot.sum(axis=1)
pivot = pivot.sort_values("total", ascending=False)

print(pivot.to_string())

# COMMAND ----------

import matplotlib.pyplot as plt

pdf = spark.sql("""
SELECT d.disorder, f.start_year, COUNT(*) AS studies
FROM cns_trials.`3_gold`.fact_study f
JOIN cns_trials.`3_gold`.bridge_study_disorder d ON f.nct_id = d.nct_id
WHERE f.start_year IS NOT NULL AND f.start_year <= YEAR(current_date()) - 1
GROUP BY d.disorder, f.start_year
""").toPandas()

pivot = pdf.pivot_table(index="start_year", columns="disorder", values="studies", fill_value=0)
overall = pivot.sum(axis=1)

fig, ax = plt.subplots(figsize=(12, 6))
for disorder in pivot.columns:
    ax.plot(pivot.index, pivot[disorder], color="steelblue", alpha=0.7, linewidth=1)

ax.set_title("Studies by start year, all 31 disorder frameworks")
ax.set_xlabel("Start year")
ax.set_ylabel("Number of studies")
plt.tight_layout()
plt.show()

# COMMAND ----------

# MAGIC %md
# MAGIC ## 2.1) Proportion of failed studies per year (per disorder).

# COMMAND ----------

pdf = spark.sql("""
SELECT d.disorder, f.start_year,
       SUM(CASE WHEN f.early_termination THEN 1 ELSE 0 END) AS early,
       COUNT(*) AS total
FROM cns_trials.`3_gold`.fact_study f
JOIN cns_trials.`3_gold`.bridge_study_disorder d ON f.nct_id = d.nct_id
WHERE f.start_year IS NOT NULL AND f.early_termination IS NOT NULL AND f.start_year <= YEAR(current_date()) - 1
GROUP BY d.disorder, f.start_year
""").toPandas()

pdf["rate"] = pdf["early"] / pdf["total"]

# rate pivot: NaN (not 0) where a disorder/year cell has no studies
# and "no data" must stay visibly different
rate_pivot = pdf.pivot_table(index="disorder", columns="start_year", values="rate")

# sample size pivot, for context (a 0% or 100% rate on n=1 is not meaningful)
n_pivot = pdf.pivot_table(index="disorder", columns="start_year", values="total", fill_value=0)

overall_rate = pdf.groupby("disorder").apply(lambda g: g["early"].sum() / g["total"].sum())
rate_pivot = rate_pivot.loc[overall_rate.sort_values(ascending=False).index]

print("Early-termination RATE by disorder x start_year (NaN = no studies that year)")
print(rate_pivot.round(2).to_string())

# COMMAND ----------

import matplotlib.pyplot as plt

pdf = spark.sql("""
SELECT d.disorder, f.start_year,
       SUM(CASE WHEN f.early_termination THEN 1 ELSE 0 END) AS early,
       COUNT(*) AS total
FROM cns_trials.`3_gold`.fact_study f
JOIN cns_trials.`3_gold`.bridge_study_disorder d ON f.nct_id = d.nct_id
WHERE f.start_year IS NOT NULL AND f.start_year <= YEAR(current_date()) - 1
  AND f.early_termination IS NOT NULL
GROUP BY d.disorder, f.start_year
""").toPandas()

pdf["rate"] = pdf["early"] / pdf["total"]
rate_pivot = pdf.pivot_table(index="start_year", columns="disorder", values="rate")

# overall rate = sum(early)/sum(total) per year across all disorder-study pairs
# (NOT the average of each disorder's rate, which would overweight small disorders)
totals_by_year = pdf.groupby("start_year")[["early", "total"]].sum()
overall_rate = totals_by_year["early"] / totals_by_year["total"]

fig, ax = plt.subplots(figsize=(14, 6))
for disorder in rate_pivot.columns:
    ax.plot(rate_pivot.index, rate_pivot[disorder], color="firebrick", alpha=0.5, linewidth=1)
ax.plot(overall_rate.index, overall_rate.values, color="black", linewidth=2.5,
        label="Overall rate (pooled)")

ax.set_title("Early-termination rate by start year, all 31 disorder frameworks (thin lines) "
             "and pooled overall rate (bold)")
ax.set_xlabel("Start year")
ax.set_ylabel("Early-termination rate")
ax.set_ylim(0, 1)
ax.legend()
plt.tight_layout()
plt.show()

# COMMAND ----------

# MAGIC %md
# MAGIC ## 2.2. Statistical significance of early termination rate (by disorder).

# COMMAND ----------

# MAGIC %md
# MAGIC Chi-square test of independence (disorder x early termination) for overall early termination rate.

# COMMAND ----------

df_disorder = run_chi2("""
SELECT d.disorder AS label,
       SUM(CASE WHEN f.early_termination THEN 1 ELSE 0 END) AS early,
       SUM(CASE WHEN NOT f.early_termination THEN 1 ELSE 0 END) AS not_early,
       COUNT(*) AS total
FROM cns_trials.`3_gold`.fact_study f
JOIN cns_trials.`3_gold`.bridge_study_disorder d ON f.nct_id = d.nct_id
WHERE f.early_termination IS NOT NULL
GROUP BY d.disorder
""", min_n=30, sort_by="rate")


# COMMAND ----------

plot_rate_bars(
    df_disorder,
    horizontal=True,
    title="Early termination rate by disorder"
)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 3.1) Most frequent reasons for early termination (past 20 years)

# COMMAND ----------

pdf = spark.sql("""
SELECT outcome_group, why_stopped_category, COUNT(*) AS studies,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY outcome_group), 1) AS pct_within_group
FROM cns_trials.`3_gold`.fact_study
WHERE outcome_group IN ('Terminated', 'Withdrawn')
GROUP BY outcome_group, why_stopped_category
ORDER BY studies DESC
""").toPandas()

terminated = pdf[pdf["outcome_group"] == "Terminated"].drop(columns="outcome_group").reset_index(drop=True)
withdrawn = pdf[pdf["outcome_group"] == "Withdrawn"].drop(columns="outcome_group").reset_index(drop=True)

print("Terminated")
print(terminated.to_string(index=False))
print("\nWithdrawn")
print(withdrawn.to_string(index=False))

# COMMAND ----------

pdf = spark.sql("""
SELECT outcome_group, stop_year, why_stopped_category, COUNT(*) AS studies,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY outcome_group, stop_year), 1) AS pct_within_year
FROM cns_trials.`3_gold`.fact_study
WHERE outcome_group IN ('Terminated', 'Withdrawn')
  AND stop_year IS NOT NULL
  AND stop_year BETWEEN YEAR(current_date()) - 21 AND YEAR(current_date()) - 1
GROUP BY outcome_group, stop_year, why_stopped_category
ORDER BY outcome_group, stop_year, studies DESC
""").toPandas()

terminated = pdf[pdf["outcome_group"] == "Terminated"].drop(columns="outcome_group")
withdrawn = pdf[pdf["outcome_group"] == "Withdrawn"].drop(columns="outcome_group")

terminated_pivot = terminated.pivot_table(index="why_stopped_category", columns="stop_year",
                                           values="pct_within_year", fill_value=0)
withdrawn_pivot = withdrawn.pivot_table(index="why_stopped_category", columns="stop_year",
                                         values="pct_within_year", fill_value=0)

print("Terminated -- reason share (%) by stop year")
print(terminated_pivot.round(1).to_string())
print("\nWithdrawn -- reason share (%) by stop year")
print(withdrawn_pivot.round(1).to_string())

# COMMAND ----------

import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator

fig, axes = plt.subplots(1, 2, figsize=(18, 6), sharey=True)

for ax, pivot, title in [(axes[0], terminated_pivot, "Terminated"),
                          (axes[1], withdrawn_pivot, "Withdrawn")]:
    for category in pivot.index:
        ax.plot(pivot.columns, pivot.loc[category], marker="o", markersize=3, linewidth=1.5,
                label=category)
    ax.set_title(f"{title} - reason share (%) by stop year")
    ax.set_xlabel("Stop year")
    ax.xaxis.set_major_locator(MaxNLocator(integer=True))

axes[0].set_ylabel("Share within year (%)")
axes[1].legend(bbox_to_anchor=(1.02, 1), loc="upper left", fontsize=9)
plt.tight_layout()
plt.show()

# COMMAND ----------

# MAGIC %md
# MAGIC ## 3.2) Most frequent reasons for early termination (by disorder).

# COMMAND ----------

top_reason(
    "d.disorder",
    extra_from="JOIN cns_trials.`3_gold`.bridge_study_disorder d ON f.nct_id = d.nct_id",
    rate_lookup=df_disorder
)


# COMMAND ----------

# MAGIC %md
# MAGIC ### 4) Early termination rates by number of sites.

# COMMAND ----------

run_chi2("""
SELECT CASE WHEN n_sites = 1 THEN '1'
            WHEN n_sites BETWEEN 2 AND 5 THEN '2-5'
            WHEN n_sites BETWEEN 6 AND 20 THEN '6-20'
            ELSE '20+' END AS label,
       SUM(CASE WHEN early_termination THEN 1 ELSE 0 END) AS early,
       SUM(CASE WHEN NOT early_termination THEN 1 ELSE 0 END) AS not_early,
       COUNT(*) AS total
FROM cns_trials.`3_gold`.fact_study
WHERE early_termination IS NOT NULL AND n_sites IS NOT NULL
GROUP BY 1
""", sort_by="rate")


# COMMAND ----------

# MAGIC %md
# MAGIC **Follow-up: most frequent reason for stopping, by number of sites.**

# COMMAND ----------

top_reason(
    """CASE WHEN f.n_sites = 1 THEN '1'
            WHEN f.n_sites BETWEEN 2 AND 5 THEN '2-5'
            WHEN f.n_sites BETWEEN 6 AND 20 THEN '6-20'
            ELSE '20+' END""",
    extra_where="f.n_sites IS NOT NULL",
    order=["1", "2-5", "6-20", "20+"]
)

# COMMAND ----------

import matplotlib.pyplot as plt

pdf = spark.sql("""
SELECT CASE WHEN n_sites = 1 THEN '1'
            WHEN n_sites BETWEEN 2 AND 5 THEN '2-5'
            WHEN n_sites BETWEEN 6 AND 20 THEN '6-20'
            ELSE '20+' END AS label,
       SUM(CASE WHEN early_termination THEN 1 ELSE 0 END) AS early, COUNT(*) AS total
FROM cns_trials.`3_gold`.fact_study
WHERE early_termination IS NOT NULL AND n_sites IS NOT NULL
GROUP BY 1
""").toPandas()
pdf["rate"] = pdf["early"] / pdf["total"]
plot_rate_bars(pdf, order=["1", "2-5", "6-20", "20+"],
               title="Early termination by number of sites",
               bar_width=0.4, color="#2f6b62")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 5) Placebo, number of arms, and planned duration.

# COMMAND ----------

# MAGIC %md
# MAGIC ### 5.1) Placebo associations with early termination.

# COMMAND ----------

run_two_prop("""
SELECT CASE WHEN has_placebo THEN 'placebo' ELSE 'no placebo' END AS label,
       SUM(CASE WHEN early_termination THEN 1 ELSE 0 END) AS early,
       SUM(CASE WHEN NOT early_termination THEN 1 ELSE 0 END) AS not_early,
       COUNT(*) AS total
FROM cns_trials.`3_gold`.fact_study
WHERE early_termination IS NOT NULL AND has_placebo IS NOT NULL
GROUP BY 1
""")


# COMMAND ----------

# MAGIC %md
# MAGIC **Follow-up: most frequent reason for stopping, by placebo status.**

# COMMAND ----------

top_reason(
    "CASE WHEN f.has_placebo THEN 'placebo' ELSE 'no placebo' END",
    extra_where="f.has_placebo IS NOT NULL",
    order=["placebo", "no placebo"]
)


# COMMAND ----------

pdf = spark.sql("""
SELECT CASE WHEN has_placebo THEN 'placebo' ELSE 'no placebo' END AS label,
       SUM(CASE WHEN early_termination THEN 1 ELSE 0 END) AS early, COUNT(*) AS total
FROM cns_trials.`3_gold`.fact_study
WHERE early_termination IS NOT NULL AND has_placebo IS NOT NULL
GROUP BY 1
""").toPandas()
pdf["rate"] = pdf["early"] / pdf["total"]
plot_rate_bars(pdf, title="Early termination: placebo vs. no placebo",
               bar_width=0.25, color="#3b5b74")

# COMMAND ----------

# MAGIC %md
# MAGIC ### 5.2) Number of arms (and placebo) associations with early termination.

# COMMAND ----------

df_cross = run_chi2("""
SELECT
  CASE WHEN n_arms = 1 THEN '1'
       WHEN n_arms = 2 THEN '2'
       ELSE '3+' END || ' / ' ||
  CASE WHEN has_placebo THEN 'placebo' ELSE 'no placebo' END AS label,
  SUM(CASE WHEN early_termination THEN 1 ELSE 0 END) AS early,
  SUM(CASE WHEN NOT early_termination THEN 1 ELSE 0 END) AS not_early,
  COUNT(*) AS total
FROM cns_trials.`3_gold`.fact_study
WHERE early_termination IS NOT NULL AND n_arms IS NOT NULL AND has_placebo IS NOT NULL
  AND NOT (n_arms = 1 AND has_placebo = true)  -- excluded: only 16 studies, CI too wide to be meaningful
GROUP BY 1
""", sort_by="rate")

plot_rate_bars(
    df_cross,
    order=["1 / no placebo", "2 / no placebo", "2 / placebo", "3+ / no placebo", "3+ / placebo"],
    horizontal=True,
    title="Early termination by arms x placebo",
    color="#7a3b46"
)

# COMMAND ----------

# MAGIC %md
# MAGIC **Follow-up: most frequent reason for stopping, by arms x placebo.**

# COMMAND ----------

top_reason(
    """CASE WHEN f.n_arms = 1 THEN '1'
            WHEN f.n_arms = 2 THEN '2'
            ELSE '3+' END || ' / ' ||
       CASE WHEN f.has_placebo THEN 'placebo' ELSE 'no placebo' END""",
    extra_where="""f.n_arms IS NOT NULL AND f.has_placebo IS NOT NULL
                   AND NOT (f.n_arms = 1 AND f.has_placebo = true)""",
    order=["1 / no placebo", "2 / no placebo", "2 / placebo", "3+ / no placebo", "3+ / placebo"]
)

# COMMAND ----------

# MAGIC %md
# MAGIC ### 5.3) (Planned) duration associations with early termination.

# COMMAND ----------

run_chi2("""
SELECT CASE WHEN time_frame_months <= 1 THEN 'up to 1 month'
            WHEN time_frame_months <= 6 THEN '1-6 months'
            WHEN time_frame_months <= 12 THEN '6-12 months'
            ELSE 'over 12 months' END AS label,
       SUM(CASE WHEN early_termination THEN 1 ELSE 0 END) AS early,
       SUM(CASE WHEN NOT early_termination THEN 1 ELSE 0 END) AS not_early,
       COUNT(*) AS total
FROM cns_trials.`3_gold`.fact_study
WHERE early_termination IS NOT NULL AND time_frame_months IS NOT NULL
GROUP BY 1
""", sort_by="rate")



# COMMAND ----------

# MAGIC %md
# MAGIC **Follow-up: most frequent reason for stopping, by planned follow-up duration.**

# COMMAND ----------

top_reason(
    """CASE WHEN f.time_frame_months <= 1 THEN 'up to 1 month'
            WHEN f.time_frame_months <= 6 THEN '1-6 months'
            WHEN f.time_frame_months <= 12 THEN '6-12 months'
            ELSE 'over 12 months' END""",
    extra_where="f.time_frame_months IS NOT NULL",
    order=["up to 1 month", "1-6 months", "6-12 months", "over 12 months"]
)


# COMMAND ----------

pdf = spark.sql("""
SELECT CASE WHEN time_frame_months <= 1 THEN 'up to 1 month'
            WHEN time_frame_months <= 6 THEN '1-6 months'
            WHEN time_frame_months <= 12 THEN '6-12 months'
            ELSE 'over 12 months' END AS label,
       SUM(CASE WHEN early_termination THEN 1 ELSE 0 END) AS early, COUNT(*) AS total
FROM cns_trials.`3_gold`.fact_study
WHERE early_termination IS NOT NULL AND time_frame_months IS NOT NULL
GROUP BY 1
""").toPandas()
pdf["rate"] = pdf["early"] / pdf["total"]
plot_rate_bars(pdf, order=["up to 1 month", "1-6 months", "6-12 months", "over 12 months"],
               title="Early termination by planned follow-up duration",
               bar_width=0.4, color="#3b5b74")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6) Number of outcome measures.

# COMMAND ----------

# MAGIC %md
# MAGIC Total outcomes = primary + secondary + other. Studies with no outcome information at all (`n_primary_outcomes IS NULL`) are excluded from the test.

# COMMAND ----------

run_chi2("""
SELECT CASE WHEN total_outcomes <= 2 THEN '1-2'
            WHEN total_outcomes <= 5 THEN '3-5'
            WHEN total_outcomes <= 10 THEN '6-10'
            ELSE '10+' END AS label,
       SUM(CASE WHEN early_termination THEN 1 ELSE 0 END) AS early,
       SUM(CASE WHEN NOT early_termination THEN 1 ELSE 0 END) AS not_early,
       COUNT(*) AS total
FROM (
  SELECT *,
         COALESCE(n_primary_outcomes,0) + COALESCE(n_secondary_outcomes,0)
           + COALESCE(n_other_outcomes,0) AS total_outcomes
  FROM cns_trials.`3_gold`.fact_study
  WHERE n_primary_outcomes IS NOT NULL
)
WHERE early_termination IS NOT NULL
GROUP BY 1
""", sort_by = "rate")


# COMMAND ----------

# MAGIC %md
# MAGIC **Follow-up: most frequent reason for stopping, by number of outcome measures.**

# COMMAND ----------

top_reason(
    """CASE WHEN (COALESCE(f.n_primary_outcomes,0) + COALESCE(f.n_secondary_outcomes,0)
                  + COALESCE(f.n_other_outcomes,0)) <= 2 THEN '1-2'
            WHEN (COALESCE(f.n_primary_outcomes,0) + COALESCE(f.n_secondary_outcomes,0)
                  + COALESCE(f.n_other_outcomes,0)) <= 5 THEN '3-5'
            WHEN (COALESCE(f.n_primary_outcomes,0) + COALESCE(f.n_secondary_outcomes,0)
                  + COALESCE(f.n_other_outcomes,0)) <= 10 THEN '6-10'
            ELSE '10+' END""",
    extra_where="f.n_primary_outcomes IS NOT NULL",
    order=["1-2", "3-5", "6-10", "10+"]
)


# COMMAND ----------

pdf = spark.sql("""
SELECT CASE WHEN total_outcomes <= 2 THEN '1-2'
            WHEN total_outcomes <= 5 THEN '3-5'
            WHEN total_outcomes <= 10 THEN '6-10'
            ELSE '10+' END AS label,
       SUM(CASE WHEN early_termination THEN 1 ELSE 0 END) AS early, COUNT(*) AS total
FROM (
  SELECT *, COALESCE(n_primary_outcomes,0) + COALESCE(n_secondary_outcomes,0)
              + COALESCE(n_other_outcomes,0) AS total_outcomes
  FROM cns_trials.`3_gold`.fact_study
  WHERE n_primary_outcomes IS NOT NULL
)
WHERE early_termination IS NOT NULL
GROUP BY 1
""").toPandas()
pdf["rate"] = pdf["early"] / pdf["total"]
plot_rate_bars(pdf, order=["1-2", "3-5", "6-10", "10+"], title="Early termination by number of outcome measures",
               bar_width=0.4, color="#2f6b62")

# COMMAND ----------

# MAGIC %md
# MAGIC

# COMMAND ----------

# MAGIC %md
# MAGIC ## 7) Intervention type associations with early termination.

# COMMAND ----------

# MAGIC %md
# MAGIC Chi-square test of independence (intervention type x early termination). As
# MAGIC with the disorder breakdown, a study can carry more than one intervention type (see
# MAGIC `bridge_study_intervention_type`), so this is not a partition of the 78,272 studies.

# COMMAND ----------

df_intervention = run_chi2("""
SELECT i.intervention_type AS label,
       SUM(CASE WHEN f.early_termination THEN 1 ELSE 0 END) AS early,
       SUM(CASE WHEN NOT f.early_termination THEN 1 ELSE 0 END) AS not_early,
       COUNT(*) AS total
FROM cns_trials.`3_gold`.fact_study f
JOIN cns_trials.`3_gold`.bridge_study_intervention_type i ON f.nct_id = i.nct_id
WHERE f.early_termination IS NOT NULL
GROUP BY i.intervention_type
""", min_n=30, sort_by="rate")

# COMMAND ----------

# MAGIC %md
# MAGIC **Follow-up: most frequent reason for stopping, by intervention type.**

# COMMAND ----------

top_reason(
    "i.intervention_type",
    extra_from="JOIN cns_trials.`3_gold`.bridge_study_intervention_type i ON f.nct_id = i.nct_id",
    rate_lookup=df_intervention
)

# COMMAND ----------

plot_rate_bars(df_intervention, horizontal=True, title="Early termination by intervention type")