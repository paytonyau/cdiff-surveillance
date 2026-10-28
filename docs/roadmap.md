# Roadmap

Status is honest: **done** means built and tested; everything else is planned and not started.

## Done
- Reproducible fetch -> parse -> QC -> clean pipeline for 81 UKHSA files (Apr 2019 to Aug 2026), with caching and parallel parsing
- Automated data-quality checks and documented corrections
- Descriptive, seasonal, regional and trust-level analyses; three exceedance methods; revision analysis
- HTML report, 14 figures, test suite (130+ tests), CI configuration, demo mode on synthetic data

## Next (analysis)
- [ ] **Denominators and maps.** Join NHS England KH03 occupied bed-days (trust level) and ONS population (sub-ICB) to produce proper rates; map regional and sub-ICB rates with boundary files from the ONS Open Geography Portal. Raw-count maps are deliberately not produced, because they mostly show population size.
- [ ] **Validate the exceedance methods.** Seed known artificial outbreaks into the series and report sensitivity, false-alarm rate and timeliness for each method; compare with the Farrington methods in the `surveillance` package.
- [ ] **Real-time vs final.** Re-run exceedance on each historical *release* (what an analyst would have seen at the time) and compare with flags on final data, using the revision archive.
- [ ] **Interrupted time series** for the COVID-19 period with seasonality and autocorrelation handled explicitly.
- [ ] **Merger-adjusted trust series** (combine absorbed trusts into survivors using `data/reference/organisation_changes.csv`).
- [ ] Check whether pre-April-2019 months can be made comparable.

## Next (data)
- [ ] **Scotland (Public Health Scotland)**, then Wales and Northern Ireland, with explicit notes on definition differences (`docs/adding-a-dataset.md`).
- [ ] **Automatic discovery of new releases** (GOV.UK content API or page scrape) so `sources.csv` updates itself; scheduled monthly CI run.
- [ ] Related HCAI series (MRSA, MSSA, E. coli bacteraemia) via the same adapter pattern.

## Next (engineering)
- [ ] `renv` lockfile for exact package versions
- [ ] Consider migrating the pipeline to `targets`
- [ ] Package the functions (R package) if reuse by others becomes a goal
