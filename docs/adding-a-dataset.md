# Adding another dataset (e.g. Scotland, Wales, bed-days)

The pipeline is organised so a new source touches few files. The contract is a **harmonised long table**:

| Column | Meaning |
|---|---|
| `source_file` | Identifier of the file/release the value came from |
| `month` | `Date`, first of the month |
| `org_type`, `org_code`, `org_name`, `region` | Geography (use the source's own codes; add a lookup in `data/reference/`) |
| `measure` | A code listed in `MEASURES` (`R/utils.R`) or a new one added there |
| `count` | Numeric |
| `signed_off`, `changed` | Optional provenance flags (`NA` if not published) |

## Steps

1. **List the files** in `config/sources.csv` (or a new `config/<dataset>_sources.csv`) with `release_date` so overlaps resolve.
2. **Write a parser** `R/parse_<dataset>.R` exposing `parse_<dataset>_file(path, file_id)` that returns `list(data = <harmonised table>, layout = <one-row tibble>)`, as `parse_file()` does. Fail loudly on anything unrecognised.
3. **Add tests** with a tiny fixture in `tests/testthat/fixtures/` (see `tests/make_fixtures.py`) covering every layout variant you have seen.
4. **Record known errors** in `config/corrections.csv`.
5. **Reuse** `build_clean()`, the QC functions and the analysis functions; they work on the harmonised schema.
6. **Document** the source in `docs/data-sources.md`, including how its case definitions differ.

## Cautions for cross-nation comparisons

Case definitions, onset categories, age ranges and reporting units differ between England, Scotland, Wales and Northern Ireland. Compare *within* a nation over time before comparing *between* nations, and say explicitly what is not comparable.

## Denominators

Rates need a denominator. For NHS trusts this is occupied or available bed-days (NHS England KH03 returns); for sub-ICB locations it is population. Keep denominators as separate tables keyed by `org_code` and `month` (or year), and join them in the analysis stage, not in the cleaned surveillance table.
