# parse.R ---------------------------------------------------------------
# Read one UKHSA CDI spreadsheet into a tidy long table. The file is read ONCE; the layout
# report is derived from the same read. Handles every layout seen across the 81 files:
#   * data sheet called "data" (2019-2024), "raw_data" or "Table_2_raw_data" (2024+): found by name,
#     else by probing for a header row containing Organisation code + Metric + Figure
#   * header on row 1 or row 4
#   * "PHE Centre" (old) vs "UKHSA centre"; STP (old) vs ICB; "CCG" (old) vs "Sub-ICB"
#   * metric labels with or without hyphens
#   * "National" (England) rows in 2024+ files

KNOWN_DATA_SHEETS <- c("data", "raw_data", "Table_2_raw_data")

REQ <- c(org_type = "Organisation type", org_code = "Organisation code", org_name = "Organisation name",
         year = "Year", month_num = "Month", metric = "Metric", count = "Figure")
OPT <- c(ukhsa_centre = "UKHSA centre", icb = "ICB", region = "Region name",
         signed_off = "Data signed off", changed = "Data changed since last publication?")

norm <- function(x) stringr::str_to_lower(stringr::str_squish(as.character(x)))
REQ_norm <- stats::setNames(norm(REQ), names(REQ))
OPT_norm <- stats::setNames(norm(OPT), names(OPT))

is_ods <- function(path) grepl("\\.ods$", path, ignore.case = TRUE)

list_sheets <- function(path) {
  if (is_ods(path)) {
    if (!requireNamespace("readODS", quietly = TRUE)) stop("Package 'readODS' is needed to read .ods files", call. = FALSE)
    readODS::list_ods_sheets(path)
  } else readxl::excel_sheets(path)
}

read_sheet_raw <- function(path, sheet, n = NULL) {
  rng <- if (is.null(n)) NULL else paste0("A1:Z", n)
  if (is_ods(path)) {
    if (is.null(rng)) readODS::read_ods(path, sheet = sheet, col_names = FALSE, col_types = NA)
    else readODS::read_ods(path, sheet = sheet, col_names = FALSE, col_types = NA, range = rng)
  } else {
    if (is.null(rng)) suppressMessages(readxl::read_excel(path, sheet = sheet, col_names = FALSE, col_types = "text"))
    else suppressMessages(readxl::read_excel(path, sheet = sheet, col_names = FALSE, col_types = "text", range = rng))
  }
}

is_header_row <- function(r) { n <- norm(r); all(c("organisation code", "metric", "figure") %in% n) }

#' Name of the sheet holding the tidy table (known names first, then probing)
find_data_sheet <- function(path, sheets = list_sheets(path)) {
  known <- intersect(KNOWN_DATA_SHEETS, sheets)
  for (s in c(known, setdiff(sheets, known))) {
    top <- tryCatch(read_sheet_raw(path, s, n = 30), error = function(e) NULL)
    if (!is.null(top) && any(apply(top, 1, is_header_row))) return(s)
  }
  NA_character_
}

std_names <- function(nm) {                       # "PHE Centre" is the old name of "UKHSA centre"
  if ("phe centre" %in% nm && !"ukhsa centre" %in% nm) nm[nm == "phe centre"] <- "ukhsa centre"
  nm
}

classify_metric <- function(x) {
  m <- stringr::str_squish(stringr::str_replace_all(stringr::str_to_lower(x), "[^a-z0-9]+", " "))
  dplyr::case_when(
    stringr::str_detect(m, "^total")                                         ~ "total",
    stringr::str_detect(m, "^hospital.onset healthcare associated")          ~ "HOHA",
    stringr::str_detect(m, "^community.onset healthcare associated")         ~ "COHA",
    stringr::str_detect(m, "^community.onset (indeterminate|intermediate)")  ~ "COIA",
    stringr::str_detect(m, "^community.onset community associated")          ~ "COCA",
    stringr::str_detect(m, "^unknown")                                       ~ "unknown",
    stringr::str_detect(m, "^no information")                                ~ "no_info",
    TRUE                                                                     ~ NA_character_)
}

ORG_TYPES <- c("NHS acute trust", "Sub-ICB", "National")

