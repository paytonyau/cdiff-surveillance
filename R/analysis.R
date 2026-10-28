# analysis.R ------------------------------------------------------------
# Pure functions: data in, tibble/list out. No plotting, no file I/O.
# All use ONE geography (trust level) so cases are never counted twice.

# ---- national series ------------------------------------------------------------------------------
national_series <- function(clean, cfg) {
  w <- cfg$analysis$ma_window
  out <- clean |>
    dplyr::filter(org_type == cfg$analysis$org_type, month >= cfg$project$series_start) |>
    dplyr::group_by(month, measure) |>
    dplyr::summarise(count = sum(count, na.rm = TRUE), n_trusts = dplyr::n_distinct(org_code), .groups = "drop") |>
    dplyr::arrange(measure, month) |>
    dplyr::group_by(measure) |>
    dplyr::mutate(ma = slider::slide_dbl(count, mean, .before = w - 1, .complete = TRUE)) |>
    dplyr::ungroup()
  latest3 <- utils::tail(sort(unique(out$month)), 3)
  dplyr::mutate(out, covid = in_covid(month, cfg), provisional = month %in% latest3)
}

#' Annual totals (calendar or NHS financial year) with year-on-year change for complete years only
annual_summary <- function(national, basis = c("calendar", "financial"),
                           measures = c("total", "HOHA", "COHA", "COIA", "COCA")) {
  basis <- match.arg(basis)
  national |>
    dplyr::filter(measure %in% measures) |>
    dplyr::mutate(period = if (basis == "calendar") as.character(lubridate::year(month)) else fin_year(month)) |>
    dplyr::group_by(measure, period) |>
    dplyr::summarise(cases = sum(count), months = dplyr::n(), .groups = "drop") |>
    dplyr::arrange(measure, period) |>
    dplyr::group_by(measure) |>
    dplyr::mutate(complete = months == 12,
                  change_pct = dplyr::if_else(complete & dplyr::lag(complete, default = FALSE),
                                              (cases / dplyr::lag(cases) - 1) * 100, NA_real_)) |>
    dplyr::ungroup()
}

#' Onset composition: each component as a share of all cases (unknown and no-information combined)
composition <- function(national) {
  parts <- national |>
    dplyr::filter(measure %in% c("HOHA", "COHA", "COIA", "COCA", "unknown", "no_info")) |>
    dplyr::mutate(measure = dplyr::if_else(measure %in% c("unknown", "no_info"), "other", measure)) |>
    dplyr::group_by(month, measure) |>
    dplyr::summarise(count = sum(count), .groups = "drop")
  tot <- dplyr::filter(national, measure == "total") |> dplyr::select(month, total = count)
  dplyr::left_join(parts, tot, by = "month") |>
    dplyr::mutate(share = count / total * 100) |>
    dplyr::group_by(measure) |> dplyr::arrange(month) |>
    dplyr::mutate(share_ma = slider::slide_dbl(share, mean, .before = 2, .complete = TRUE)) |>
    dplyr::ungroup()
}

# ---- seasonality ----------------------------------------------------------------------------------
#' Year x calendar-month index (100 = that year's monthly average), complete years only
seasonal_index <- function(national, which_measure = "total") {
  x <- national |>
    dplyr::filter(measure == which_measure) |>
    dplyr::mutate(year = lubridate::year(month), mon = lubridate::month(month, label = TRUE))
  full <- x |>
    dplyr::group_by(year) |> dplyr::filter(dplyr::n() == 12) |>
    dplyr::mutate(index = count / mean(count) * 100) |> dplyr::ungroup()
  list(matrix = full,
       summary = full |> dplyr::filter(!covid) |> dplyr::group_by(mon) |>
         dplyr::summarise(mean_index = mean(index), sd_index = stats::sd(index), n_years = dplyr::n(), .groups = "drop"))
}

#' Robust STL on log counts: trend (cases), seasonal effect (%), remainder (%)
stl_decompose <- function(national, which_measure = "total") {
  x <- national |> dplyr::filter(measure == which_measure) |> dplyr::arrange(month)
  if (nrow(x) < 24) stop("STL needs at least 24 months", call. = FALSE)
  y <- stats::ts(log(pmax(x$count, 1)), start = c(lubridate::year(min(x$month)), lubridate::month(min(x$month))), frequency = 12)
  fit <- stats::stl(y, s.window = "periodic", robust = TRUE)$time.series
  tibble::tibble(month = x$month, observed = x$count, trend = exp(fit[, "trend"]),
                 seasonal_pct = (exp(fit[, "seasonal"]) - 1) * 100, remainder_pct = (exp(fit[, "remainder"]) - 1) * 100)
}

