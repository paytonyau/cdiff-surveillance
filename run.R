#!/usr/bin/env Rscript
# run.R -- one command for the whole pipeline.
#
#   Rscript run.R                  # fetch (only what is missing) -> build -> analyse -> report
#   Rscript run.R --refresh        # ignore the parse cache and re-read every file
#   Rscript run.R --workers=4      # parallel parsing/downloading (default: cores - 1)
#   Rscript run.R --skip-fetch     # use files already in data/raw
#   Rscript run.R --no-report      # stop after figures and tables
#   Rscript run.R --dpi=100        # faster, lower-resolution figures for quick previews
#   Rscript run.R --demo           # SYNTHETIC data: preview the full report in outputs/demo/
#
# Stages can also be run individually: scripts/01_fetch.R ... scripts/04_report.R

args <- commandArgs(trailingOnly = TRUE)
flag <- function(name) any(args == paste0("--", name))
opt  <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), args, value = TRUE); if (length(h)) sub(paste0("^--", name, "="), "", h[1]) else default }

root <- normalizePath(if (file.exists("config/params.yml")) "." else dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])))
source(file.path(root, "R", "utils.R")); source(file.path(root, "R", "pipeline.R")); source_all(root)
cfg <- load_config(root)
workers <- n_workers(as.integer(opt("workers", cfg$parse$workers)))
if (!is.null(opt("dpi"))) cfg$figures$dpi <- as.numeric(opt("dpi"))      # e.g. --dpi=100 for quick previews

if (flag("demo")) {
  say("DEMO MODE: synthetic data, outputs go to outputs/demo/")
  cfg <- demo_config(cfg)
  clean <- fake_clean(134); lookup <- build_org_lookup(clean); v <- fake_vintages(14)
  stage_analyse(cfg, clean, lookup, v$all_long, v$sources, qc = NULL, demo = TRUE)
  if (!flag("no-report")) stage_report(cfg, demo = TRUE)
  quit(status = 0)
}

log   <- if (flag("skip-fetch")) readr::read_csv(file.path(cfg$paths$raw, "RETRIEVAL_LOG.csv"), show_col_types = FALSE) |>
           dplyr::mutate(path = file.path(cfg$paths$raw, paste0(file_id, ".", file_type)), ok = file.exists(path)) else stage_fetch(cfg, workers)
built   <- stage_build(cfg, log, workers, refresh = flag("refresh"))
results <- stage_analyse(cfg, built$clean, built$lookup, built$all_long, built$sources, built$qc)
if (!flag("no-report")) stage_report(cfg)
say("finished. Report: outputs/report.html")
