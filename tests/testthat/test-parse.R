fx <- function(f) testthat::test_path("fixtures", f)

test_that("metric labels are recognised with and without hyphens", {
  new <- c("Total cases", "Hospital-onset, healthcare-associated", "Community-onset, healthcare-associated",
           "Community-onset, indeterminate-association", "Community-onset, community-associated", "Unknown", "No information")
  old <- c("Total cases", "Hospital-onset, healthcare associated", "Community-onset, healthcare associated",
           "Community-onset, indeterminate association", "Community-onset, community associated", "Unknown", "No information")
  expected <- c("total", "HOHA", "COHA", "COIA", "COCA", "unknown", "no_info")
  expect_equal(classify_metric(new), expected)
  expect_equal(classify_metric(old), expected)
  expect_true(is.na(classify_metric("Hospital-onset")))        # plain "Hospital-onset" is NOT HOHA: never guess
  expect_true(is.na(classify_metric("Something else")))
})

test_that("2024+ layout parses: sheet found by name, header on row 4, National rows kept", {
  r <- parse_file(fx("new_layout.xlsx"), "new")
  expect_equal(r$layout$sheet, "Table_2_raw_data"); expect_equal(r$layout$header_row, 4)
  expect_equal(r$layout$missing_required, ""); expect_equal(r$layout$missing_optional, "")
  expect_setequal(unique(r$data$org_type), c("NHS acute trust", "Sub-ICB", "National"))
  expect_false(anyNA(r$data$measure)); expect_false(anyNA(r$data$month)); expect_s3_class(r$data$month, "Date")
  expect_true(all(r$data$org_name == stringr::str_squish(r$data$org_name)))       # stray spaces removed
})

test_that("2019-2021 layout parses: header row 1, PHE Centre alias, CCG -> Sub-ICB, optional columns filled", {
  r <- parse_file(fx("old_layout.xlsx"), "old")
  expect_equal(r$layout$header_row, 1)
  expect_match(r$layout$missing_optional, "icb"); expect_match(r$layout$missing_optional, "region name")
  expect_false(grepl("ukhsa centre", r$layout$missing_optional))                   # aliased from "PHE Centre"
  expect_setequal(unique(r$data$org_type), c("NHS acute trust", "Sub-ICB"))
  expect_true(all(is.na(r$data$region)))
})

test_that("components add up to the total in the fixtures (sanity of the fixtures themselves)", {
  r <- parse_file(fx("new_layout.xlsx"), "new")
  expect_equal(nrow(qc_components(r$data)), 0)
  expect_equal(nrow(qc_duplicates(r$data)), 0)
  expect_equal(nrow(qc_geographies(r$data)), 0)
})

test_that("unknown metric labels and missing header rows fail loudly instead of guessing", {
  expect_error(parse_file(fx("bad_metric.xlsx"), "x"), "Mystery category")
  expect_error(parse_file(fx("no_header.xlsx"), "x"), "No data sheet")
})

test_that("parse_all caches by file hash and re-reads when forced", {
  tmp <- withr::local_tempdir(); cfg <- fake_cfg(tmp)
  log <- tibble::tibble(file_id = c("a", "b"), path = c(fx("new_layout.xlsx"), fx("old_layout.xlsx")), ok = TRUE,
                        md5 = unname(tools::md5sum(c(fx("new_layout.xlsx"), fx("old_layout.xlsx")))))
  first <- suppressMessages(parse_all(log, cfg, workers = 1))
  expect_equal(length(list.files(file.path(tmp, "cache", "parsed"))), 2)
  expect_message(parse_all(log, cfg, workers = 1), "2 cached, 0 to parse")
  expect_equal(nrow(first$data), 56 + 42); expect_equal(nrow(first$layout), 2)
})
