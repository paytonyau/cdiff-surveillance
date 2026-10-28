# plots.R ---------------------------------------------------------------
# Every function takes already-computed data and returns a ggplot. No file I/O (see save_plot()).

short_trust <- function(x) {
  x <- stringr::str_to_title(x)
  x <- stringr::str_replace_all(x, "\\bNhs\\b", "NHS")
  x <- stringr::str_remove_all(x, "(?i)\\s*(NHS )?(Foundation )?Trust$")
  x <- stringr::str_remove_all(x, "(?i)\\s*(NHS )?Foundation$")
  stringr::str_trunc(stringr::str_squish(x), 34)
}

# 1. Headline: monthly counts + trailing mean --------------------------------------------------------------
plot_overview <- function(national, cfg, which_measure = "total") {
  d <- dplyr::filter(national, measure == which_measure)
  ymax <- max(d$count) * 1.02
  ggplot2::ggplot(d, ggplot2::aes(month)) +
    covid_layer(cfg, ymax = ymax) +
    ggplot2::geom_col(ggplot2::aes(y = count, fill = provisional), width = 26, show.legend = FALSE) +
    ggplot2::geom_line(ggplot2::aes(y = ma), colour = PAL[["ink"]], linewidth = 1.1, na.rm = TRUE) +
    ggplot2::scale_fill_manual(values = c(`FALSE` = PAL[["sky"]], `TRUE` = "#BFE3F7")) +
    scale_x_months() +
    ggplot2::scale_y_continuous(labels = scales::label_comma(), expand = ggplot2::expansion(mult = c(0, 0.08))) +
    cdiff_labs("Monthly C. difficile infections in England",
               sprintf("Bars: monthly cases. Line: trailing %d-month mean. Pale bars: latest three months, provisional.", cfg$analysis$ma_window),
               y = "Cases per month") +
    theme_cdiff()
}

# 2. Composition by onset category -----------------------------------------------------------------------
plot_composition_counts <- function(comp, cfg) {
  d <- comp |> dplyr::mutate(measure = factor(measure, levels = c("other", "COCA", "COIA", "COHA", "HOHA")))
  ggplot2::ggplot(d, ggplot2::aes(month, count, fill = measure)) +
    ggplot2::geom_col(width = 26) +
    ggplot2::scale_fill_manual(values = MEASURE_COLOURS, breaks = c("HOHA", "COHA", "COIA", "COCA", "other"),
                               labels = c("Hospital-onset, healthcare-assoc.", "Community-onset, healthcare-assoc.",
                                          "Community-onset, indeterminate", "Community-onset, community-assoc.", "Unknown / no info")) +
    scale_x_months() +
    ggplot2::scale_y_continuous(labels = scales::label_comma(), expand = ggplot2::expansion(mult = c(0, 0.05))) +
    cdiff_labs("Where do infections start? Cases by onset category", "Stacked monthly counts.", y = "Cases per month") +
    ggplot2::guides(fill = ggplot2::guide_legend(nrow = 2)) + theme_cdiff()
}

plot_composition_share <- function(comp, cfg) {
  d <- comp |> dplyr::filter(measure != "other")
  ends <- d |> dplyr::group_by(measure) |> dplyr::slice_max(month, n = 1) |> dplyr::ungroup()
  ggplot2::ggplot(d, ggplot2::aes(month, share_ma, colour = measure)) +
    covid_layer(cfg, label = FALSE) +
    ggplot2::geom_line(linewidth = 1.1, na.rm = TRUE) +
    ggrepel::geom_text_repel(data = ends, ggplot2::aes(y = share_ma, label = measure), hjust = 0, nudge_x = 40, direction = "y",
                             segment.colour = NA, size = 3.4, fontface = "bold", show.legend = FALSE, na.rm = TRUE) +
    ggplot2::scale_colour_manual(values = MEASURE_COLOURS, guide = "none") +
    scale_x_months(expand = ggplot2::expansion(mult = c(0.01, 0.08)), data_range = d$month) +
    ggplot2::scale_y_continuous(labels = scales::label_percent(scale = 1), limits = c(0, NA)) +
    cdiff_labs("Share of cases by onset category", sprintf("Share of all cases, trailing %d-month mean.", cfg$analysis$ma_window), y = "Share of all cases") +
    theme_cdiff()
}