# ---- indices relative to the pre-COVID baseline (no denominators needed) --------------------------------
#' Monthly counts by a grouping (e.g. region) as an index of that group's own baseline mean (100)
baseline_index <- function(clean, lookup, cfg, by = "region", which_measure = "total") {
  bw <- cfg$analysis$baseline_window
  x <- clean |>
    dplyr::filter(org_type == cfg$analysis$org_type, measure == which_measure, month >= cfg$project$series_start) |>
    with_org(lookup) |>
    dplyr::filter(!is.na(.data[[by]])) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by)), month) |>
    dplyr::summarise(count = sum(count), .groups = "drop")
  base <- x |> dplyr::filter(month >= bw[1], month <= bw[2]) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by))) |> dplyr::summarise(baseline = mean(count), .groups = "drop")
  x |> dplyr::inner_join(base, by = by) |>
    dplyr::mutate(index = count / baseline * 100) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by))) |> dplyr::arrange(month, .by_group = TRUE) |>
    dplyr::mutate(index_ma = slider::slide_dbl(index, mean, .before = 2, .complete = TRUE)) |>
    dplyr::ungroup()
}

#' Per trust: last-N-months vs baseline rate ratio with an exact Poisson 95% CI.
#' Only trusts with enough baseline cases and complete data in both windows are included.
trust_index <- function(clean, lookup, cfg, which_measure = "total", last_n = 12) {
  bw <- cfg$analysis$baseline_window
  x <- clean |> dplyr::filter(org_type == cfg$analysis$org_type, measure == which_measure, month >= cfg$project$series_start)
  recent_months <- utils::tail(sort(unique(x$month)), last_n)
  n0_expected <- length(seq(bw[1], bw[2], by = "month"))
  base <- x |> dplyr::filter(month >= bw[1], month <= bw[2]) |>
    dplyr::group_by(org_code) |> dplyr::summarise(x0 = sum(count), n0 = dplyr::n_distinct(month), .groups = "drop")
  rec <- x |> dplyr::filter(month %in% recent_months) |>
    dplyr::group_by(org_code) |> dplyr::summarise(x1 = sum(count), n1 = dplyr::n_distinct(month), .groups = "drop")
  d <- dplyr::inner_join(base, rec, by = "org_code") |>
    dplyr::filter(n0 == n0_expected, n1 == last_n, x0 >= cfg$analysis$index_min_baseline_cases)
  if (nrow(d) == 0) return(dplyr::mutate(d, rr = numeric(), lo = numeric(), hi = numeric(), org_name = character(), region = character()))
  ci <- purrr::pmap(d[c("x1", "x0", "n1", "n0")], function(x1, x0, n1, n0) {
    t <- stats::poisson.test(c(x1, x0), c(n1, n0)); c(rr = unname(t$estimate), lo = t$conf.int[1], hi = t$conf.int[2])
  })
  dplyr::bind_cols(d, dplyr::bind_rows(lapply(ci, as.list))) |>
    with_org(lookup) |> dplyr::arrange(dplyr::desc(rr))
}

# ---- exceedance: three methods, one comparison table ----------------------------------------------------
exceed_naive <- function(df, k = 2, min_history = 24) {
  df |> dplyr::arrange(month) |>
    dplyr::mutate(thr_naive  = slider::slide_dbl(count, ~ mean(.x) + k * stats::sd(.x), .before = Inf, .after = -1),
                  n_prev     = dplyr::row_number() - 1L,
                  flag_naive = n_prev >= min_history & count > thr_naive)
}

#' EARS C2 (Hutwagner et al.): baseline of 7 months ending 3 months before, threshold mean + k * SD
exceed_ears <- function(df, k = 3, min_history = 24) {
  df |> dplyr::arrange(month) |>
    dplyr::mutate(thr_ears  = slider::slide_dbl(count, ~ mean(.x) + k * stats::sd(.x), .before = 9, .after = -3, .complete = TRUE),
                  flag_ears = dplyr::row_number() - 1L >= min_history & !is.na(thr_ears) & count > thr_ears)
}

