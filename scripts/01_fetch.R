# Stage 1: download the files listed in config/sources.csv (only what is missing).
#   Rscript scripts/01_fetch.R
root <- if (file.exists("config/params.yml")) "." else ".."
source(file.path(root, "R", "utils.R")); source(file.path(root, "R", "pipeline.R")); source_all(root)
cfg <- load_config(root)
log <- stage_fetch(cfg, workers = n_workers(cfg$parse$workers))
print(log[, c("file_id", "ok", "retrieved")], n = Inf)