# 3. Seasonality ---------------------------------------------------------------------------------------
plot_seasonal_heatmap <- function(si) {
  d <- si$matrix |> dplyr::mutate(year_f = factor(year, levels = rev(sort(unique(year)))))
  ggplot2::ggplot(d, ggplot2::aes(mon, year_f, fill = index)) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.6) +
    ggplot2::geom_text(ggplot2::aes(label = round(index), colour = abs(index - 100) > 9), size = 3, fontface = "bold", show.legend = FALSE) +
    ggplot2::scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = PAL[["ink"]])) +
    ggplot2::scale_fill_gradient2(low = PAL[["blue"]], mid = "#F4F1EA", high = PAL[["vermillion"]], midpoint = 100, name = "Index") +
    cdiff_labs("Seasonality: which months run high?", "Index: monthly cases relative to that year's average (100). Complete years only.") +
    theme_cdiff() + ggplot2::theme(panel.grid = ggplot2::element_blank(), legend.position = "right")
}

plot_stl <- function(stl) {
  long <- stl |>
    tidyr::pivot_longer(c(observed, trend, seasonal_pct, remainder_pct), names_to = "component", values_to = "value") |>
    dplyr::mutate(component = factor(component, levels = c("observed", "trend", "seasonal_pct", "remainder_pct"),
                                     labels = c("Observed (cases)", "Trend (cases)", "Seasonal effect (%)", "Remainder (%)")))
  ggplot2::ggplot(long, ggplot2::aes(month, value)) +
    ggplot2::geom_hline(data = dplyr::tibble(component = factor(c("Seasonal effect (%)", "Remainder (%)")), y = 0), ggplot2::aes(yintercept = y),
                        colour = PAL[["light"]]) +
    ggplot2::geom_line(colour = PAL[["blue"]], linewidth = 0.9) +
    ggplot2::facet_wrap(~component, ncol = 1, scales = "free_y") +
    scale_x_months() +
    cdiff_labs("Trend, seasonal and irregular components", "Robust STL decomposition of log monthly counts.") +
    theme_cdiff()
}

# 4. Regions / trusts relative to their own pre-COVID baseline ------------------------------------------------
plot_region_index <- function(idx, cfg) {
  if (nrow(idx) == 0) return(ggplot2::ggplot() + ggplot2::labs(title = "No regional data available") + theme_cdiff())
  ends <- idx |> dplyr::group_by(region) |> dplyr::slice_max(month, n = 1, with_ties = FALSE) |> dplyr::ungroup()
  ggplot2::ggplot(idx, ggplot2::aes(month, index_ma, colour = region)) +
    covid_layer(cfg, label = FALSE) +
    ggplot2::geom_hline(yintercept = 100, colour = PAL[["grey"]], linetype = 2) +
    ggplot2::geom_line(linewidth = 1, na.rm = TRUE) +
    ggrepel::geom_text_repel(data = ends, ggplot2::aes(label = region), hjust = 0, nudge_x = 40, direction = "y", size = 3.1,
                             segment.colour = NA, show.legend = FALSE, na.rm = TRUE) +
    ggplot2::scale_colour_manual(values = grDevices::colorRampPalette(unname(PAL[c("blue", "vermillion", "green", "orange", "pink", "sky", "ink")]))(dplyr::n_distinct(idx$region)), guide = "none") +
    scale_x_months(expand = ggplot2::expansion(mult = c(0.01, 0.22)), data_range = idx$month) +
    cdiff_labs("Regional trends relative to each region's own pre-COVID baseline",
               sprintf("Index, 100 = mean monthly cases %s to %s. Trailing %d-month mean. Compares each region with itself, so no population denominator is needed.",
                       format(cfg$analysis$baseline_window[1], "%b %Y"), format(cfg$analysis$baseline_window[2], "%b %Y"), cfg$analysis$ma_window),
               y = "Index (baseline = 100)") + theme_cdiff()
}

