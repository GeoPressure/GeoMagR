utils::globalVariables(c(".data"))

#' Interactive Visualization of Magnetic and Acceleration Data
#'
#' @description
#' Provides interactive 3D and 2D plots for exploring [GeoPressureR tag object
#' ](https://geopressure.org/GeoPressureR/reference/tag_create.html) sensor data, including
#' raw and calibrated magnetic data, fitted calibration ellipsoids, and (projected) acceleration
#' data. Color-coding by stationary period or movement state is supported. Time series plots can
#' optionally overlay a reference path, and histogram plots compare errors against a reference
#' path.
#'
#' Plot types:
#' \itemize{
#'   \item \strong{"magnetic"}: Raw magnetic data in sensor frame, colored by stationary period.
#'   \item \strong{"magnetic_c"}: Calibrated magnetic data in sensor frame, colored by stationary period.
#'   \item \strong{"magnetic_cp"}: Calibrated magnetic data projected in the Earth frame, colored by stationary period.
#'   \item \strong{"magnetic_calib"}: Calibration points and fitted ellipsoids for selected periods.
#'   \item \strong{"calib"}: Alias of \code{"magnetic_calib"} (kept for backward compatibility).
#'   \item \strong{"acceleration"}: Raw acceleration, colored by static/moving classification.
#'   \item \strong{"acceleration_p"}: Projected acceleration (NED frame), with reference gravity.
#'   \item \strong{"timeseries"}: Time series of inclination and intensity, with optional reference
#'    path overlay.
#'   \item \strong{"histogram"}: Histogram of errors (sample and mean per stationary period)
#'   against reference path.
#' }
#'
#' @param tag A [GeoPressureR tag object
#' ](https://geopressure.org/GeoPressureR/reference/tag_create.html) containing magnetic (and
#'  optionally calibration) data.
#' @param type Character, plot type. One of "magnetic", "magnetic_c", "magnetic_cp",
#'  "magnetic_calib" (or alias "calib"), "acceleration", "acceleration_p", "timeseries",
#'  or "histogram".
#' @param stap_id Integer or vector, stationary period(s) to plot calibration fit for
#' (type="magnetic_calib" or "calib").
#' @param path Optional for `"timeseries"` and required for `"histogram"`. A data frame with
#'   columns `start`, `end`, `stap_id`, `lon`, `lat` for plotting reference paths.
#' @param static_thr_hard Numeric. Hard threshold around 1 g used when classifying static
#'   samples in `"acceleration"` plots. Passed to [tag_static()].
#' @param static_thr_outlier Numeric. MAD threshold used to remove outliers among candidate static
#'   samples. Passed to [tag_static()].
#'
#' @return A `plotly::plot_ly()` object for magnetic, calibration, and acceleration plots; a
#' `plotly::ggplotly()` object for timeseries plots; or a `ggplot2` object for histogram plots.
#'
#' @details
#' - Uses the `scico` or `viridisLite` palettes for clear color separation.
#' - For magnetic plots, "magnetic_c" and "magnetic_cp" require calibrated data from [geomag_calib()].
#' - For type "magnetic_calib" (or alias "calib"), if `stap_id` is missing, periods with
#'   min/max radii are shown.
#' - If `stap_id` is missing in `tag$magnetic` and/or `tag$mag_calib`, a fallback grouping is
#'   created automatically so plots still render.
#' - For acceleration plots, static/moving state is estimated if not present.
#' - For histogram plots, a reference path is required for error analysis.
#' - For timeseries plots, a reference path is optional and only used for overlaying reference
#'   segments.
#'
#' @examples
#' library(GeoPressureR)
#' withr::with_dir(system.file("extdata", package = "GeoMagR"), {
#'   tag <- tag_create("14DM", quiet = TRUE)
#'   tag <- tag_label(tag, quiet = TRUE)
#'   tag <- geomag_calib(tag, quiet = TRUE)
#' })
#' plot_mag(tag, type = "acceleration")
#' plot_mag(tag, type = "magnetic")
#' plot_mag(tag, type = "calib")
#' @export
plot_mag <- function(
  tag,
  type = "magnetic",
  stap_id = NULL,
  path = NULL,
  static_thr_hard = NULL,
  static_thr_outlier = NULL
) {
  tag <- plot_mag_normalize_stap_id(tag)
  cols <- get_stap_palette(tag)

  p <- switch(
    type,
    magnetic = plot_mag_magnetic(
      tag,
      cols,
      mag_origin = "data",
      variant = "raw",
      stap_id = stap_id
    ),
    magnetic_c = plot_mag_magnetic(
      tag,
      cols,
      mag_origin = "data",
      variant = "corr",
      stap_id = stap_id
    ),
    magnetic_cp = plot_mag_magnetic(
      tag,
      cols,
      mag_origin = "data",
      variant = "corr_proj",
      stap_id = stap_id
    ),
    magnetic_calib = plot_mag_magnetic(
      tag,
      cols,
      mag_origin = "calib",
      variant = "raw",
      stap_id = stap_id
    ),
    calib = plot_mag_magnetic(
      tag,
      cols,
      mag_origin = "calib",
      variant = "raw",
      stap_id = stap_id
    ),
    acceleration = plot_mag_acceleration(
      tag,
      static_thr_hard,
      static_thr_outlier,
      "acceleration"
    ),
    acceleration_p = plot_mag_acceleration(
      tag,
      static_thr_hard,
      static_thr_outlier,
      "acceleration_p"
    ),
    timeseries = plot_mag_timeseries(tag, cols, stap_id, path),
    histogram = plot_mag_histogram(tag, cols, stap_id, path),
    cli::cli_abort(c(
      x = "Unknown plot type.",
      ">" = "Use one of {.val magnetic}, {.val magnetic_c}, {.val magnetic_cp}, {.val magnetic_calib}, {.val calib}, {.val acceleration}, {.val acceleration_p}, {.val timeseries}, or {.val histogram}."
    ))
  )
  p
}

