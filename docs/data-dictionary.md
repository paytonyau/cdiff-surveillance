# Data dictionary

## `data/derived/cdiff_england_clean.csv.gz`

One row per **organisation x month x measure**, taking each value from the most recent release that contains it.

| Column | Type | Description |
|---|---|---|
| `source_file` | text | `file_id` of the release the value was taken from |
| `source_release` | date | Publication date of that release |
| `month` | date | First day of the month the cases refer to (specimen month) |
| `org_type` | text | `NHS acute trust`, `Sub-ICB` or `National`. **Same cases, different geographies: never sum across types.** Analyses use `NHS acute trust`. |
| `org_code` | text | NHS ODS organisation code (e.g. `RAL`) |
| `org_name` | text | Name as published (whitespace cleaned) |
| `region` | text | NHS England region. Missing for older files; the analysis takes each trust's most recent known region from `org_lookup.csv`. |
| `measure` | text | One of the seven measures below |
| `count` | number | Number of cases |
| `signed_off` | text | `Yes` / `No` (trust sign-off) where published |
| `changed` | text | `Yes` if UKHSA marks the value as changed since the previous publication |

### Measures (UKHSA definitions, from the Cover sheet)

| `measure` | Name | Definition |
|---|---|---|
| `total` | Total cases | All reported cases; equals the sum of the six below |
| `HOHA` | Hospital-onset, healthcare-associated | Specimen date is 3 days or more after the current admission date (day of admission = day 1) |
| `COHA` | Community-onset, healthcare-associated | Not HOHA, and the patient was most recently discharged from the same reporting trust in the 28 days before the specimen date |
| `COIA` | Community-onset, indeterminate association | Not HOHA, and the patient was most recently discharged from the same trust 29 to 84 days before the specimen date |
| `COCA` | Community-onset, community-associated | Not HOHA, and the patient was not discharged from the same trust in the 84 days before the specimen date |
| `unknown` | Unknown | The trust answered "Don't know" to the prior-discharge question |
| `no_info` | No information | The trust gave no answer to the prior-admission questions |

## `data/derived/org_lookup.csv`

One row per trust: latest `org_name`, most recent non-missing `region`, `first_month`, `last_month`, `n_months`, `n_names`.

## `data/derived/qc/`

| File | Meaning |
|---|---|
| `verdict.csv` | Pass/fail summary of the automated checks |
| `layout.csv` | Per file: data sheet, header row, columns missing or extra |
| `completeness.csv` | Per file: months, trusts, sub-ICBs, rows, missing counts |
| `revisions.csv` | Trust-months whose published value changed between releases (first vs final) |
| `unsigned.csv` | Trust-months not signed off |
| `changed.csv` | Rows UKHSA marks as changed since the previous publication |
| `org_coverage.csv` | First/last month per organisation (mergers, renames) |
| `corrections_applied.csv` | Every documented correction applied |
| `FAIL_*.csv` | Present only if a check failed: the offending rows |

## `outputs/tables/`

CSV copies of every table in the report (annual totals, key numbers, exceedance flags and summary, trust rate ratios, revisions by lag, QC verdict, file coverage).

## `outputs/figures/`

Fourteen PNG figures (numbered `01_` to `14_`), 300 dpi by default.
