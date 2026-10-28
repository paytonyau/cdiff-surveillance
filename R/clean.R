# clean.R ---------------------------------------------------------------
# Turn the stacked per-file tables into ONE analysis-ready dataset.

#' Documented corrections for known source-data errors (config/corrections.csv).
#' Returns list(data, applied): the corrected data and a log of every change made.
apply_corrections <- function(df, corrections) {
  applied <- list()
  for (i in seq_len(nrow(corrections))) {
    cr  <- corrections[i, ]
    hit <- df$source_file == cr$source_file & df$org_code == cr$org_code_from &
           stringr::str_detect(df$org_name, cr$org_name_pattern)
    if (any(hit)) {
      applied[[length(applied) + 1]] <- df[hit, ] |>
        dplyr::distinct(source_file, org_name, month) |>
        dplyr::mutate(org_code_from = cr$org_code_from, org_code_to = cr$org_code_to, reason = cr$reason)
      df$org_code[hit] <- cr$org_code_to
    }
  }
  list(data = df, applied = dplyr::bind_rows(applied))
}

#' Rank files by release date (ties broken by window end): later = more authoritative.
release_ranks <- function(sources) {
  sources |>
    dplyr::arrange(release_date, window_end) |>
    dplyr::transmute(source_file = file_id, release_date, rank = dplyr::row_number())
}

#' RULE: each month x organisation x measure is taken from the MOST RECENT file containing it.
build_clean <- function(all_long, sources) {
  dt <- data.table::as.data.table(dplyr::left_join(all_long, release_ranks(sources), by = "source_file"))
  key <- c("month", "org_type", "org_code", "measure")
  data.table::setorderv(dt, c(key, "rank"), order = c(1L, 1L, 1L, 1L, -1L))
  dt <- dt[!duplicated(dt, by = key)]
  out <- tibble::as_tibble(dt[, `:=`(rank = NULL)])
  dplyr::rename(out, source_release = release_date) |> dplyr::arrange(org_type, org_code, measure, month)
}

#' One row per organisation: latest name and region, first/last month reported.
#' Older files lack Region name, so the region is taken from the most recent file that has one.
build_org_lookup <- function(clean) {
  clean |>
    dplyr::filter(org_type == "NHS acute trust") |>
    dplyr::distinct(org_code, org_name, region, month, source_release) |>
    dplyr::arrange(org_code, month) |>
    dplyr::group_by(org_code) |>
    dplyr::summarise(org_name   = dplyr::last(org_name),
                     region     = { r <- region[!is.na(region)]; if (length(r)) r[length(r)] else NA_character_ },
                     first_month = min(month), last_month = max(month), n_months = dplyr::n_distinct(month),
                     n_names = dplyr::n_distinct(org_name), .groups = "drop")
}

#' Attach the lookup's (latest) region and name to any table with org_code.
with_org <- function(df, lookup) {
  dplyr::left_join(dplyr::select(df, -dplyr::any_of(c("region", "org_name"))),
                   dplyr::select(lookup, org_code, org_name, region), by = "org_code")
}
