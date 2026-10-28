# Methods

This is a **descriptive surveillance exercise** on aggregated public data. It describes patterns; it does not estimate causal effects, rank trusts, or declare outbreaks.

## 1. Building one series from many files

1. **Fetch** every file in `config/sources.csv` (existing valid files are kept; each download is checked to be a real spreadsheet, not an HTML error page).
2. **Parse** each file once into a tidy table. Several layout variants are handled (see `docs/data-sources.md`). Unknown metric labels, unknown organisation types or a missing header row stop the build with a clear message instead of guessing.
3. **Correct** known source errors from `config/corrections.csv` (logged).
4. **Check** quality (below). Duplicate keys stop the build.
5. **Combine** with one rule: *each organisation-month-measure is taken from the most recent release that contains it.* Earlier values are kept for the revision analysis.

Parsed files are cached by file hash and parser version, so only new or changed files are re-read.

## 2. Automated checks (every build)

| Check | Rationale |
|---|---|
| Required columns present in every file | Layout drift |
| No duplicate organisation-month-measure within a file | Source errors (one was found and corrected) |
| Six onset components sum to the total | Internal consistency |
| Trust, Sub-ICB and National totals agree each month | They are the same cases; disagreement signals a parsing or coverage problem |
| No month missing from the series | Gaps between files |
| No missing counts | Parsing |

## 3. Descriptive analyses

- **National series:** sum over NHS acute trusts only. Trailing 3-month mean. The last three months are marked provisional.
- **Annual totals:** by NHS financial year (April to March) and calendar year; year-on-year change only between complete years.
- **Onset composition:** each category as a share of all cases (unknown and no-information combined).
- **Seasonality:** index of each month against that year's average (complete years only), and a robust STL decomposition of log counts (trend, seasonal %, remainder %).
- **Region and trust comparisons use each unit's own history.** Without bed-day denominators, raw counts mostly reflect size. Regions are indexed to their own pre-COVID mean (April 2019 to February 2020 = 100). For trusts, the rate ratio of cases per month in the last 12 months to the baseline period is shown with an exact Poisson 95% interval; only trusts with at least 30 baseline cases and complete data in both windows are included.
- **Concentration and dispersion:** Lorenz curve/Gini of cases across trusts and the variance-to-mean ratio of trust-month counts, as context for the count model.

## 4. Exceedance detection (three methods, each using only earlier months)

| Method | Rule |
|---|---|
| Naive | count > mean + 2 SD of all earlier months |
| EARS C2 | count > mean + 3 SD of a 7-month baseline ending 3 months earlier |
| Rolling negative binomial | Fit `count ~ trend + sin + cos` (annual harmonic) on the previous 36 months, excluding the COVID window; flag if the observed count exceeds the 97.5th percentile of the predictive distribution |

A minimum of 24 months of history is required before any flag. Methods are compared by number of flags and pairwise agreement (Jaccard). **A flag is a prompt to look, not evidence of an outbreak.** These rules have **not** been validated against known outbreaks (see Limitations).

## 5. Revisions

For every trust-month, each release is compared with its final (most recent) value, by the number of months between the data month and the release. This quantifies how provisional the latest months are and supports reading real-time flags cautiously.

## 6. Limitations

- **Counts, not rates.** No denominator (bed-days) is published with these files. Differences between trusts mix infection risk with size, case-mix and testing practice. UKHSA itself states the data are not a basis for comparing trusts.
- **Attribution.** Cases belong to the reporting laboratory's trust, not necessarily where infection was acquired.
- **Mergers.** Trust boundaries change; trust-level histories are not like-for-like across them. Regional and national series are more robust.
- **Provisional data.** Recent months are revised after release and some trust-months are unsigned.
- **COVID-19.** March 2020 to June 2021 is shaded and excluded from model training; the choice of window is an assumption (`config/params.yml`).
- **Short baseline.** About seven years of consistent definitions; seasonal and trend estimates are uncertain.
- **Method validation.** Thresholds are arbitrary and untested against known outbreaks; no sensitivity or false-alarm analysis has been done yet (see `docs/roadmap.md`).
- **Ecological and aggregate data.** No individual-level, age or sex information; no inference about individuals.