# ---- Utility functions for plot_mag ----
plot_mag_normalize_stap_id <- function(tag) {
  if (is.null(tag$magnetic) || nrow(tag$magnetic) == 0) {
    cli::cli_abort("No magnetic data found in {.var tag}.")
  }
  tag$magnetic <- plot_mag_add_stap_id(tag$magnetic)
  tag$mag_calib <- plot_mag_add_stap_id(tag$mag_calib, ref = tag$magnetic)

  all_stap_id <- sort(unique(c(
    tag$magnetic$stap_id,
    if (!is.null(tag$mag_calib)) tag$mag_calib$stap_id else NULL
  )))
  if (length(all_stap_id) == 0 || all(is.na(all_stap_id))) {
    all_stap_id <- 1L
  }
  all_stap_id <- as.integer(round(all_stap_id))

  if (is.null(tag$stap) || !"stap_id" %in% names(tag$stap)) {
    tag$stap <- data.frame(stap_id = all_stap_id)
  }
  tag
}

plot_mag_add_stap_id <- function(df, ref = NULL) {
  if (is.null(df) || nrow(df) == 0) {
    return(df)
  }
  if ("stap_id" %in% names(df)) {
    return(df)
  }

  if (
    !is.null(ref) &&
      "stap_id" %in% names(ref) &&
      "date" %in% names(df) &&
      "date" %in% names(ref)
  ) {
    id <- ref$stap_id[match(df$date, ref$date)]
    id <- as.integer(round(id))
    if (all(is.na(id))) {
      id <- rep(1L, nrow(df))
    } else if (anyNA(id)) {
      id[is.na(id)] <- stats::median(id, na.rm = TRUE)
    }
    df$stap_id <- id
  } else {
    df$stap_id <- rep(1L, nrow(df))
  }
  df
}

# Generate color palette for stap_id
get_stap_palette <- function(tag) {
  max_stap_id <- max(
    c(
      tag$magnetic$stap_id,
      if (!is.null(tag$mag_calib)) tag$mag_calib$stap_id else 1L,
      if ("geomag_calib" %in% names(tag$param)) {
        length(tag$param$geomag_calib$radius_amplitude)
      } else {
        1L
      }
    ),
    na.rm = TRUE
  )
  n <- max(1L, as.integer(max_stap_id))

  cols <- scico::scico(n, palette = "romaO")
  n2 <- length(cols) %/% 2
  cols <- c(cols[(n2 + 1):length(cols)], cols[1:n2])
  stats::setNames(cols, seq_len(n))
}

# Add ellipsoid mesh overlay to a plotly object
add_ellipsoid_mesh <- function(
  p,
  radius = c(1, 1, 1),
  offset = c(0, 0, 0),
  rotM = diag(3),
  color = "lightblue"
) {
  # Mesh grid for ellipsoid overlays
  phi <- seq(0, 360, length.out = 100) / 180 * pi
  theta <- seq(-90, 90, length.out = 100) / 180 * pi
  x <- c(sin(phi) %*% t(cos(theta)))
  y <- c(sin(phi) %*% t(sin(theta)))
  z <- c(cos(phi) %*% t(rep(1, length(theta))))
  xyz <- cbind(x, y, z)
  xyz <- sweep(xyz, 2, radius, "*")
  xyz <- xyz %*% t(rotM)
  xyz <- sweep(xyz, 2, offset, "+")

  suppressWarnings(
    p |>
      plotly::add_mesh(
        x = xyz[, 1],
        y = xyz[, 2],
        z = xyz[, 3],
        alphahull = 0,
        opacity = 0.2,
        showscale = FALSE,
        intensity = rep(1, length(x)),
        colorscale = list(c(0, 1), c(color, color)),
        color = I(color),
        showlegend = FALSE
      )
  )
}
# Helper for 3D scatter plot
add_3d_scatter <- function(
  p,
  data,
  xcol,
  ycol,
  zcol,
  colorcol,
  colors,
  ...
) {
  data <- data[stats::complete.cases(data[, c(xcol, ycol, zcol, colorcol)]), ]
  if (nrow(data) == 0) {
    return(p)
  }
  suppressWarnings(
    p |>
      plotly::add_markers(
        data = data,
        x = data[[xcol]],
        y = data[[ycol]],
        z = data[[zcol]],
        color = data[[colorcol]],
        colors = colors,
        text = data[[colorcol]],
        ...
      )
  )
}
