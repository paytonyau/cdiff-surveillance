# Stage 4: render outputs/report.html from the saved results.
#   Rscript scripts/04_report.R
root <- if (file.exists("config/params.yml")) "." else ".."
source(file.path(root, "R", "utils.R")); source(file.path(root, "R", "pipeline.R")); source_all(root)
stage_report(load_config(root))
