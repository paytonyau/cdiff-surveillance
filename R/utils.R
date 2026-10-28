# utils.R ---------------------------------------------------------------
# Small helpers shared by every script. Functions only; nothing runs on source().

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

#' Project root: the directory that contains config/params.yml
project_root <- function(start = getwd()) {
  d <- normalizePath(start, mustWork = FALSE)
  repeat {
    if (file.exists(file.path(d, "config", "params.yml"))) return(d)
    parent <- dirname(d)
    if (parent == d) stop("Cannot find config/params.yml above ", start, call. = FALSE)
    d <- parent
  }
}

#' Load config/params.yml and make every path absolute
load_config <- function(root = project_root()) {
  cfg <- yaml::read_yaml(file.path(root, "config", "params.yml"))
  cfg$root <- root
  cfg$paths <- lapply(cfg$paths, function(p) file.path(root, p))
  cfg$analysis$covid_window    <- as.Date(unlist(cfg$analysis$covid_window))
  cfg$analysis$baseline_window <- as.Date(unlist(cfg$analysis$baseline_window))
  cfg$project$series_start     <- as.Date(cfg$project$series_start)
  cfg
}

ensure_dir <- function(...) { p <- file.path(...); dir.create(p, showWarnings = FALSE, recursive = TRUE); p }

say <- function(...) message(format(Sys.time(), "%H:%M:%S"), "  ", sprintf(...))

#' Number of workers: 0 -> cores - 1 (at least 1)
n_workers <- function(requested = 0L) {
  if (requested > 0) return(as.integer(requested))
  max(1L, parallel::detectCores(logical = FALSE) - 1L, na.rm = TRUE)
}

#' mapply() that can run on a PSOCK cluster (works on Windows, macOS and Linux).
#' Each worker sources `source_files` first, so top-level functions are available there.
#' Pass vectors, not closures: `.f` must be a top-level function.
parallel_mapply <- function(.f, ..., workers = 1L, source_files = character()) {
  workers <- as.integer(workers)
  n <- length(..1)
  if (workers > 1L && n > 1L) {
    cl <- parallel::makeCluster(min(workers, n))
    on.exit(parallel::stopCluster(cl), add = TRUE)
    parallel::clusterCall(cl, function(files) { for (f in files) source(f, local = FALSE); invisible(NULL) }, source_files)
    parallel::clusterMap(cl, .f, ..., SIMPLIFY = FALSE, .scheduling = "dynamic")
  } else {
    mapply(.f, ..., SIMPLIFY = FALSE)
  }
}

# Measure metadata: one place that defines names, labels and order everywhere ------
MEASURES <- tibble::tribble(
  ~measure,   ~label,                                  ~group,
  "total",    "All cases",                             "total",
  "HOHA",     "Hospital-onset, healthcare-associated", "hospital",
  "COHA",     "Community-onset, healthcare-associated","community",
  "COIA",     "Community-onset, indeterminate",        "community",
  "COCA",     "Community-onset, community-associated", "community",
  "unknown",  "Unknown",                               "other",
  "no_info",  "No information",                        "other")
COMPONENTS <- c("HOHA", "COHA", "COIA", "COCA", "unknown", "no_info")

measure_label <- function(x) {
  factor(x, levels = MEASURES$measure, labels = MEASURES$label)
}

#' Financial year label for a date (England NHS year runs April to March), e.g. "2023/24"
fin_year <- function(d) {
  y <- lubridate::year(d); m <- lubridate::month(d)
  start <- ifelse(m >= 4, y, y - 1)
  sprintf("%d/%02d", start, (start + 1) %% 100)
}

#' Is a month inside the COVID-19 disruption window?
in_covid <- function(month, cfg) month >= cfg$analysis$covid_window[1] & month <= cfg$analysis$covid_window[2]