plot_trust_index <- function(ti, cfg, n_show = 30) {
  if (nrow(ti) == 0) return(ggplot2::ggplot() + ggplot2::labs(title = "No trusts meet the baseline criteria") + theme_cdiff())
  d <- ti |> dplyr::mutate(name = short_trust(org_name %||% org_code), changed = dplyr::case_when(lo > 1 ~ "higher", hi < 1 ~ "lower", TRUE ~ "no clear change"))
  d <- dplyr::bind_rows(utils::head(d, ceiling(n_show / 2)), utils::tail(d, floor(n_show / 2))) |> dplyr::distinct(org_code, .keep_all = TRUE)
  ggplot2::ggplot(d, ggplot2::aes(rr, stats::reorder(name, rr), colour = changed)) +
    ggplot2::geom_vline(xintercept = 1, colour = PAL[["grey"]], linetype = 2) +
    ggplot2::geom_linerange(ggplot2::aes(xmin = lo, xmax = hi), linewidth = 0.6, orientation = "y") +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_colour_manual(values = c(higher = PAL[["vermillion"]], lower = PAL[["blue"]], `no clear change` = PAL[["grey"]])) +
    ggplot2::scale_x_log10(breaks = c(0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4), labels = function(x) paste0(x, "x")) +
    cdiff_labs("Which trusts differ most from their own pre-COVID baseline?", wrap = 105,
               subtitle =
               "Rate ratio of cases per month, last 12 months vs baseline, with exact 95% Poisson intervals. Largest increases and decreases shown. Bed-days are not available, so this compares a trust with itself, never with other trusts.",
               x = "Rate ratio (log scale)") +
    theme_cdiff() + ggplot2::theme(panel.grid.major.y = ggplot2::element_blank(), plot.subtitle = ggplot2::element_text(size = 9))
}

plot_trust_small_multiples <- function(clean, lookup, cfg, n = 20, which_measure = "total", last_n = 12) {
  x <- clean |> dplyr::filter(org_type == cfg$analysis$org_type, measure == which_measure, month >= cfg$project$series_start)
  top <- x |> dplyr::filter(month %in% utils::tail(sort(unique(x$month)), last_n)) |>
    dplyr::group_by(org_code) |> dplyr::summarise(cases = sum(count), .groups = "drop") |> dplyr::slice_max(cases, n = n, with_ties = FALSE)
  order <- with_org(top, lookup) |> dplyr::mutate(name = short_trust(org_name))
  d <- x |> dplyr::semi_join(top, by = "org_code") |> with_org(lookup) |>
    dplyr::mutate(name = factor(short_trust(org_name), levels = unique(order$name)))
  ggplot2::ggplot(d, ggplot2::aes(month, count)) +
    covid_layer(cfg, label = FALSE) +
    ggplot2::geom_area(fill = PAL[["sky"]], alpha = 0.35) + ggplot2::geom_line(colour = PAL[["blue"]], linewidth = 0.5) +
    ggplot2::facet_wrap(~name, ncol = 4, scales = "free_y") +
    ggplot2::scale_x_date(date_breaks = "2 years", date_labels = "'%y") +
    cdiff_labs(sprintf("The %d trusts with the most cases in the last %d months", n, last_n),
               "Monthly cases, each panel on its own scale. Counts reflect trust size and case-mix, so panels show each trust's own trajectory, not a league table.",
               y = NULL) +
    theme_cdiff(base_size = 9) + ggplot2::theme(axis.text.y = ggplot2::element_text(size = 7))
}