#' Rolling negative binomial, one step ahead: fit trend + annual harmonic on the previous `window`
#' months (optionally leaving out the COVID window) and flag a count above the upper prediction limit.
exceed_nb <- function(df, window = 36, min_history = 24, level = 0.975, exclude_covid = TRUE, min_train = 18) {
  df <- df |> dplyr::arrange(month) |>
    dplyr::mutate(t = dplyr::row_number(), s = sin(2 * pi * lubridate::month(month) / 12), c = cos(2 * pi * lubridate::month(month) / 12))
  res <- vector("list", nrow(df))
  for (i in seq_len(nrow(df))) {
    if (i - 1 < min_history) next
    tr <- df[max(1, i - window):(i - 1), ]
    if (exclude_covid) tr <- tr[!tr$covid, ]
    if (nrow(tr) < min_train) next
    fit <- tryCatch(suppressWarnings(MASS::glm.nb(count ~ t + s + c, data = tr)), error = function(e) NULL)
    if (is.null(fit)) next
    mu <- unname(stats::predict(fit, newdata = df[i, ], type = "response"))
    res[[i]] <- tibble::tibble(month = df$month[i], expected_nb = mu, upper_nb = stats::qnbinom(level, mu = mu, size = fit$theta))
  }
  dplyr::left_join(dplyr::select(df, -t, -s, -c), dplyr::bind_rows(res), by = "month") |>
    dplyr::mutate(flag_nb = !is.na(upper_nb) & count > upper_nb)
}

run_exceedance <- function(national, cfg, which_measure = cfg$analysis$primary_measure) {
  ex <- cfg$analysis$exceedance
  x <- national |> dplyr::filter(measure == which_measure) |> dplyr::select(month, count, covid, provisional)
  x |>
    exceed_naive(ex$naive_k, ex$min_history) |>
    exceed_ears(ex$ears_k, ex$min_history) |>
    exceed_nb(ex$nb_window, ex$min_history, ex$nb_level, ex$nb_exclude_covid) |>
    dplyr::mutate(n_methods = flag_naive + flag_ears + flag_nb, measure = which_measure)
}

exceedance_summary <- function(res) {
  m <- c(naive = "flag_naive", ears = "flag_ears", nb = "flag_nb")
  elig <- res |> dplyr::filter(!is.na(upper_nb) | !is.na(thr_ears) | n_prev >= 24)
  purrr::imap_dfr(m, function(col, nm) {
    f <- elig[elig[[col]], ]
    tibble::tibble(method = nm, flags = nrow(f), flags_outside_covid = sum(!f$covid),
                   first_flag = if (nrow(f)) min(f$month) else as.Date(NA), last_flag = if (nrow(f)) max(f$month) else as.Date(NA))
  })
}

#' Pairwise agreement (Jaccard) between methods on the months they flag
exceedance_agreement <- function(res) {
  m <- c("flag_naive", "flag_ears", "flag_nb")
  jac <- function(a, b) { u <- sum(a | b); if (u == 0) NA_real_ else sum(a & b) / u }
  tidyr::expand_grid(a = m, b = m) |>
    dplyr::mutate(jaccard = purrr::map2_dbl(a, b, ~ jac(res[[.x]], res[[.y]])))
}

