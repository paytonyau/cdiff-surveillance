# pipeline.R ------------------------------------------------------------
# The four stages. Each returns its products and logs how long it took.
#   stage_fetch   : download files listed in config/sources.csv
#   stage_build   : parse (cached, parallel) -> correct -> QC -> clean dataset
#   stage_analyse : compute every result, write figures and tables
#   stage_report  : render the HTML report

timed <- function(label, expr) {
  t0 <- Sys.time(); on.exit(say("%s done in %.1f s", label, as.numeric(Sys.time() - t0, units = "secs")))
  force(expr)
}

source_all <- function(root = project_root()) {
  for (f in list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE)) source(f, local = FALSE)
}

stage_fetch <- function(cfg, workers = 1L, force = FALSE) {
  timed("fetch", {
    sources <- read_sources(cfg)
    fetch_sources(sources, cfg, workers = workers, force = force)
  })
}

stage_build <- function(cfg, log, workers = 1L, refresh = FALSE) {
  timed("build", {
    sources <- read_sources(cfg)
    parsed  <- parse_all(log, cfg, workers = workers, refresh = refresh)
    corr    <- readr::read_csv(cfg$paths$corrections, show_col_types = FALSE)
    fixed   <- apply_corrections(parsed$data, corr)
    all_long <- fixed$data
    if (nrow(fixed$applied)) say("applied %d documented correction(s)", nrow(fixed$applied))

    dups <- qc_duplicates(all_long)
    if (nrow(dups)) {
      readr::write_csv(dups, file.path(ensure_dir(cfg$paths$derived, "qc"), "duplicates.csv"))
      stop(nrow(dups), " duplicated organisation-month-measure keys within files (see data/derived/qc/duplicates.csv). ",
           "If they are source errors, add a row to config/corrections.csv.", call. = FALSE)
    }
    clean  <- build_clean(all_long, sources)
    lookup <- build_org_lookup(clean)
    qc     <- run_qc(all_long, clean, sources, parsed$layout)

    out <- ensure_dir(cfg$paths$derived)
    qcd <- ensure_dir(out, "qc")
    readr::write_csv(clean,  file.path(out, "cdiff_england_clean.csv.gz"))
    readr::write_csv(lookup, file.path(out, "org_lookup.csv"))
    readr::write_csv(parsed$layout, file.path(qcd, "layout.csv"))
    readr::write_csv(fixed$applied, file.path(qcd, "corrections_applied.csv"))
    for (n in c("completeness", "unsigned", "org_coverage", "revisions", "changed")) readr::write_csv(qc[[n]], file.path(qcd, paste0(n, ".csv")))
    readr::write_csv(qc$verdict, file.path(qcd, "verdict.csv"))
    for (n in names(qc$checks)) if (nrow(qc$checks[[n]])) readr::write_csv(qc$checks[[n]], file.path(qcd, paste0("FAIL_", n, ".csv")))
    if (any(qc$verdict$status != "pass")) warning("Some QC checks failed: see data/derived/qc/ and the verdict table.", call. = FALSE)
    list(all_long = all_long, clean = clean, lookup = lookup, qc = qc, sources = sources, layout = parsed$layout)
  })
}

