# demo.R ----------------------------------------------------------------
# SYNTHETIC data with the same schema as the real cleaned dataset. Used by
#   * `Rscript run.R --demo`  -> preview the full report and figures before real data is parsed
#   * the test-suite          -> exercise every function without downloading anything
# It is NOT real surveillance data, and demo outputs are written to outputs/demo/ only.

fake_clean <- function(n_trusts = 60, start = as.Date("2019-04-01"), end = as.Date("2026-08-01"), seed = 1, national_mean = 1500) {
  set.seed(seed)
  months <- seq(start, end, by = "month")
  regions <- c("East of England", "London", "Midlands", "North East and Yorkshire", "North West", "South East", "South West")
  trusts <- tibble::tibble(org_code = sprintf("R%02d", seq_len(n_trusts)),
                           org_name = sprintf("FAKE TRUST %02d NHS FOUNDATION TRUST", seq_len(n_trusts)),
                           region = sample(regions, n_trusts, replace = TRUE),
                           size = stats::rlnorm(n_trusts, 0, 0.6))
  trusts$size <- trusts$size / sum(trusts$size)
  grid <- tidyr::expand_grid(trusts, month = months)
  mon <- lubridate::month(grid$month); tt <- as.numeric(grid$month - start) / 365
  seasonal <- 1 + 0.08 * cos(2 * pi * (mon - 2) / 12)
  covid <- ifelse(grid$month >= as.Date("2020-03-01") & grid$month <= as.Date("2021-06-01"), 0.85, 1)
  trend <- 1 + 0.03 * tt
  mu <- national_mean * grid$size * seasonal * covid * trend
  grid$total <- stats::rnbinom(nrow(grid), mu = mu, size = 12)
  grid$total[grid$org_code == "R05" & grid$month == as.Date("2025-01-01")] <- grid$total[grid$org_code == "R05" & grid$month == as.Date("2025-01-01")] + 40  # a planted spike
  p <- c(HOHA = .44, COHA = .17, COIA = .11, COCA = .26, unknown = .012, no_info = .008)
  comp <- t(vapply(grid$total, function(n) if (n == 0) rep(0, 6) else as.vector(stats::rmultinom(1, n, p)), numeric(6)))
  colnames(comp) <- names(p)
  wide <- dplyr::bind_cols(dplyr::select(grid, org_code, org_name, region, month), tibble::as_tibble(comp), total = grid$total)
  long <- tidyr::pivot_longer(wide, c(total, dplyr::all_of(names(p))), names_to = "measure", values_to = "count")
  dplyr::mutate(long, source_file = "FAKE", org_type = "NHS acute trust", signed_off = "Yes", changed = "No",
                source_release = as.Date("2026-10-07")) |>
    dplyr::select(source_file, month, org_type, org_code, org_name, region, measure, count, signed_off, changed, source_release)
}

#' Rolling 13-month files released monthly, where the latest 3 months are revised later.
fake_vintages <- function(n_files = 8, seed = 2) {
  set.seed(seed)
  rel <- seq(as.Date("2025-01-08"), by = "month", length.out = n_files)
  trusts <- sprintf("R%02d", 1:10)
  truth <- tidyr::expand_grid(org_code = trusts, month = seq(as.Date("2024-01-01"), by = "month", length.out = n_files + 12)) |>
    dplyr::mutate(final = stats::rpois(dplyr::n(), 12))
  sources <- tibble::tibble(file_id = sprintf("F%02d", seq_len(n_files)), release_date = rel,
                            window_start = format(seq(as.Date("2024-01-01"), by = "month", length.out = n_files), "%Y-%m"),
                            window_end = format(seq(as.Date("2025-01-01"), by = "month", length.out = n_files), "%Y-%m"))
  all_long <- purrr::map2_dfr(seq_len(n_files), rel, function(i, r) {
    win <- seq(as.Date("2024-01-01"), by = "month", length.out = n_files + 12)[i:(i + 12)]
    d <- truth |> dplyr::filter(month %in% win)
    age <- (lubridate::year(r) - lubridate::year(d$month)) * 12 + lubridate::month(r) - lubridate::month(d$month)
    d$count <- ifelse(age <= 2 & stats::runif(nrow(d)) < 0.3, d$final - stats::rpois(nrow(d), 1), d$final)  # recent months under-reported at first
    dplyr::mutate(d, source_file = sources$file_id[i], org_type = "NHS acute trust", org_name = org_code, region = NA_character_,
                  measure = "total", signed_off = "Yes", changed = "No", release_date = r) |>
      dplyr::select(source_file, month, org_type, org_code, org_name, region, measure, count, signed_off, changed)
  })
  list(sources = sources, all_long = all_long)
}
