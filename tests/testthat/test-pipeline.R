test_that("non-demo analysis stage (QC + revisions) and the report run end to end on synthetic data", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc not available")
  tmp <- withr::local_tempdir(); cfg <- fake_cfg(tmp)
  root <- project_root(testthat::test_path("..", ".."))
  dir.create(file.path(tmp, "reports")); dir.create(file.path(tmp, "reference"))
  file.copy(file.path(root, "reports", c("report.Rmd", "style.css")), file.path(tmp, "reports"))
  file.copy(file.path(root, "data", "reference", "organisation_changes.csv"), file.path(tmp, "reference"))

  trust <- fake_clean(30, seed = 21)
  subicb <- dplyr::mutate(trust, org_type = "Sub-ICB", org_code = paste0("S", org_code))      # same cases, second geography
  all_long <- dplyr::bind_rows(trust, subicb) |> dplyr::select(-source_release)
  src <- tibble::tibble(file_id = "FAKE", release_date = as.Date("2026-10-07"), window_start = "2019-04", window_end = "2026-08")
  clean <- build_clean(all_long, src); lookup <- build_org_lookup(clean)
  qc <- run_qc(all_long, clean, src, tibble::tibble(file_id = "FAKE", missing_required = ""))
  expect_true(all(qc$verdict$status == "pass"))

  res <- stage_analyse(cfg, clean, lookup, all_long, src, qc, demo = FALSE)
  expect_length(res$figures, 14)
  expect_equal(length(list.files(cfg$paths$figures, pattern = "png$")), 14)
  expect_true(all(c("qc", "revisions", "file_coverage", "annual_financial") %in% names(Filter(Negate(is.null), res$tables))))
  expect_true(file.exists(file.path(cfg$paths$derived, "results.rds")))

  out <- stage_report(cfg)
  expect_true(file.exists(file.path(tmp, "outputs", "report.html")))
  expect_gt(file.size(file.path(tmp, "outputs", "report.html")), 1e6)
  html <- paste(readLines(file.path(tmp, "outputs", "report.html"), warn = FALSE), collapse = " ")
  expect_false(grepl("SYNTHETIC DEMONSTRATION", html))                       # banner only in demo mode
  expect_true(grepl("Automated checks run on every build", html))
})
