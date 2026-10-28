# theme.R ---------------------------------------------------------------
# One look for every figure: Okabe-Ito colour-blind-safe palette, quiet grid, left-aligned titles.

PAL <- c(ink = "#1B2A41", blue = "#0072B2", sky = "#56B4E9", green = "#009E73", orange = "#E69F00",
         vermillion = "#D55E00", pink = "#CC79A7", yellow = "#F0E442", grey = "#8A8F98", light = "#D9DCE1")

# Fixed colour per onset category, used identically in every figure
MEASURE_COLOURS <- c(total = PAL[["ink"]], HOHA = PAL[["vermillion"]], COHA = PAL[["orange"]],
                     COIA = PAL[["sky"]], COCA = PAL[["blue"]], other = PAL[["grey"]],
                     unknown = PAL[["grey"]], no_info = PAL[["light"]])

SOURCE_CAPTION <- "Source: UKHSA mandatory HCAI surveillance (accredited official statistics), Open Government Licence v3.0.\nCases are counted by the NHS acute trust whose laboratory processed the specimen; patients aged 2+."

theme_cdiff <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      text               = ggplot2::element_text(colour = PAL[["ink"]]),
      plot.title.position = "plot", plot.caption.position = "plot",
      plot.title         = ggplot2::element_text(face = "bold", size = base_size + 3, margin = ggplot2::margin(b = 4)),
      plot.subtitle      = ggplot2::element_text(colour = "#4A5568", margin = ggplot2::margin(b = 10)),
      plot.caption       = ggplot2::element_text(colour = PAL[["grey"]], size = base_size - 3, hjust = 0, margin = ggplot2::margin(t = 10)),
      panel.grid.minor   = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_line(colour = "#E6E8EC", linewidth = 0.4),
      axis.title         = ggplot2::element_text(colour = "#4A5568", size = base_size - 1),
      axis.text          = ggplot2::element_text(colour = "#4A5568"),
      strip.text         = ggplot2::element_text(face = "bold", hjust = 0),
      legend.position    = "top", legend.justification = "left", legend.title = ggplot2::element_blank(),
      legend.key.height  = ggplot2::unit(0.4, "cm"),
      plot.margin        = ggplot2::margin(12, 14, 8, 12))
}

cdiff_labs <- function(title, subtitle = NULL, x = NULL, y = NULL, caption = SOURCE_CAPTION, wrap = 85) {
  if (!is.null(subtitle)) subtitle <- stringr::str_wrap(subtitle, width = wrap)   # long subtitles wrap instead of being clipped
  ggplot2::labs(title = title, subtitle = subtitle, x = x, y = y, caption = caption)
}

#' Yearly date axis. Pass `data_range` so ticks stop at the data even when the axis is padded for end labels.
scale_x_months <- function(expand = ggplot2::expansion(mult = c(0.01, 0.02)), data_range = NULL, ...) {
  if (is.null(data_range)) return(ggplot2::scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = expand, ...))
  ggplot2::scale_x_date(breaks = seq(lubridate::floor_date(min(data_range), "year"), max(data_range), by = "year"),
                        date_labels = "%Y", expand = expand, ...)
}

#' Shaded COVID-19 disruption window with a small label
covid_layer <- function(cfg, label = TRUE, ymax = Inf) {
  w <- cfg$analysis$covid_window
  l <- list(ggplot2::annotate("rect", xmin = w[1], xmax = w[2], ymin = -Inf, ymax = Inf, fill = PAL[["grey"]], alpha = 0.12))
  if (label) l <- c(l, list(ggplot2::annotate("text", x = w[1] + 15, y = ymax, label = "COVID-19\ndisruption", hjust = 0, vjust = 1.2,
                                              size = 3, colour = PAL[["grey"]], lineheight = 0.9)))
  l
}

save_plot <- function(p, name, cfg, width = cfg$figures$width, height = cfg$figures$height) {
  dir <- ensure_dir(cfg$paths$figures)
  file <- file.path(dir, paste0(name, ".png"))
  dev <- if (requireNamespace("ragg", quietly = TRUE)) ragg::agg_png else "png"
  ggplot2::ggsave(file, p, width = width, height = height, dpi = cfg$figures$dpi, device = dev, bg = "white")
  invisible(file)
}
