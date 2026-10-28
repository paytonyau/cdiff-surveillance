cfg <- fake_cfg()
clean <- fake_clean(40, seed = 3); lookup <- build_org_lookup(clean); nat <- national_series(clean, cfg)
v <- fake_vintages(); cfg_rev <- cfg; cfg_rev$project$series_start <- as.Date("2024-01-01")
rev <- revision_profile(v$all_long, v$sources, cfg_rev)

built <- function(p) { b <- ggplot2::ggplot_build(p); expect_s3_class(p, c("ggplot", "patchwork"), exact = FALSE); invisible(b) }

test_that("every figure builds and renders to a PNG", {
  res <- run_exceedance(nat, cfg)
  plots <- list(
    overview = plot_overview(nat, cfg), comp_counts = plot_composition_counts(composition(nat), cfg), comp_share = plot_composition_share(composition(nat), cfg),
    heat = plot_seasonal_heatmap(seasonal_index(nat)), stl = plot_stl(stl_decompose(nat)),
    region = plot_region_index(baseline_index(clean, lookup, cfg), cfg), trust_idx = plot_trust_index(trust_index(clean, lookup, cfg), cfg),
    small = plot_trust_small_multiples(clean, lookup, cfg), exceed = plot_exceedance(res, cfg),
    dist = plot_trust_distribution(trust_month_distribution(clean, cfg)), conc = plot_concentration(case_concentration(clean, cfg)),
    cov = plot_coverage(reporting_coverage(clean, cfg)), rev_lag = plot_revision_lag(rev), rev_nat = plot_revision_national(rev, cfg))
  cfg$paths$figures <- withr::local_tempdir()
  for (n in names(plots)) {
    expect_s3_class(plots[[n]], "gg")
    f <- save_plot(plots[[n]], n, modifyList(cfg, list(figures = list(width = 6, height = 4, dpi = 60))), width = 6, height = 4)
    expect_gt(file.size(f), 5000)
  }
})

test_that("empty inputs give a placeholder figure, not an error", {
  expect_s3_class(plot_region_index(dplyr::filter(baseline_index(clean, lookup, cfg), FALSE), cfg), "gg")
  expect_s3_class(plot_trust_index(dplyr::filter(trust_index(clean, lookup, cfg), FALSE), cfg), "gg")
})

test_that("the measure palette covers every measure", {
  expect_true(all(MEASURES$measure %in% names(MEASURE_COLOURS)))
})

test_that("coverage figure accepts the merger annotations", {
  root <- project_root(testthat::test_path("..", ".."))
  ch <- readr::read_csv(file.path(root, "data", "reference", "organisation_changes.csv"), show_col_types = FALSE)
  g <- plot_coverage(reporting_coverage(clean, cfg), ch)
  expect_s3_class(g, "gg"); expect_gte(length(g$layers), 2)
  expect_s3_class(plot_coverage(reporting_coverage(clean, cfg), NULL), "gg")
})
