#' Calibrate Magnetic and Acceleration Data for 3-Axis Sensors
#'
#' @description
#' Performs tilt compensation and magnetic calibration for 3-axis sensor data, with support for
#' field-data and in vitro calibration routines, outlier removal, and computation of orientation and
#' field parameters. This function is designed for use with `GeoPressureR` tag objects and can
#' utilize calibration datasets if available.
#'
#' ## Workflow
#'
#' 1. **Magnetic Data Calibration:**
#'    - Select calibration data source (raw or from calibration dataset).
#'    - Optionally remove extreme or outlier values.
#'    - Fit and apply a calibration model (sphere/ellipse or their stap variants).
#' 2. **Tilt Compensation:**
#'    - Compute pitch and roll from acceleration.
#'    - Project acceleration and calibrated magnetic data into the horizontal plane of the Earth frame.
#' 3. **Orientation and Field Parameters:**
#'    - Calculate heading, field intensity, and inclination.
#'    - Store calibration metadata and processed data in the tag object.
#'
#' @param tag A `GeoPressureR` tag object containing magnetic and acceleration data.
#' @param calib_data Logical, character, or `NULL`.
#'        If `TRUE`, uses calibration data from `magCalib/` subfolder.
#'        If `FALSE`, calibrates using field-data calibration.
#'        If a character path, uses calibration data from the specified directory.
#'        If `NULL`, auto-detects calibration folder.
#' @param calib_method Character. Calibration method, one of `"sphere"`, `"ellipse"`,
#'        `"near-sphere"`, `"sphere_stap"`, or `"ellipse_stap"`. If `NULL`, chosen automatically.
#' @param rm_outlier Logical. If `TRUE`, removes outliers from calibration data (recommended).
#' @param static_thr_hard Numeric. Hard threshold around 1 g used when classifying static
#'   samples. Passed to [tag_static()].
#' @param static_thr_outlier Numeric. MAD threshold used to remove outliers among candidate static
#'   samples. Passed to [tag_static()].
#' @param quiet Logical. If `TRUE`, suppresses progress messages.
#'
#' @return Modified `GeoPressureR` tag object. The `$magnetic` data frame contains:
#'   - `date`: Timestamp (POSIXct or numeric)
#'   - `acceleration_x`, `acceleration_y`, `acceleration_z`: Raw acceleration data
#'   - `magnetic_x`, `magnetic_y`, `magnetic_z`: Raw magnetic data
#'   - `is_static`: Scaled MAD of acceleration (0 = static, >1 = movement)
#'   - `pitch`, `roll`: Orientation angles (radian)
#'   - `acceleration_xp`, `acceleration_yp`, `acceleration_zp`: Projected acceleration in NED
#'     frame
#'   - `magnetic_xc`, `magnetic_yc`, `magnetic_zc`: Calibrated magnetic data
#'   - `magnetic_xcp`, `magnetic_ycp`, `magnetic_zcp`: Calibrated magnetic data projected in NED
#'   frame
#'   - `H`: Magnetic heading / yaw (degrees). Computed from the calibrated magnetic axes after
#'     tilt compensation. 0 = North, 90 = East, 180 = South, 270 = West. Range [0, 360).
#'   - `F`: Magnetic field intensity (Gauss)
#'   - `I`: Inclination (radian)
#' Also returns (invisibly) the calibration dataset used (`tag$mag_calib`) and calibration
#' parameters (`tag$param$geomag_calib`).
#'
#' @examples
#' library(GeoPressureR)
#' withr::with_dir(system.file("extdata", package = "GeoMagR"), {
#'   tag <- tag_create("14DM", quiet = TRUE)
#'   tag <- tag_label(tag, quiet = TRUE)
#'   tag <- geomag_calib(tag, quiet = TRUE)
#'   tag$param$geomag_calib
#'   head(tag$magnetic)
#' })
#' @export
geomag_calib <- function(
  tag,
  calib_data = NULL,
  calib_method = NULL,
  rm_outlier = TRUE,
  static_thr_hard = 0.1,
  static_thr_outlier = 3,
  quiet = FALSE
) {
  GeoPressureR::tag_assert(tag, "magnetic")

  tag <- tag_static(
    tag,
    static_thr_hard = static_thr_hard,
    static_thr_outlier = static_thr_outlier
  )
  mag <- tag$magnetic

  # Select calibration data source
  if (is.null(calib_data)) {
    directory <- glue::glue("{tag$param$tag_create$directory}/magCalib")
    if (dir.exists(directory)) {
      calib_data <- TRUE
    } else {
      calib_data <- FALSE
    }
  } else if (is.character(calib_data) && dir.exists(calib_data)) {
    directory <- calib_data
    calib_data <- TRUE
  } else if (isTRUE(calib_data)) {
    directory <- glue::glue("{tag$param$tag_create$directory}/magCalib")
  }

  # Load calibration dataset when available, otherwise fallback to field data
  if (isTRUE(calib_data)) {
    tag_calib <- GeoPressureR::tag_create(
      "",
      manufacturer = "soi",
      directory = directory,
      assert_pressure = FALSE,
      quiet = quiet
    )
    assertthat::assert_that(
      !is.null(tag_calib$magnetic),
      msg = "No magnetic data found in the calibration data."
    )
    tag_calib <- tag_static(
      tag_calib,
      static_thr_hard = static_thr_hard,
      static_thr_outlier = static_thr_outlier
    )
    mag_calib <- tag_calib$magnetic
  } else if (is.data.frame(calib_data)) {
    mag_calib <- calib_data
    cli::cli_alert_info("Using provided data.frame {.arg calib_data}")
  } else {
    mag_calib <- mag[,
      intersect(
        c("date", "magnetic_x", "magnetic_y", "magnetic_z", "stap_id"),
        names(mag)
      )
    ]
    cli::cli_alert_info("Using raw magnetic data for calibration data")
  }

  # Filter calibration samples
  if (rm_outlier) {
    mag_calib <- geomag_calib_rm(mag_calib, tag)
  }
  mag_calib <- mag_calib[
    stats::complete.cases(
      mag_calib[, c("magnetic_x", "magnetic_y", "magnetic_z")]
    ),
  ]

  # Choose calibration model
  if (is.null(calib_method)) {
    has_known_stap <- "stap_id" %in%
      names(mag_calib) &&
      !is.null(tag$stap) &&
      "known_lat" %in% names(tag$stap) &&
      !all(is.na(tag$stap$known_lat))
    if (has_known_stap) {
      calib_method <- "ellipse_stap"
    } else {
      calib_method <- "ellipse"
    }
  }
  if (grepl("_stap$", calib_method) && !"stap_id" %in% names(mag_calib)) {
    cli::cli_abort(c(
      "x" = "{.arg calib_method} {.val {calib_method}} requires {.field stap_id} in magnetic data.",
      ">" = "Use a non-stap method (e.g. {.val ellipse}) or provide magnetic data with {.field stap_id}."
    ))
  }

  # Fit calibration and transform magnetic axes
  mag <- geomag_calib_fit(
    mag = mag,
    mag_calib = mag_calib,
    method = calib_method,
    stap = tag$stap
  )

  # Compute orientation from acceleration
  gn <- sqrt(mag$acceleration_x^2 + mag$acceleration_y^2 + mag$acceleration_z^2)

  mag$pitch <- asin(-mag$acceleration_x / gn)
  mag$roll <- atan2(mag$acceleration_y / gn, mag$acceleration_z / gn)

  # Rotate acceleration and magnetic vectors into Earth frame
  gr <- geomag_calib_rotate(
    matrix(
      c(mag$acceleration_x, mag$acceleration_y, mag$acceleration_z),
      nrow(mag),
      3
    ),
    roll = mag$roll,
    pitch = mag$pitch
  )
  mag$acceleration_xp <- gr[, 1]
  mag$acceleration_yp <- gr[, 2]
  mag$acceleration_zp <- gr[, 3]

  mr <- geomag_calib_rotate(
    matrix(
      c(mag$magnetic_xc, mag$magnetic_yc, mag$magnetic_zc),
      nrow(mag),
      3
    ),
    roll = mag$roll,
    pitch = mag$pitch
  )
  mag$magnetic_xcp <- mr[, 1]
  mag$magnetic_ycp <- mr[, 2]
  mag$magnetic_zcp <- mr[, 3]

  # Derive field intensity, inclination, and heading
  mag$F <- sqrt(rowSums(mr^2))
  mag$I <- -asin(mag$magnetic_zcp / mag$F)
  # Package convention is North=0, East=90; +pi/2 aligns axes before degree conversion.
  mag$H <- ((atan2(mag$magnetic_xcp, mag$magnetic_ycp) + pi / 2) *
    180 /
    pi +
    360) %%
    360

  # Store calibration metadata
  tag$param$geomag_calib <- attr(mag, "geomag_calib")
  tag$param$geomag_calib$calib_data <- ifelse(
    isTRUE(calib_data),
    directory,
    FALSE
  )
  tag$param$geomag_calib$rm_outlier <- rm_outlier
  attr(mag, "geomag_calib") <- NULL

  # Save processed data
  tag$mag_calib <- mag_calib
  tag$magnetic <- mag

  return(tag)
}