# 5. Exceedance -------------------------------------------------------------------------------------------
plot_exceedance <- function(res, cfg) {
  flags <- res |>
    dplyr::select(month, count, flag_naive, flag_ears, flag_nb) |>
    tidyr::pivot_longer(dplyr::starts_with("flag_"), names_to = "method", values_to = "flag") |>
    dplyr::filter(flag) |>
    dplyr::mutate(method = factor(method, levels = c("flag_naive", "flag_ears", "flag_nb"),
                                  labels = c("Naive: mean + 2 SD", "EARS C2", "Rolling negative binomial")))
  ymax <- max(res$count) * 1.02
  ggplot2::ggplot(res, ggplot2::aes(month)) +
    covid_layer(cfg, ymax = ymax) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = 0, ymax = upper_nb), fill = PAL[["sky"]], alpha = 0.15, na.rm = TRUE) +
    ggplot2::geom_line(ggplot2::aes(y = upper_nb, linetype = "NB 97.5% limit"), colour = PAL[["blue"]], na.rm = TRUE) +
    ggplot2::geom_line(ggplot2::aes(y = count), colour = PAL[["ink"]], linewidth = 0.9) +
    ggplot2::geom_point(data = flags, ggplot2::aes(y = count, colour = method, shape = method), size = 3.2, stroke = 1) +
    ggplot2::scale_colour_manual(values = c("Naive: mean + 2 SD" = PAL[["orange"]], "EARS C2" = PAL[["green"]], "Rolling negative binomial" = PAL[["vermillion"]])) +
    ggplot2::scale_shape_manual(values = c(1, 2, 16)) +
    ggplot2::scale_linetype_manual(values = c("NB 97.5% limit" = 2)) +
    scale_x_months() + ggplot2::scale_y_continuous(labels = scales::label_comma(), limits = c(0, NA)) +
    cdiff_labs("Which months exceed what a simple baseline predicts?",
               "Black line: observed cases. Shaded: negative binomial prediction up to its upper limit. Markers: months flagged by each method. Flags are prompts to look, not outbreak declarations.",
               y = "Cases per month", wrap = 105) +
    theme_cdiff() + ggplot2::theme(plot.subtitle = ggplot2::element_text(size = 9))
}

# 6. Distribution and concentration ---------------------------------------------------------------------------
plot_trust_distribution <- function(dist) {
  ggplot2::ggplot(dist$data, ggplot2::aes(count)) +
    ggplot2::geom_histogram(binwidth = 1, fill = PAL[["blue"]], colour = "white", boundary = 0) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.01, 0.02))) +
    ggplot2::scale_y_continuous(labels = scales::label_comma(), expand = ggplot2::expansion(mult = c(0, 0.05))) +
    cdiff_labs("Distribution of cases per trust per month",
               sprintf("Trust-months over the last 12 months. Mean %.1f, variance %.1f: variance/mean = %.1f (a Poisson process would give 1), so counts vary more than chance alone would explain.",
                       dist$mean, dist$var, dist$dispersion),
               x = "Cases in a trust in a month", y = "Trust-months") + theme_cdiff()
}

plot_concentration <- function(conc) {
  d <- dplyr::bind_rows(tibble::tibble(trust_share = 0, cum_share = 0), conc$per_trust)
  ggplot2::ggplot(d, ggplot2::aes(trust_share, cum_share)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, colour = PAL[["grey"]], linetype = 2) +
    ggplot2::geom_area(fill = PAL[["sky"]], alpha = 0.3) + ggplot2::geom_line(colour = PAL[["blue"]], linewidth = 1.1) +
    ggplot2::scale_x_continuous(labels = scales::label_percent(), expand = c(0, 0)) +
    ggplot2::scale_y_continuous(labels = scales::label_percent(), expand = c(0, 0)) +
    ggplot2::coord_equal() +
    cdiff_labs("How concentrated are cases across trusts?",
               sprintf("Trusts ordered from fewest to most cases (last 12 months). The busiest 10%% of trusts account for %.0f%% of cases (Gini %.2f). Large trusts naturally see more cases.", conc$top10_share, conc$gini),
               x = "Cumulative share of trusts", y = "Cumulative share of cases") + theme_cdiff()
}

