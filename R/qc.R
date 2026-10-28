# qc.R ------------------------------------------------------------------
# Data-quality checks on the stacked, per-file data (all_long) and on the cleaned dataset.
# Each check returns a tibble that is EMPTY when the check passes.

KEY <- c("month", "org_type", "org_code", "measure")

qc_completeness <- function(all_long) {
  all_long |>
    dplyr::group_by(source_file) |>
    dplyr::summarise(first_month = min(month), last_month = max(month), n_months = dplyr::n_distinct(month),
                     n_trusts = dplyr::n_distinct(org_code[org_type == "NHS acute trust"]),
                     n_subicb = dplyr::n_distinct(org_code[org_type == "Sub-ICB"]),
                     n_rows = dplyr::n(), n_missing = sum(is.na(count)), .groups = "drop")
}

#' The same organisation x month x measure twice in one file
qc_duplicates <- function(all_long) {
  dt <- data.table::as.data.table(all_long)[, c("source_file", KEY), with = FALSE]      # data.table: ~20x faster than dplyr::count here
  tibble::as_tibble(dt[, .N, by = c("source_file", KEY)][N > 1L]) |> dplyr::rename(n = N)
}

#' Do the six components add up to the total?
qc_components <- function(all_long) {
  all_long |>
    dplyr::select(source_file, month, org_type, org_code, measure, count) |>
    tidyr::pivot_wider(names_from = measure, values_from = count) |>
    dplyr::mutate(components = rowSums(dplyr::across(dplyr::all_of(COMPONENTS)))) |>
    dplyr::filter(total != components)
}

#' Trust, Sub-ICB (and National, in 2024+ files) are the same cases on different geographies: totals must agree.
#' NEVER sum them: that doubles the national count.
qc_geographies <- function(all_long) {
  x <- all_long |>
    dplyr::filter(measure == "total") |>
    dplyr::group_by(source_file, month, org_type) |>
    dplyr::summarise(total = sum(count), .groups = "drop") |>
    tidyr::pivot_wider(names_from = org_type, values_from = total)
  if (!"National" %in% names(x)) x$National <- NA_real_
  x |>
    dplyr::mutate(diff_subicb = `NHS acute trust` - `Sub-ICB`, diff_national = `NHS acute trust` - National) |>
    dplyr::filter(diff_subicb != 0 | (!is.na(diff_national) & diff_national != 0))
}

#' Trust-months the publisher marks as not yet signed off (provisional)
qc_unsigned <- function(all_long) {
  all_long |> dplyr::filter(signed_off == "No") |> dplyr::distinct(source_file, month, org_code, org_name)
}

qc_org_coverage <- function(all_long) {
  all_long |>
    dplyr::group_by(org_type, org_code) |>
    dplyr::summarise(first = min(month), last = max(month), n_months = dplyr::n_distinct(month),
                     n_names = dplyr::n_distinct(org_name), .groups = "drop")
}

qc_missing_months <- function(clean) {
  have <- sort(unique(clean$month))
  all_m <- seq(min(have), max(have), by = "month")
  tibble::tibble(month = all_m[!all_m %in% have])
}

#' Per organisation x month x measure: how did the published value change across releases?
#' (trust level only: Sub-ICB and National rows repeat the same cases.)
qc_revisions <- function(all_long, sources) {
  rk <- release_ranks(sources)
  dt <- data.table::as.data.table(
    all_long |> dplyr::filter(org_type == "NHS acute trust") |> dplyr::left_join(rk, by = "source_file"))
  key <- c("month", "org_code", "measure")
  data.table::setorderv(dt, c(key, "rank"))
  dt[, `:=`(first_count = count[1], final_count = count[.N], n_files = .N,
            n_values = data.table::uniqueN(count), first_release = release_date[1], final_release = release_date[.N]),
     by = key]
  tibble::as_tibble(dt[n_values > 1, ])
}

#' Run every check and return a named list plus a one-line verdict table.
run_qc <- function(all_long, clean, sources, layout) {
  checks <- list(
    layout      = dplyr::filter(layout, nzchar(missing_required)),
    duplicates  = qc_duplicates(all_long),
    components  = qc_components(all_long),
    geographies = qc_geographies(all_long),
    missing     = qc_missing_months(clean),
    na_counts   = dplyr::filter(all_long, is.na(count)))
  verdict <- tibble::tibble(
    check = c("Layout: required columns present in every file", "No duplicate organisation-month-measure within a file",
              "Six components add up to the total", "Trust, Sub-ICB and National totals agree",
              "No month missing from the series", "No missing counts"),
    n_problems = vapply(checks, nrow, integer(1)),
    status = ifelse(n_problems == 0, "pass", "FAIL"))
  list(checks = checks, verdict = verdict,
       completeness = qc_completeness(all_long), unsigned = qc_unsigned(all_long),
       org_coverage = qc_org_coverage(all_long), revisions = qc_revisions(all_long, sources),
       changed = dplyr::filter(all_long, changed == "Yes"))
}
