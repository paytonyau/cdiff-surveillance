# tables.R --------------------------------------------------------------
# Presentation tables (tibbles with display-ready columns). write_table() saves CSV for reuse.

fmt_int <- function(x) format(round(x), big.mark = ",", trim = TRUE)
fmt_pct <- function(x, digits = 1, sign = TRUE) ifelse(is.na(x), "", sprintf(paste0(if (sign) "%+." else "%.", digits, "f%%"), x))

write_table <- function(df, name, cfg) {
  path <- file.path(ensure_dir(cfg$paths$tables), paste0(name, ".csv"))
  readr::write_csv(df, path); invisible(path)
}

table_annual <- function(national, basis = c("financial", "calendar"), measures = c("total", "HOHA", "COHA", "COIA", "COCA")) {
  basis <- match.arg(basis)
  a <- annual_summary(national, basis, measures)
  a |>
    dplyr::mutate(cell = dplyr::if_else(complete,
                                        paste0(fmt_int(cases), dplyr::if_else(is.na(change_pct), "", paste0(" (", fmt_pct(change_pct), ")"))),
                                        paste0(fmt_int(cases), " *"))) |>
    dplyr::select(measure, period, cell) |>
    dplyr::mutate(measure = measure_label(measure)) |>
    dplyr::arrange(measure, period) |>
    tidyr::pivot_wider(names_from = measure, values_from = cell) |>
    dplyr::rename(dplyr::all_of(stats::setNames("period", if (basis == "financial") "Financial year" else "Calendar year")))
}

table_key_numbers <- function(k) {
  tibble::tribble(
    ~Indicator, ~Value,
    "Latest month", format(k$last_month, "%B %Y"),
    "Cases in latest month (provisional)", fmt_int(k$last_count),
    "Same month a year earlier", ifelse(is.na(k$yago_count), "n/a", fmt_int(k$yago_count)),
    "Cases in the last 12 months", fmt_int(k$last12),
    "Cases in the 12 months before that", ifelse(is.na(k$prev12), "n/a", fmt_int(k$prev12)),
    "Mean monthly cases, pre-COVID baseline", fmt_int(k$baseline_mean),
    "Mean monthly cases, last 12 months", fmt_int(k$last12_mean),
    "Last 12 months vs baseline", fmt_pct(k$vs_baseline_pct),
    "Peak month in the series", sprintf("%s (%s cases)", format(k$peak_month, "%B %Y"), fmt_int(k$peak_count)))
}

table_flags <- function(res) {
  res |>
    dplyr::filter(n_methods > 0) |>
    dplyr::arrange(dplyr::desc(month)) |>
    dplyr::transmute(Month = format(month, "%b %Y"), Cases = fmt_int(count),
                     `Expected (NB)` = ifelse(is.na(expected_nb), "", fmt_int(expected_nb)),
                     `NB limit` = ifelse(is.na(upper_nb), "", fmt_int(upper_nb)),
                     `EARS limit` = ifelse(is.na(thr_ears), "", fmt_int(thr_ears)),
                     `Naive limit` = ifelse(is.na(thr_naive), "", fmt_int(thr_naive)),
                     Methods = n_methods, `In COVID window` = ifelse(covid, "yes", ""),
                     Provisional = ifelse(provisional, "yes", ""))
}

table_trust_index <- function(ti, n = 12) {
  d <- dplyr::bind_rows(utils::head(ti, n), utils::tail(ti, n)) |> dplyr::distinct(org_code, .keep_all = TRUE)
  d |> dplyr::transmute(Trust = short_trust(org_name %||% org_code), Region = region,
                        `Baseline cases/month` = sprintf("%.1f", x0 / n0), `Last 12 months cases/month` = sprintf("%.1f", x1 / n1),
                        `Rate ratio (95% CI)` = sprintf("%.2f (%.2f to %.2f)", rr, lo, hi))
}

table_revisions <- function(rev) {
  rev$by_lag |> dplyr::filter(lag >= 0, n >= 20) |>
    dplyr::transmute(`Months after data month` = lag, `Trust-months` = n, `% later revised` = sprintf("%.1f%%", share_revised),
                     `Mean abs. change (cases)` = sprintf("%.2f", mean_abs_diff), `Net vs final` = fmt_pct(net_pct, 2))
}

table_qc <- function(qc) {
  qc$verdict |> dplyr::transmute(Check = check, Problems = n_problems, Result = status)
}

table_file_coverage <- function(qc) {
  qc$completeness |> dplyr::transmute(File = source_file, `First month` = format(first_month, "%b %Y"), `Last month` = format(last_month, "%b %Y"),
                                      Months = n_months, Trusts = n_trusts, `Sub-ICBs` = n_subicb, Rows = n_rows)
}
