cfg <- fake_cfg()
clean <- fake_clean(40, seed = 11); lookup <- build_org_lookup(clean); nat <- national_series(clean, cfg)

test_that("national series uses one geography and has the expected shape", {
  expect_equal(dplyr::n_distinct(nat$measure), 7)
  expect_equal(nrow(dplyr::filter(nat, measure == "total")), 89)
  tot <- dplyr::filter(nat, measure == "total")
  expect_equal(tot$count[1], sum(clean$count[clean$measure == "total" & clean$month == tot$month[1]]))
  expect_true(all(is.na(tot$ma[1:2])) && !is.na(tot$ma[3]))              # trailing 3-month mean needs 3 months
  expect_equal(sum(nat$provisional[nat$measure == "total"]), 3)
  expect_true(all(nat$covid[nat$month == as.Date("2020-06-01")]))
})

test_that("components sum to the total in the national series", {
  w <- tidyr::pivot_wider(dplyr::select(nat, month, measure, count), names_from = measure, values_from = count)
  expect_equal(w$total, rowSums(w[COMPONENTS]))
})

test_that("annual summaries flag incomplete years and compute change on complete years only", {
  a <- annual_summary(nat, "financial", "total")
  expect_false(tail(a$complete, 1)); expect_true(is.na(tail(a$change_pct, 1)))
  expect_true(is.na(a$change_pct[1]))
  expect_equal(a$change_pct[2], (a$cases[2] / a$cases[1] - 1) * 100)
  expect_equal(fin_year(as.Date(c("2024-03-01", "2024-04-01", "2025-01-15"))), c("2023/24", "2024/25", "2024/25"))
})

test_that("STL, seasonal index and composition behave", {
  s <- stl_decompose(nat); expect_equal(nrow(s), 89)
  expect_lt(max(abs(s$seasonal_pct[1:12] - s$seasonal_pct[13:24])), 1e-6)       # periodic seasonal component
  si <- seasonal_index(nat); expect_true(all(dplyr::summarise(si$matrix, m = mean(index), .by = year)$m - 100 < 1e-9))
  cp <- composition(nat); expect_equal(dplyr::n_distinct(cp$measure), 5)
  chk <- dplyr::summarise(cp, s = sum(share), .by = month); expect_true(all(abs(chk$s - 100) < 1e-9))
})

test_that("exceedance methods flag a clear planted spike and stay quiet on flat noise", {
  spiked <- nat; i <- which(spiked$measure == "total" & spiked$month == as.Date("2025-06-01")); spiked$count[i] <- spiked$count[i] * 1.8
  res <- run_exceedance(spiked, cfg)
  r <- dplyr::filter(res, month == as.Date("2025-06-01"))
  expect_true(r$flag_nb && r$flag_ears && r$flag_naive)
  expect_equal(r$n_methods, 3)
  expect_false(any(res$flag_nb[res$month < as.Date("2021-04-01")]))              # min_history: no flags in the first 24 months
  set.seed(5); flat <- tibble::tibble(month = seq(as.Date("2019-04-01"), by = "month", length.out = 60), count = stats::rpois(60, 500), covid = FALSE, provisional = FALSE)
  nb <- exceed_nb(flat, exclude_covid = FALSE); expect_lt(mean(nb$flag_nb, na.rm = TRUE), 0.1)
})

test_that("NB training can leave out the COVID window", {
  tot <- dplyr::filter(nat, measure == "total") |> dplyr::select(month, count, covid, provisional)
  a <- exceed_nb(tot, exclude_covid = TRUE); b <- exceed_nb(tot, exclude_covid = FALSE)
  expect_false(isTRUE(all.equal(a$upper_nb, b$upper_nb)))
})

test_that("trust index returns rate ratios whose intervals contain the estimate", {
  ti <- trust_index(clean, lookup, cfg)
  expect_gt(nrow(ti), 10)
  expect_true(all(ti$lo <= ti$rr & ti$rr <= ti$hi)); expect_true(all(ti$x0 >= cfg$analysis$index_min_baseline_cases))
  expect_equal(ti$rr[1], max(ti$rr))
})

test_that("baseline index equals 100 on average over the baseline window", {
  idx <- baseline_index(clean, lookup, cfg)
  bw <- cfg$analysis$baseline_window
  m <- dplyr::filter(idx, month >= bw[1], month <= bw[2]) |> dplyr::summarise(m = mean(index), .by = region)
  expect_true(all(abs(m$m - 100) < 1e-9))
})

test_that("revision profile shows revisions only at short lags in the synthetic vintages", {
  v <- fake_vintages(); cfg2 <- cfg; cfg2$project$series_start <- as.Date("2024-01-01")
  rv <- revision_profile(v$all_long, v$sources, cfg2)
  expect_gt(max(rv$by_lag$share_revised[rv$by_lag$lag <= 2]), 0)
  expect_true(all(rv$by_lag$share_revised[rv$by_lag$lag >= 3] == 0))
  settled <- dplyr::filter(rv$national, month <= as.Date("2024-12-01"))                 # months whose final value is itself settled
  expect_true(all(settled$diff <= 0))                                            # first releases under-reported in the simulation
})

test_that("concentration, distribution and headline numbers are sensible", {
  cc <- case_concentration(clean, cfg); expect_gt(cc$gini, 0); expect_lt(cc$gini, 1); expect_gt(cc$top10_share, 10)
  d <- trust_month_distribution(clean, cfg); expect_gt(d$dispersion, 1)
  res <- run_exceedance(nat, cfg); k <- key_numbers(nat, res, cfg)
  expect_equal(k$n_months, 89); expect_equal(k$last_month, as.Date("2026-08-01")); expect_equal(k$last12, sum(utils::tail(dplyr::filter(nat, measure == "total")$count, 12)))
})