stage_analyse <- function(cfg, clean, lookup, all_long = NULL, sources = NULL, qc = NULL, demo = FALSE) {
  timed("analyse", {
    nat  <- national_series(clean, cfg)
    comp <- composition(nat)
    si   <- seasonal_index(nat, cfg$analysis$primary_measure)
    stl  <- stl_decompose(nat, cfg$analysis$primary_measure)
    idx  <- baseline_index(clean, lookup, cfg, by = "region", which_measure = cfg$analysis$primary_measure)
    ti   <- trust_index(clean, lookup, cfg, which_measure = cfg$analysis$primary_measure)
    res  <- run_exceedance(nat, cfg)
    conc <- case_concentration(clean, cfg)
    dist <- trust_month_distribution(clean, cfg)
    cov  <- reporting_coverage(clean, cfg)
    rev  <- if (!is.null(all_long) && !is.null(sources)) revision_profile(all_long, sources, cfg) else NULL
    key  <- key_numbers(nat, res, cfg)
    ch_file <- file.path(cfg$paths$reference, "organisation_changes.csv")
    org_changes <- if (file.exists(ch_file) && !demo) readr::read_csv(ch_file, show_col_types = FALSE) else NULL

    # exceedance for each onset category (appendix material)
    res_all <- purrr::map_dfr(c("total", "HOHA", "COHA", "COIA", "COCA"), ~ run_exceedance(nat, cfg, .x))

    plots <- list(
      "01_overview"            = plot_overview(nat, cfg),
      "02_composition_counts"  = plot_composition_counts(comp, cfg),
      "03_composition_share"   = plot_composition_share(comp, cfg),
      "04_seasonal_heatmap"    = plot_seasonal_heatmap(si),
      "05_stl_decomposition"   = plot_stl(stl),
      "06_region_index"        = plot_region_index(idx, cfg),
      "07_trust_index"         = plot_trust_index(ti, cfg),
      "08_trust_small_multiples" = plot_trust_small_multiples(clean, lookup, cfg),
      "09_exceedance"          = plot_exceedance(res, cfg),
      "10_trust_distribution"  = plot_trust_distribution(dist),
      "11_concentration"       = plot_concentration(conc),
      "12_reporting_coverage"  = plot_coverage(cov, org_changes))
    if (!is.null(rev)) plots <- c(plots, list("13_revision_by_lag" = plot_revision_lag(rev), "14_revision_national" = plot_revision_national(rev, cfg)))
    heights <- c("08_trust_small_multiples" = 10, "07_trust_index" = 7.5, "05_stl_decomposition" = 7.5, "04_seasonal_heatmap" = 5)
    for (n in names(plots)) save_plot(plots[[n]], n, cfg, height = heights[n] %||% cfg$figures$height)
    say("saved %d figures to %s", length(plots), cfg$paths$figures)

    tabs <- list(
      key_numbers = table_key_numbers(key), annual_financial = table_annual(nat, "financial"), annual_calendar = table_annual(nat, "calendar"),
      exceedance_flags = table_flags(res), exceedance_summary = exceedance_summary(res), exceedance_agreement = exceedance_agreement(res),
      trust_index = table_trust_index(ti), seasonal_index = si$summary,
      revisions = if (!is.null(rev)) table_revisions(rev), qc = if (!is.null(qc)) table_qc(qc), file_coverage = if (!is.null(qc)) table_file_coverage(qc))
    for (n in names(tabs)) if (!is.null(tabs[[n]])) write_table(tabs[[n]], n, cfg)

    results <- list(generated = Sys.time(), demo = demo, key = key, national = nat, tables = tabs, res = res, res_all = res_all,
                    conc = conc[c("gini", "top10_share")], dist = dist[c("mean", "var", "dispersion", "zero_share")],
                    n_trusts = dplyr::n_distinct(clean$org_code[clean$org_type == cfg$analysis$org_type]),
                    figures = names(plots), sessioninfo = utils::capture.output(print(utils::sessionInfo())))
    dir <- ensure_dir(if (demo) cfg$paths$figures |> dirname() else cfg$paths$derived)
    saveRDS(results, file.path(dir, "results.rds"))
    results
  })
}

stage_report <- function(cfg, demo = FALSE) {
  timed("report", {
    if (!requireNamespace("rmarkdown", quietly = TRUE)) stop("Package 'rmarkdown' is needed to render the report", call. = FALSE)
    results <- file.path(if (demo) dirname(cfg$paths$figures) else cfg$paths$derived, "results.rds")
    out_dir <- if (demo) dirname(cfg$paths$figures) else file.path(cfg$root, "outputs")
    rmarkdown::render(file.path(cfg$root, "reports", "report.Rmd"), output_dir = out_dir, output_file = "report.html",
                      params = list(results = results, figures = cfg$paths$figures, demo = demo),
                      intermediates_dir = tempdir(), knit_root_dir = cfg$root, quiet = TRUE, envir = new.env())
  })
}

#' Demo configuration: same settings, but everything is written under outputs/demo
demo_config <- function(cfg) {
  d <- ensure_dir(cfg$root, "outputs", "demo")
  cfg$paths$figures <- ensure_dir(d, "figures"); cfg$paths$tables <- ensure_dir(d, "tables")
  cfg
}