#' Parse one file. Returns list(data = tidy tibble, layout = one-row tibble).
parse_file <- function(path, file_id) {
  sheets <- list_sheets(path)
  sheet  <- find_data_sheet(path, sheets)
  if (is.na(sheet)) stop("No data sheet in ", basename(path), "; sheets: ", paste(sheets, collapse = ", "), call. = FALSE)
  raw <- read_sheet_raw(path, sheet)
  hdr <- which(apply(raw, 1, is_header_row))[1]
  nm  <- std_names(make.unique(tidyr::replace_na(norm(unlist(raw[hdr, ])), "na")))
  d   <- stats::setNames(raw[-seq_len(hdr), ], nm)

  layout <- tibble::tibble(
    file_id, sheet, all_sheets = paste(sheets, collapse = "; "), header_row = hdr,
    n_rows = nrow(d),
    missing_required = paste(setdiff(REQ_norm, names(d)), collapse = "; "),
    missing_optional = paste(setdiff(OPT_norm, names(d)), collapse = "; "),
    extra_cols       = paste(setdiff(names(d), c(REQ_norm, OPT_norm)), collapse = "; "))
  if (nzchar(layout$missing_required))
    stop("Required column(s) missing in ", file_id, ": ", layout$missing_required, call. = FALSE)

  for (nm_ in setdiff(OPT_norm, names(d))) d[[nm_]] <- NA_character_      # optional columns absent in older files
  tidy <- d |>
    dplyr::rename(dplyr::all_of(c(REQ_norm, OPT_norm))) |>
    dplyr::mutate(
      dplyr::across(c(org_type, org_code, org_name, region, metric, signed_off, changed), ~ stringr::str_squish(as.character(.x))),
      dplyr::across(c(signed_off, changed), ~ dplyr::na_if(.x, "N/A")),
      org_type = dplyr::case_when(stringr::str_detect(stringr::str_to_lower(org_type), "acute")   ~ "NHS acute trust",
                                  stringr::str_detect(stringr::str_to_lower(org_type), "icb|ccg") ~ "Sub-ICB",
                                  TRUE ~ org_type),
      month   = lubridate::make_date(as.integer(year), as.integer(month_num), 1),
      measure = classify_metric(metric),
      count   = suppressWarnings(as.numeric(count)),
      source_file = file_id) |>
    dplyr::select(source_file, month, org_type, org_code, org_name, region, measure, count, signed_off, changed, metric)

  # Fail loudly, with the evidence, rather than guess.
  if (anyNA(tidy$measure)) stop(file_id, ": unmapped metric label(s): ", paste(unique(tidy$metric[is.na(tidy$measure)]), collapse = " | "), call. = FALSE)
  bad_t <- setdiff(unique(tidy$org_type), ORG_TYPES)
  if (length(bad_t)) stop(file_id, ": unexpected organisation type(s): ", paste(bad_t, collapse = " | "), call. = FALSE)
  if (anyNA(tidy$month) || anyNA(tidy$count)) stop(file_id, ": unparsed month or count values", call. = FALSE)
  list(data = dplyr::select(tidy, -metric), layout = layout)
}

# ---- parsed-file cache --------------------------------------------------------------------------
cache_path <- function(cfg, file_id, md5) {
  file.path(ensure_dir(cfg$paths$cache, "parsed"), sprintf("%s__%s__v%s.rds", file_id, substr(md5, 1, 10), cfg$parse$version))
}

parse_and_cache_one <- function(path, file_id, cache) {
  res <- parse_file(path, file_id)
  saveRDS(res, cache, compress = "gzip")
  TRUE
}

#' Parse every downloaded file, using the cache when the file (md5) and parser version are unchanged.
#' Returns list(data, layout). Cache misses are parsed in parallel.
parse_all <- function(log, cfg, workers = 1L, refresh = FALSE) {
  log <- dplyr::filter(log, ok)
  log$cache <- unname(mapply(cache_path, file_id = log$file_id, md5 = log$md5, MoreArgs = list(cfg = cfg)))
  log$hit   <- !refresh & file.exists(log$cache)
  say("parsing: %d cached, %d to parse (%d worker%s)", sum(log$hit), sum(!log$hit), workers, if (workers == 1) "" else "s")

  miss <- which(!log$hit)
  if (length(miss)) {
    # first file sequentially: any parsing problem is reported immediately and clearly
    parse_and_cache_one(log$path[miss[1]], log$file_id[miss[1]], log$cache[miss[1]])
    if (length(miss) > 1)
      parallel_mapply(parse_and_cache_one, log$path[miss[-1]], log$file_id[miss[-1]], log$cache[miss[-1]],
                      workers = workers, source_files = file.path(cfg$root, "R", c("utils.R", "parse.R")))
  }
  res <- lapply(log$cache, readRDS)
  list(data   = dplyr::bind_rows(lapply(res, `[[`, "data")),
       layout = dplyr::bind_rows(lapply(res, `[[`, "layout")))
}