#' @noRd
geomag_calib_rm <- function(mag_calib, tag) {
  # Remove values with excessive magnetic field intensity
  mn <- sqrt(
    mag_calib$magnetic_x^2 + mag_calib$magnetic_y^2 + mag_calib$magnetic_z^2
  )
  mag_calib <- mag_calib[mn < 1, ]
  if (nrow(mag_calib) == 0) {
    cli::cli_abort(c(
      "x" = "No calibration data left after removing extreme values.",
      ">" = "Check the magnetic sensor unit for issues."
    ))
  }

  # Initial offset estimation using spherical model
  mag_tmp <- geomag_calib_fit(
    mag = tag$magnetic,
    mag_calib = mag_calib,
    method = "sphere",
    stap = tag$stap
  )
  offset <- attr(mag_tmp, "geomag_calib")$offset

  # Remove values with physically implausible field strengths
  mn <- sqrt(
    (mag_calib$magnetic_x - offset[1])^2 +
      (mag_calib$magnetic_y - offset[2])^2 +
      (mag_calib$magnetic_z - offset[3])^2
  )
  mag_calib <- mag_calib[mn > 0.25, ]
  mag_calib <- mag_calib[mn < 0.65, ]

  # Outlier detection within stap groups if available
  mn <- sqrt(
    (mag_calib$magnetic_x - offset[1])^2 +
      (mag_calib$magnetic_y - offset[2])^2 +
      (mag_calib$magnetic_z - offset[3])^2
  )
  if ("stap_id" %in% names(mag_calib)) {
    G <- round(mag_calib$stap_id)
    split_df <- split(mn, G)
    result <- lapply(split_df, is_outlier)
    mag_calib <- mag_calib[!unsplit(result, G), ]
  } else {
    mag_calib <- mag_calib[!is_outlier(mn), ]
  }

  # Require enough remaining calibration points
  if (nrow(mag_calib) < 10) {
    cli::cli_abort(c(
      "x" = "Removal of outliers left no calibration data."
    ))
  }

  mag_calib
}


