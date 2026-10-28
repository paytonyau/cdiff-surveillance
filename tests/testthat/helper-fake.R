# helper-fake.R ---- test helpers. The synthetic generators live in R/demo.R.
fake_cfg <- function(root = tempdir()) {
  cfg <- load_config(project_root(testthat::test_path("..", "..")))
  cfg$root <- root
  cfg$paths <- lapply(cfg$paths, function(p) file.path(root, basename(p)))
  cfg
}
