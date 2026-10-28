mk <- function(file, month, count, code = "R1", org_type = "NHS acute trust", measure = "total", name = "Alpha", region = NA_character_, signed = "Yes") {
  tibble::tibble(source_file = file, month = as.Date(month), org_type = org_type, org_code = code, org_name = name, region = region,
                 measure = measure, count = count, signed_off = signed, changed = "No")
}
sources <- tibble::tibble(file_id = c("old", "new"), release_date = as.Date(c("2025-01-08", "2025-02-05")), window_end = c("2025-01", "2025-02"))

test_that("the most recent release wins for each organisation-month-measure", {
  all_long <- dplyr::bind_rows(mk("old", "2025-01-01", 10), mk("new", "2025-01-01", 12), mk("old", "2024-12-01", 7))
  cl <- build_clean(all_long, sources)
  expect_equal(nrow(cl), 2)
  expect_equal(cl$count[cl$month == as.Date("2025-01-01")], 12)         # revised value from the newer file
  expect_equal(cl$count[cl$month == as.Date("2024-12-01")], 7)          # only in the old file: kept
  expect_equal(unique(cl$source_release[cl$month == as.Date("2025-01-01")]), as.Date("2025-02-05"))
})

test_that("documented corrections recode only the intended file, organisation and code, and are logged", {
  corr <- tibble::tibble(source_file = "old", org_code_from = "RCF", org_name_pattern = "^Liverpool Women", org_code_to = "REP", reason = "test")
  d <- dplyr::bind_rows(mk("old", "2025-01-01", 1, code = "RCF", name = "Airedale"), mk("old", "2025-01-01", 2, code = "RCF", name = "Liverpool Women's"),
                        mk("new", "2025-01-01", 3, code = "RCF", name = "Liverpool Women's"))
  f <- apply_corrections(d, corr)
  expect_equal(f$data$org_code, c("RCF", "REP", "RCF"))                 # Airedale and the other file untouched
  expect_equal(nrow(f$applied), 1); expect_equal(f$applied$org_code_to, "REP")
  expect_equal(nrow(qc_duplicates(f$data)), 0)
})

test_that("duplicates, component mismatches and geography mismatches are detected", {
  d <- dplyr::bind_rows(mk("old", "2025-01-01", 1), mk("old", "2025-01-01", 2))
  expect_equal(nrow(qc_duplicates(d)), 1)

  comps <- purrr::map_dfr(c(total = 10, HOHA = 4, COHA = 2, COIA = 1, COCA = 2, unknown = 0, no_info = 0), identity) |>
    tidyr::pivot_longer(dplyr::everything(), names_to = "measure", values_to = "count")
  ok  <- dplyr::bind_cols(mk("f", "2025-01-01", NA), dplyr::select(comps, measure, count) |> dplyr::rename(measure2 = measure, count2 = count)) |>
    dplyr::mutate(measure = measure2, count = count2) |> dplyr::select(-measure2, -count2)
  expect_equal(nrow(qc_components(ok)), 1)                              # 4+2+1+2 = 9 != 10: flagged

  geo <- dplyr::bind_rows(mk("f", "2025-01-01", 10), mk("f", "2025-01-01", 9, code = "S1", org_type = "Sub-ICB"))
  expect_equal(nrow(qc_geographies(geo)), 1)
})

test_that("organisation lookup takes the latest name and the most recent non-missing region", {
  cl <- dplyr::bind_rows(mk("old", "2024-01-01", 1, name = "Old name", region = "North West"),
                         mk("new", "2025-01-01", 1, name = "New name", region = NA)) |>
    dplyr::mutate(source_release = as.Date("2025-02-05"))
  lk <- build_org_lookup(cl)
  expect_equal(lk$org_name, "New name"); expect_equal(lk$region, "North West")
})

test_that("revisions are detected between releases (trust level)", {
  src <- dplyr::bind_rows(sources, tibble::tibble(file_id = "newest", release_date = as.Date("2025-03-05"), window_end = "2025-03"))
  d <- dplyr::bind_rows(mk("old", "2025-01-01", 10), mk("new", "2025-01-01", 12), mk("newest", "2025-01-01", 12), mk("old", "2024-12-01", 5), mk("new", "2024-12-01", 5))
  rv <- qc_revisions(d, src)
  expect_equal(nrow(rv), 3)                                             # three published values of the changed key
  expect_true(all(rv$first_count == 10 & rv$final_count == 12))
})
