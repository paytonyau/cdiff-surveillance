# fetch.R ---------------------------------------------------------------
# Download the files listed in config/sources.csv. Existing, valid files are never
# re-downloaded. Every file is checked to be a real spreadsheet (ODS/XLSX are zip files and
# start with "PK"); an HTML error page saved by mistake is deleted and reported.

read_sources <- function(cfg) {
  src <- readr::read_csv(cfg$paths$sources, show_col_types = FALSE, col_types = readr::cols(.default = "c"))
  req <- c("file_id", "window_start", "window_end", "release_date", "file_type", "url")
  miss <- setdiff(req, names(src))
  if (length(miss)) stop("sources.csv is missing column(s): ", paste(miss, collapse = ", "), call. = FALSE)
  if (anyDuplicated(src$file_id)) stop("sources.csv has duplicated file_id values", call. = FALSE)
  src$release_date <- as.Date(src$release_date)
  src[order(src$release_date, src$window_end), ]
}

is_spreadsheet_zip <- function(path) {
  if (!file.exists(path) || file.size(path) < 1000) return(FALSE)
  identical(readBin(path, "raw", 2), as.raw(c(0x50, 0x4b)))   # "PK"
}

download_one <- function(url, dest, tries = 3L) {
  for (i in seq_len(tries)) {
    ok <- tryCatch({
      suppressWarnings(utils::download.file(url, dest, mode = "wb", quiet = TRUE))
      is_spreadsheet_zip(dest)
    }, error = function(e) FALSE)
    if (ok) return(TRUE)
    if (file.exists(dest)) file.remove(dest)
    Sys.sleep(i^2)                               # 1 s, 4 s, 9 s: be polite to the archive
  }
  FALSE
}

#' Download all files; returns the retrieval log (also written to data/raw/RETRIEVAL_LOG.csv).
#' Files already on disk keep the retrieval date recorded the first time they were fetched.
fetch_sources <- function(sources, cfg, workers = 1L, force = FALSE) {
  raw_dir  <- ensure_dir(cfg$paths$raw)
  log_path <- file.path(raw_dir, "RETRIEVAL_LOG.csv")
  prev <- if (file.exists(log_path))
    readr::read_csv(log_path, show_col_types = FALSE, col_types = readr::cols(.default = "c")) |>
      dplyr::select(file_id, retrieved_prev = retrieved) else
    tibble::tibble(file_id = character(), retrieved_prev = character())

  todo <- sources |>
    dplyr::mutate(path = file.path(raw_dir, paste0(file_id, ".", file_type)),
                  have = vapply(path, is_spreadsheet_zip, logical(1), USE.NAMES = FALSE),
                  need = force | !have)
  say("%d files listed, %d to download", nrow(todo), sum(todo$need))
  if (any(todo$need)) {
    idx <- which(todo$need)
    parallel_mapply(download_one, todo$url[idx], todo$path[idx], workers = min(workers, 4L),   # be polite: max 4 at once
                    source_files = file.path(cfg$root, "R", c("utils.R", "fetch.R")))
  }

  out <- todo |>
    dplyr::mutate(ok = vapply(path, is_spreadsheet_zip, logical(1), USE.NAMES = FALSE),
                  md5 = ifelse(ok, unname(tools::md5sum(path)), NA_character_)) |>
    dplyr::left_join(prev, by = "file_id") |>
    dplyr::mutate(retrieved = dplyr::if_else(!need & !is.na(retrieved_prev), retrieved_prev, as.character(Sys.Date()))) |>
    dplyr::select(file_id, file_type, release_date, window_start, window_end, url, path, ok, md5, retrieved)
  readr::write_csv(dplyr::mutate(out, path = basename(path)), log_path)
  if (any(!out$ok)) warning(sum(!out$ok), " file(s) could not be downloaded: ", paste(out$file_id[!out$ok], collapse = ", "), call. = FALSE)
  out
}
