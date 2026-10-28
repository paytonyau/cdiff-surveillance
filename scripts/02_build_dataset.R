# Stage 2: parse (cached, parallel) -> documented corrections -> QC -> cleaned dataset in data/derived/.
#   Rscript scripts/02_build_dataset.R           (add --refresh as an argument to ignore the cache)
root <- if (file.exists("config/params.yml")) "." else ".."
source(file.path(root, "R", "utils.R")); source(file.path(root, "R", "pipeline.R")); source_all(root)
cfg <- load_config(root)
log <- readr::read_csv(file.path(cfg$paths$raw, "RETRIEVAL_LOG.csv"), show_col_types = FALSE) |>
  dplyr::mutate(path = file.path(cfg$paths$raw, paste0(file_id, ".", file_type)), ok = file.exists(path))
built <- stage_build(cfg, log, workers = n_workers(cfg$parse$workers), refresh = "--refresh" %in% commandArgs(TRUE))
print(built$qc$verdict)