#' Classify Static and Moving Samples From Acceleration
#'
#' @description
#' Computes a logical `is_static` flag for each row in `tag$magnetic` using the
#' acceleration magnitude.
#'
#' The classification is done in three steps:
#' 1. Compute the acceleration norm `gn = sqrt(x^2 + y^2 + z^2)` for each sample.
#' 2. Apply the hard threshold `abs(gn - 1) < static_thr_hard` to build the
#'    initial static candidates.
#' 3. If `tag$acceleration` is available, cluster the positive `value` samples
#'    into low- and high-activity groups, force the high-activity group to
#'    `FALSE`, then remove outliers among the remaining candidate static points
#'    using a MAD rule with threshold `static_thr_outlier`.
#'
#'
#' @param tag A `GeoPressureR` tag object containing a `$magnetic` data frame
#'   with `acceleration_x`, `acceleration_y`, and `acceleration_z`. If
#'   `tag$acceleration` is present, its `value` column is used as an activity
#'   signal.
#' @param static_thr_hard Numeric or `NULL`. Hard threshold around 1 g used to
#'   build the initial candidate static set. If `NULL`, the default `0.15` is
#'   used.
#' @param static_thr_outlier Numeric or `NULL`. MAD threshold used to remove
#'   outliers among the candidate static samples. If `NULL`, the default `3` is
#'   used.
#' @param use_activity Logical. If `TRUE` and `tag$acceleration` is available,
#'   use activity clustering to flag high-activity samples as moving before MAD
#'   outlier filtering.
#'
#' @return The input tag object with `tag$magnetic$is_static` added or updated.
#'   `tag$magnetic$is_static` is a logical vector where `TRUE` denotes samples
#'   considered static and `FALSE` denotes samples considered moving.
#'
#' @examples
#' library(GeoPressureR)
#' withr::with_dir(system.file("extdata", package = "GeoMagR"), {
#'   tag <- tag_create("14DM", quiet = TRUE)
#'   tag_static_obj <- tag_static(tag)
#'   table(tag_static_obj$magnetic$is_static)
#'
#'   # A stricter hard threshold keeps fewer samples as static
#'   tag_static_strict <- tag_static(tag, static_thr_hard = 0.05, static_thr_outlier = 2)
#'   table(tag_static_strict$magnetic$is_static)
#' })
#'
#' @export
tag_static <- function(
  tag,
  static_thr_hard = NULL,
  static_thr_outlier = NULL,
  use_activity = FALSE
) {
  if (is.null(tag$magnetic)) {
    cli::cli_abort("No magnetic data found in the tag object.")
  }
  mag <- tag$magnetic

  if (is.null(static_thr_hard)) {
    static_thr_hard <- 0.15
  }
  if (is.null(static_thr_outlier)) {
    static_thr_outlier <- 3
  }

  # Compute the acceleration norm
  gn <- sqrt(mag$acceleration_x^2 + mag$acceleration_y^2 + mag$acceleration_z^2)

  # Use the hard threshold around 1 g to form the initial candidate static set
  is_static <- abs(gn - 1) < static_thr_hard

  # If activity is available, split positive values into low- and high-activity groups.
  # The high-activity group is treated as moving before the final outlier cleanup.
  if (use_activity && !is.null(tag$acceleration)) {
    acc <- tag$acceleration
    km <- stats::kmeans(acc$value[acc$value > 0], centers = 2)
    acc$act_mig <- acc$value > mean(km$centers)
    mag_acc <- merge(mag, acc, by = "date", all.x = TRUE)
    is_static[mag_acc$act_mig] <- FALSE
  }

  # Finish with a robust outlier filter on the candidate static samples.
  is_static[is_static] <- !is_outlier(
    gn[is_static],
    static_thr_outlier = static_thr_outlier
  )

  tag$magnetic$is_static <- is_static
  tag
}

#' Identify outliers in a Numeric Vector (MAD Method)
#' @param x Numeric vector.
#' @param static_thr_outlier Threshold (default 3).
#' @return Logical vector: TRUE if outlier.
#' @noRd
is_outlier <- function(x, static_thr_outlier = 3) {
  med <- stats::median(x, na.rm = TRUE)
  mad_val <- stats::mad(x, na.rm = TRUE)
  abs(x - med) / (mad_val + .Machine$double.eps) > static_thr_outlier
}
