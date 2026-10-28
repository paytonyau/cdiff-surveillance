# Configuration

| File | Purpose |
|---|---|
| `params.yml` | Every tunable setting (paths, COVID window, baseline window, exceedance parameters, figure size). Change values here, not in code. |
| `sources.csv` | One row per UKHSA spreadsheet: where to download it, which months it covers and when it was released. |
| `corrections.csv` | Documented corrections for known errors in the source files. Each row says what is changed and why. |

## `sources.csv` columns

| Column | Meaning |
|---|---|
| `file_id` | Unique name, `CDI_<first month>_<last month>` (e.g. `CDI_2024-03_2025-03`). Used for the local file name. |
| `window_start`, `window_end` | First and last month covered (`YYYY-MM`). Files are rolling 13-month windows, plus two financial-year files. |
| `release_date` | Publication date, taken from the update history on the GOV.UK page. **Decides which file wins when releases overlap** (later release wins; ties broken by `window_end`). |
| `file_type` | `ods` (preferred) or `xlsx`. |
| `url` | Download address. Older files point at the UK Government Web Archive. |
| `url_xlsx`, `url_alt`, `notes` | Optional: alternative formats/addresses and free-text provenance. |

To add a new monthly release: append one row, then run `Rscript run.R`. Only the new file is downloaded and parsed.
A test (`tests/testthat/test-config-sources.R`) checks that the listed windows cover every month from `series_start` with no gaps.

## `corrections.csv`

| Column | Meaning |
|---|---|
| `source_file` | The only file the correction applies to |
| `org_code_from` | The wrong organisation code |
| `org_name_pattern` | Regular expression the organisation name must match (so only the intended organisation is changed) |
| `org_code_to` | The corrected code |
| `reason` | Why. Every applied correction is logged to `data/derived/qc/corrections_applied.csv`. |

Corrections are for unambiguous source errors only. If the pipeline stops on duplicated keys, inspect `data/derived/qc/duplicates.csv` before adding a row.