plot_coverage <- function(cov, changes = NULL) {
  g <- ggplot2::ggplot(cov, ggplot2::aes(month, n_trusts)) +
    ggplot2::geom_step(colour = PAL[["blue"]], linewidth = 1) +
    scale_x_months() + ggplot2::scale_y_continuous(limits = c(0, NA))
  if (!is.null(changes) && nrow(changes)) {
    ch <- changes |> dplyr::mutate(date = as.Date(date), label = paste0(absorbed_code, " into ", surviving_code)) |>
      dplyr::filter(date >= min(cov$month), date <= max(cov$month))
    g <- g + ggplot2::geom_vline(data = ch, ggplot2::aes(xintercept = date), colour = PAL[["vermillion"]], linetype = 2) +
      ggplot2::geom_text(data = ch, ggplot2::aes(x = date, y = 0, label = label), angle = 90, hjust = -0.1, vjust = -0.5, size = 3, colour = PAL[["vermillion"]])
  }
  g + cdiff_labs("Trusts reporting each month",
                 "Dashed lines: documented mergers (UKHSA Cover sheet). A changing set of trusts is one reason trust-level trends need care.",
                 y = "Trusts") + theme_cdiff()
}

# 7. Data quality: revisions ----------------------------------------------------------------------------------
plot_revision_lag <- function(rev) {
  d <- rev$by_lag |> dplyr::filter(lag >= 0, n >= 20)
  p1 <- ggplot2::ggplot(d, ggplot2::aes(lag, share_revised)) +
    ggplot2::geom_col(fill = PAL[["orange"]], width = 0.7) +
    ggplot2::scale_x_continuous(breaks = scales::breaks_width(1)) +
    ggplot2::scale_y_continuous(labels = scales::label_percent(scale = 1), expand = ggplot2::expansion(mult = c(0, 0.08))) +
    ggplot2::labs(subtitle = "Share of trust-month counts that later changed", x = "Months between data month and release", y = NULL) + theme_cdiff()
  p2 <- ggplot2::ggplot(d, ggplot2::aes(lag, net_pct)) +
    ggplot2::geom_hline(yintercept = 0, colour = PAL[["grey"]]) +
    ggplot2::geom_col(fill = PAL[["blue"]], width = 0.7) +
    ggplot2::scale_x_continuous(breaks = scales::breaks_width(1)) +
    ggplot2::scale_y_continuous(labels = scales::label_percent(scale = 1, accuracy = 0.1)) +
    ggplot2::labs(subtitle = "Net difference from the final published value (national)", x = "Months between data month and release", y = NULL) + theme_cdiff()
  patchwork::wrap_plots(p1, p2, ncol = 2) +
    patchwork::plot_annotation(title = "How much do published counts change after release?",
                               caption = SOURCE_CAPTION, theme = ggplot2::theme(plot.title = ggplot2::element_text(face = "bold", size = 14),
                                                                                 plot.caption = ggplot2::element_text(colour = PAL[["grey"]], size = 8, hjust = 0)))
}

plot_revision_national <- function(rev, cfg) {
  d <- rev$national
  ggplot2::ggplot(d, ggplot2::aes(month, diff_pct)) +
    ggplot2::geom_hline(yintercept = 0, colour = PAL[["grey"]]) +
    ggplot2::geom_col(ggplot2::aes(fill = diff_pct > 0), width = 26, show.legend = FALSE) +
    ggplot2::scale_fill_manual(values = c(`TRUE` = PAL[["vermillion"]], `FALSE` = PAL[["blue"]])) +
    scale_x_months() + ggplot2::scale_y_continuous(labels = scales::label_percent(scale = 1, accuracy = 0.1)) +
    cdiff_labs("First published value vs final value, by data month",
               "Positive: the first release over-stated the final count. Negative: later revisions added cases.", y = "First release vs final (%)") + theme_cdiff()
}