# ---- revisions: how much do published counts change after first release? ------------------------------
revision_profile <- function(all_long, sources, cfg, which_measure = "total") {
  rk <- release_ranks(sources)
  x <- all_long |>
    dplyr::filter(org_type == cfg$analysis$org_type, measure == which_measure, month >= cfg$project$series_start) |>
    dplyr::left_join(rk, by = "source_file")
  final <- x |> dplyr::group_by(month, org_code) |> dplyr::slice_max(rank, n = 1, with_ties = FALSE) |>
    dplyr::ungroup() |> dplyr::select(month, org_code, final = count)
  x <- x |> dplyr::inner_join(final, by = c("month", "org_code")) |>
    dplyr::mutate(lag = (lubridate::year(release_date) - lubridate::year(month)) * 12 + lubridate::month(release_date) - lubridate::month(month),
                  diff = count - final)
  by_lag <- x |> dplyr::group_by(lag) |>
    dplyr::summarise(n = dplyr::n(), share_revised = mean(diff != 0) * 100, mean_abs_diff = mean(abs(diff)),
                     net_diff = sum(diff), final_total = sum(final), .groups = "drop") |>
    dplyr::mutate(net_pct = net_diff / final_total * 100)
  first_file <- x |> dplyr::group_by(month) |> dplyr::summarise(first_rank = min(rank), .groups = "drop")
  national <- x |> dplyr::inner_join(first_file, by = "month") |> dplyr::filter(rank == first_rank) |>
    dplyr::group_by(month) |>
    dplyr::summarise(first_release = sum(count), final = sum(final), n_trusts = dplyr::n(), .groups = "drop") |>
    dplyr::mutate(diff = first_release - final, diff_pct = diff / final * 100)
  list(by_lag = by_lag, national = national)
}

# ---- trust-level descriptives (counts only: never rank trusts on raw counts) ---------------------------
#' Cases over the last N months per trust, with the trust's share and the cumulative share (Lorenz)
case_concentration <- function(clean, cfg, which_measure = "total", last_n = 12) {
  x <- clean |> dplyr::filter(org_type == cfg$analysis$org_type, measure == which_measure)
  keep <- utils::tail(sort(unique(x$month)), last_n)
  per <- x |> dplyr::filter(month %in% keep) |> dplyr::group_by(org_code) |>
    dplyr::summarise(cases = sum(count), .groups = "drop") |> dplyr::arrange(cases) |>
    dplyr::mutate(trust_share = dplyr::row_number() / dplyr::n(), cum_share = cumsum(cases) / sum(cases))
  gini <- 1 - 2 * sum((per$cum_share[-1] + per$cum_share[-nrow(per)]) / 2 * diff(per$trust_share)) - per$cum_share[1] * per$trust_share[1]
  list(per_trust = per, gini = gini,
       top10_share = sum(utils::tail(per$cases, ceiling(0.1 * nrow(per)))) / sum(per$cases) * 100)
}

#' Dispersion of trust-month counts (variance / mean) and share of zeros, last N months
trust_month_distribution <- function(clean, cfg, which_measure = "total", last_n = 12) {
  x <- clean |> dplyr::filter(org_type == cfg$analysis$org_type, measure == which_measure)
  x <- x |> dplyr::filter(month %in% utils::tail(sort(unique(x$month)), last_n))
  list(data = x, mean = mean(x$count), var = stats::var(x$count), dispersion = stats::var(x$count) / mean(x$count),
       zero_share = mean(x$count == 0) * 100)
}

reporting_coverage <- function(clean, cfg) {
  clean |> dplyr::filter(org_type == cfg$analysis$org_type, measure == "total", month >= cfg$project$series_start) |>
    dplyr::group_by(month) |> dplyr::summarise(n_trusts = dplyr::n_distinct(org_code), .groups = "drop")
}

# ---- headline numbers for the report text -----------------------------------------------------------
key_numbers <- function(national, res, cfg) {
  tot <- national |> dplyr::filter(measure == "total") |> dplyr::arrange(month)
  last <- tot[nrow(tot), ]
  yago <- tot |> dplyr::filter(month == last$month - lubridate::years(1))
  l12 <- utils::tail(tot$count, 12); p12 <- if (nrow(tot) >= 24) tot$count[(nrow(tot) - 23):(nrow(tot) - 12)] else NA
  bw <- cfg$analysis$baseline_window
  base <- tot |> dplyr::filter(month >= bw[1], month <= bw[2])
  peak <- tot[which.max(tot$count), ]
  list(first_month = min(tot$month), last_month = last$month, n_months = nrow(tot),
       last_count = last$count, yago_count = if (nrow(yago)) yago$count else NA,
       last12 = sum(l12), prev12 = if (all(is.na(p12))) NA else sum(p12),
       baseline_mean = mean(base$count), last12_mean = mean(l12),
       vs_baseline_pct = (mean(l12) / mean(base$count) - 1) * 100,
       peak_month = peak$month, peak_count = peak$count,
       n_flags_nb = sum(res$flag_nb, na.rm = TRUE), n_flags_any = sum(res$n_methods > 0, na.rm = TRUE))
}
