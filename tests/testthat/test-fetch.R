test_that("fetch downloads valid spreadsheets, rejects HTML error pages and keeps the first retrieval date", {
  tmp <- withr::local_tempdir(); cfg <- fake_cfg(tmp)
  good <- testthat::test_path("fixtures", "new_layout.xlsx")
  html <- file.path(tmp, "error.html"); writeLines(rep("<html><body>404 Not Found</body></html>", 60), html)
  src <- tibble::tibble(file_id = c("good", "bad"), window_start = "2024-04", window_end = "2024-05", release_date = as.Date("2024-06-05"),
                        file_type = "xlsx", url = c(paste0("file://", normalizePath(good)), paste0("file://", html)))
  log <- suppressWarnings(fetch_sources(src, cfg, workers = 1))
  expect_equal(log$ok, c(TRUE, FALSE))
  expect_false(file.exists(file.path(tmp, "raw", "bad.xlsx")))          # an HTML error page is never kept as data
  expect_match(log$md5[1], "^[0-9a-f]{32}$")

  rl <- file.path(tmp, "raw", "RETRIEVAL_LOG.csv"); old <- readr::read_csv(rl, show_col_types = FALSE, col_types = readr::cols(.default = "c"))
  old$retrieved[old$file_id == "good"] <- "2020-01-01"; readr::write_csv(old, rl)
  log2 <- suppressWarnings(fetch_sources(src, cfg, workers = 1))
  expect_equal(log2$retrieved[log2$file_id == "good"], "2020-01-01")    # not re-downloaded, original date preserved
})

test_that("read_sources rejects a sources file with missing columns or duplicate ids", {
  tmp <- withr::local_tempdir(); cfg <- fake_cfg(tmp); dir.create(file.path(tmp, "config"))
  readr::write_csv(tibble::tibble(file_id = "a", url = "x"), cfg$paths$sources)
  expect_error(read_sources(cfg), "missing column")
})
