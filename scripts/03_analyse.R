# Stage 3: every result, figure and table, from the cleaned dataset + the per-file data.
#   Rscript scripts/03_analyse.R
root <- if (file.exists("config/params.yml")) "." else ".."
source(file.path(root, "R", "utils.R")); source(file.path(root, "R", "pipeline.R")); source_all(root)
cfg <- load_config(root)
log <- readr::read_csv(file.path(cfg$paths$raw, "RETRIEVAL_LOG.csv"), show_col_types = FALSE) |>
  dplyr::mutate(path = file.path(cfg$paths$raw, paste0(file_id, ".", file_type)), ok = file.exists(path))
built <- stage_build(cfg, log, workers = n_workers(cfg$parse$workers))      # fast when the parse cache is warm
invisible(stage_analyse(cfg, built$clean, built$lookup, built$all_long, built$sources, built$qc))
