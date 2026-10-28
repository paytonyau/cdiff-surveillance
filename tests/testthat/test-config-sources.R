test_that("config loads and paths are absolute", {
  cfg <- load_config(project_root(testthat::test_path("..", "..")))
  expect_true(all(startsWith(unlist(cfg$paths), cfg$root)))
  expect_s3_class(cfg$analysis$covid_window, "Date"); expect_length(cfg$analysis$covid_window, 2)
})

test_that("config/sources.csv is well formed and covers every month without gaps", {
  cfg <- load_config(project_root(testthat::test_path("..", "..")))
  src <- read_sources(cfg)
  expect_false(anyDuplicated(src$file_id) > 0); expect_false(anyDuplicated(src$url) > 0)
  expect_true(all(startsWith(src$url, "https://")))
  expect_false(anyNA(src$release_date))
  expect_true(all(src$file_type %in% c("ods", "xlsx")))
  covered <- unique(unlist(lapply(seq_len(nrow(src)), function(i)
    format(seq(as.Date(paste0(src$window_start[i], "-01")), as.Date(paste0(src$window_end[i], "-01")), by = "month"), "%Y-%m"))))
  want <- format(seq(cfg$project$series_start, as.Date(paste0(max(src$window_end), "-01")), by = "month"), "%Y-%m")
  expect_equal(setdiff(want, covered), character(0))                    # every month from series_start is in at least one file
})

test_that("corrections file has the columns the code needs", {
  cfg <- load_config(project_root(testthat::test_path("..", "..")))
  corr <- readr::read_csv(cfg$paths$corrections, show_col_types = FALSE)
  expect_true(all(c("source_file", "org_code_from", "org_name_pattern", "org_code_to", "reason") %in% names(corr)))
})

test_that("organisation changes reference table is well formed", {
  root <- project_root(testthat::test_path("..", ".."))
  ch <- readr::read_csv(file.path(root, "data", "reference", "organisation_changes.csv"), show_col_types = FALSE)
  expect_true(all(c("date", "surviving_code", "absorbed_code", "description", "source") %in% names(ch)))
  expect_false(anyNA(as.Date(ch$date)))
  expect_false(any(ch$surviving_code == ch$absorbed_code))
})
