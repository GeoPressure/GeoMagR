#' Calibrate Magnetic and Acceleration Data for 3-Axis Sensors
#'
#' @description
#' Calibrates 3-axis magnetic sensor data, performs tilt compensation, and
#' computes magnetic field intensity, inclination, and heading.
#'
#' @details
#' ## Workflow and argument use
#'
#' 1. **Classify static samples.** [tag_static()] adds `is_static` to the
#'    magnetic data using `static_thr_hard` and `static_thr_outlier`. Only static
#'    samples are used for the calibration fit, because their acceleration is the
#'    gravity direction.
#' 2. **Select calibration data.** `calib_data` selects a dedicated calibration
#'    dataset, a supplied data frame, or the field data in `tag$magnetic`. With field
#'    data and `stap_id`, the samples of flights with at least 12 samples (e.g. 1 h at
#'    5 min) are added with the flight-mean acceleration as gravity direction: birds
#'    that rest in a single orientation (e.g. owls) only rotate in flight. Static
#'    samples are then thinned to three times the flight samples.
#' 3. **Filter calibration samples.** When `rm_outlier = TRUE`, samples whose raw
#'    magnetic norm differs from the median raw norm by more than `calib_thr_extreme`
#'    are removed (spikes). Rows with incomplete magnetic axes are removed regardless
#'    of `rm_outlier`.
#' 4. **Fit the calibration model.** The hard-iron offset (and the soft-iron shape for
#'    `calib_method = "ellipse"`) is fitted so that, within each stationary period (or
#'    day without `stap_id`), the field intensity and the inclination measured against
#'    the acceleration are constant (see **Calibration model**). The fitted
#'    transformation is applied to every row of `tag$magnetic`.
#' 5. **Perform tilt compensation.** Pitch and roll are computed from the
#'    acceleration, then the acceleration and calibrated magnetic vectors are rotated
#'    into the Earth frame. Flight samples (non-integer `stap_id`) use the mean
#'    acceleration of their flight, which removes most of the wingbeat-induced tilt
#'    error of single snapshots.
#' 6. **Compute and store outputs.** Field intensity, inclination, heading,
#'    calibration data, and fitted parameters are stored in the returned tag.
#'
#' ## Calibration model
#'
#' The notation follows Appendix A of Nussbaumer et al. (2026)
#' (\doi{10.1111/2041-210x.70355}). The raw magnetic vector \eqn{\mathbf{B}_i}{B_i} of sample
#' \eqn{i} is corrected for a hard-iron offset \eqn{\mathbf{o}}{o} and a soft-iron ellipsoid of
#' rotation \eqn{\mathbf{R}}{R} and radii \eqn{\mathbf{A} = \mathrm{diag}(a_1, a_2, a_3)}{A = diag(a_1, a_2, a_3)}:
#' \deqn{\mathbf{M}_i = \mathbf{R}^\top \mathbf{A}^{-1} \mathbf{R} (\mathbf{B}_i - \mathbf{o}),
#' \qquad a_1 a_2 a_3 = 1.}{M_i = t(R) A^-1 R (B_i - o), with a1 a2 a3 = 1.}
#' `"ellipse"` fits \eqn{\mathbf{o}}{o}, \eqn{\mathbf{R}}{R} and the shape of \eqn{\mathbf{A}}{A}
#' (8 parameters); `"sphere"` fits \eqn{\mathbf{o}}{o} only (\eqn{\mathbf{R} = \mathbf{A} =
#' \mathbf{I}}{R = A =
#' I}). The product of the radii is 1, so the sensor scale is kept.
#'
#' Within a group \eqn{g} (stationary period, or day without `stap_id`) the Earth's field is
#' fixed. The intensity \eqn{F_i = \|\mathbf{M}_i\|}{F_i = |M_i|} and the inclination, measured against the
#' unit acceleration \eqn{\hat{\mathbf{a}}_i}{a_i} (gravity on static samples),
#' \deqn{\sin I_i = -\frac{\mathbf{M}_i \cdot \hat{\mathbf{a}}_i}{\|\mathbf{M}_i\|},}{sin(I_i) =
#' -(M_i . a_i) / |M_i|,}
#' are therefore the same for every sample of the group, whatever the posture of the bird. The
#' group values \eqn{F_g} and \eqn{\sin I_g}{sin I_g} are not free parameters: they are the group means,
#' or the WMM values (height 0, mean date of the period) at stationary periods of known location
#' (`tag$stap$known_lat`). The fit minimises
#' \deqn{J(\mathbf{o}, \mathbf{R}, \mathbf{A}) = \sum_i \left[ h(r_i^F) + h(r_i^I) \right] + P_F
#' + P_A,}{J(o, R, A) = sum_i [h(rF_i) + h(rI_i)] + P_F + P_A,}
#' with the residuals \eqn{r_i^F = (F_i - F_{g_i}) / 0.45}{rF_i = (F_i - F_g_i) / 0.45} G and
#' \eqn{r_i^I = \sin I_i - \sin I_{g_i}}{rI_i = sin I_i - sin I_g_i}, and the pseudo-Huber loss
#' \eqn{h(r) = \delta^2 (\sqrt{1 + (r/\delta)^2} - 1)}{h(r) = delta^2 (sqrt1 + (r/delta)^2 - 1)}, \eqn{\delta = 0.02}{delta = 0.02}. The loss is
#' quadratic for small residuals and linear for large ones, which limits the weight of spikes and
#' non-static samples. The penalty \eqn{P_F} keeps \eqn{F_g} of the groups of unknown location
#' within 0.18-0.75 G, and \eqn{P_A} (`"ellipse"` only) pulls the ellipsoid towards a sphere when
#' the data do not constrain its shape. \eqn{J} is minimised with BFGS ([stats::optim()]) from
#' three starting offsets (an algebraic sphere fit, and the mean raw field shifted up or down
#' along gravity), on at most 20,000 evenly thinned samples.
#'
#' Give at least one stationary period with a known location (e.g. the equipment site, with
#' `GeoPressureR::tag_set_map()`): without it, the intensity is not anchored, can be biased, and
#' `geomag_calib()` warns.
#'
#' ## Diagnostics
#'
#' `tag$param$geomag_calib` contains `offset` (\eqn{\mathbf{o}}{o}), `rotM`
#' (\eqn{\mathbf{R}^\top}{R'}), `radius_shape` (\eqn{a_1, a_2, a_3}), `radius_amplitude`
#' (\eqn{F_g}, indexed by `stap_id`) and `optim`, a list with:
#' - `n_obs`, `n_group`, `n_known`: samples, groups and groups of known location in the fit.
#' - `rmse_F`: RMS of \eqn{r_i^F}{rF_i} (relative to 0.45 G).
#' - `rmse_I`: RMS of the inclination residual \eqn{I_i - I_{g_i}}{I_i - I_g_i}, in degrees.
#' - `fit_rmse`: RMS of \eqn{F_i / F_{g_i} - 1}.
#' - `convergence`, `value`: [stats::optim()] convergence code (0 = converged) and final
#'   \eqn{J}.
#'
#' Check that `n_known` is at least 1 and `convergence` is 0. A large `rmse_I` points to
#' non-static samples, a poor static classification, or a tag whose orientation changed during
#' the deployment. On a benchmark of 77 tags from 13 species (5-min to 6-hourly logging), the
#' median static inclination error at stationary periods of unknown location was 2.1 degrees
#' (2.3 degrees for the previous default `ellipse_stap`, which failed on 5 tags).
#'
#' @param tag A `GeoPressureR` tag object containing magnetic and acceleration data.
#' @param calib_data Logical, character, data frame, or `NULL`.
#'        If `TRUE`, uses calibration data from the `magCalib/` subfolder of the
#'        tag directory.
#'        If `FALSE`, calibrates using field-data calibration.
#'        If a character path, uses calibration data from the specified directory.
#'        If a data frame, uses it directly as the calibration dataset (`date`,
#'        `magnetic_x/y/z`, `acceleration_x/y/z` and optionally `is_static` and `stap_id`).
#'        If `NULL`, auto-detects calibration folder.
#' @param calib_method Character. `"ellipse"` (default) corrects hard- and soft-iron
#'   effects, `"sphere"` only the hard-iron offset.
#' @param rm_outlier Logical. If `TRUE`, applies the magnetic calibration-data
#'   filters described in **Workflow and argument use**.
#' @param static_thr_hard Numeric. Hard threshold around 1 g used when classifying static
#'   samples. Passed to [tag_static()].
#' @param static_thr_outlier Numeric. MAD threshold used to remove outliers among candidate static
#'   samples. Passed to [tag_static()].
#' @param quiet Logical. If `TRUE`, suppresses progress messages.
#' @param calib_thr_extreme Numeric. Maximum absolute difference (G) between the raw magnetic
#'   norm (`sqrt(x^2 + y^2 + z^2)`) and its median, used when `rm_outlier = TRUE`.
#'
#' @return Modified `GeoPressureR` tag object. The `$magnetic` data frame contains:
#'   - `date`: Timestamp (POSIXct or numeric)
#'   - `acceleration_x`, `acceleration_y`, `acceleration_z`: Raw acceleration data
#'   - `magnetic_x`, `magnetic_y`, `magnetic_z`: Raw magnetic data
#'   - `is_static`: Logical static-sample classification
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
#' The calibration dataset used is stored in `tag$mag_calib`, and the fitted
#' parameters and argument values are stored in `tag$param$geomag_calib` (see **Diagnostics**).
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
  calib_method = c("ellipse", "sphere"),
  rm_outlier = TRUE,
  static_thr_hard = 0.1,
  static_thr_outlier = 3,
  quiet = FALSE,
  calib_thr_extreme = 1
) {
  GeoPressureR::tag_assert(tag, "magnetic")
  # Methods retired in GeoMagR 0.3.0 map to the gravity-aided fit
  retired <- c(
    "near-sphere",
    "sphere_stap",
    "ellipse_stap",
    "sphere_dip",
    "ellipse_dip"
  )
  if (length(calib_method) == 1 && calib_method %in% retired) {
    new <- if (startsWith(calib_method, "sphere")) "sphere" else "ellipse"
    cli::cli_warn(
      "{.code calib_method = \"{calib_method}\"} was retired in GeoMagR 0.3.0 and replaced by {.val {new}}."
    )
    calib_method <- new
  }
  calib_method <- match.arg(calib_method)
  acc_cols <- c("acceleration_x", "acceleration_y", "acceleration_z")

  # 1. Classify static samples
  tag <- tag_static(
    tag,
    static_thr_hard = static_thr_hard,
    static_thr_outlier = static_thr_outlier
  )
  mag <- tag$magnetic

  # Tilt acceleration: flight samples use the mean acceleration of their flight. A single
  # snapshot during flapping flight mixes gravity with wingbeat acceleration.
  acc <- as.matrix(mag[, acc_cols])
  fl <- if ("stap_id" %in% names(mag)) {
    which(mag$stap_id %% 1 != 0)
  } else {
    integer(0)
  }
  if (length(fl) > 0) {
    g <- floor(mag$stap_id[fl])
    acc_m <- rowsum(acc[fl, , drop = FALSE], g, na.rm = TRUE) /
      as.vector(rowsum(rep(1, length(g)), g))
    acc[fl, ] <- acc_m[match(g, as.numeric(rownames(acc_m))), ]
  }

  # 2. Select calibration data
  if (is.null(calib_data)) {
    directory <- glue::glue("{tag$param$tag_create$directory}/magCalib")
    if (dir.exists(directory)) {
      calib_data <- TRUE
    } else {
      calib_data <- FALSE
    }
  } else if (is.character(calib_data)) {
    directory <- calib_data
    calib_data <- TRUE
  } else if (isTRUE(calib_data)) {
    directory <- glue::glue("{tag$param$tag_create$directory}/magCalib")
  }

  if (isTRUE(calib_data)) {
    if (!dir.exists(directory)) {
      cli::cli_abort(
        "Calibration directory {.path {directory}} does not exist."
      )
    }
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
    if (!quiet) {
      cli::cli_alert_info("Using provided data.frame {.arg calib_data}")
    }
  } else {
    mag_calib <- mag[,
      intersect(
        c(
          "date",
          "magnetic_x",
          "magnetic_y",
          "magnetic_z",
          acc_cols,
          "is_static",
          "stap_id"
        ),
        names(mag)
      )
    ]
    if (!quiet) {
      cli::cli_alert_info("Using raw magnetic data for calibration data")
    }
  }
  # Static samples only (acceleration = gravity) with a stationary period when available
  if ("is_static" %in% names(mag_calib)) {
    mag_calib <- mag_calib[mag_calib$is_static %in% TRUE, ]
  }
  # Without any labelled stationary period, group by day instead
  if ("stap_id" %in% names(mag_calib)) {
    mag_calib <- if (all(is.na(mag_calib$stap_id))) {
      mag_calib[names(mag_calib) != "stap_id"]
    } else {
      mag_calib[!is.na(mag_calib$stap_id), ]
    }
  }
  # Add the samples of flights with at least 12 samples, with the flight-mean acceleration as
  # gravity. Static samples are thinned to 3x the flight samples.
  if (isFALSE(calib_data) && length(fl) > 0) {
    flc <- fl[stats::ave(g, g, FUN = length) >= 12]
    if (length(flc) > 0) {
      mf <- mag[flc, names(mag_calib)]
      mf[, acc_cols] <- acc[flc, ]
      mf$stap_id <- floor(mf$stap_id)
      mf$is_static <- TRUE
      k <- unique(round(seq(
        1,
        nrow(mag_calib),
        length.out = min(nrow(mag_calib), 3 * nrow(mf))
      )))
      mag_calib <- rbind(mag_calib[k, ], mf)
    }
  }

  # 3. Filter calibration samples
  n_calib <- nrow(mag_calib)
  if (rm_outlier) {
    # Spikes: the raw norm is far from its median (not from 1 G, as tags with a large hard-iron
    # offset have raw norms above 1 G)
    mn <- sqrt(
      mag_calib$magnetic_x^2 + mag_calib$magnetic_y^2 + mag_calib$magnetic_z^2
    )
    mag_calib <- mag_calib[
      abs(mn - stats::median(mn, na.rm = TRUE)) < calib_thr_extreme,
    ]
  }
  mag_calib <- mag_calib[
    stats::complete.cases(mag_calib[, c(
      "magnetic_x",
      "magnetic_y",
      "magnetic_z",
      acc_cols
    )]),
  ]
  if (nrow(mag_calib) < 10) {
    cli::cli_abort(c(
      "x" = "Fewer than 10 static calibration samples are left after filtering.",
      ">" = "Check the magnetic sensor and the static classification ({.arg static_thr_hard})."
    ))
  }
  if (nrow(mag_calib) < n_calib / 2) {
    cli::cli_warn(
      "Filtering excluded {n_calib - nrow(mag_calib)} of {n_calib} calibration samples ({round(100 * (n_calib - nrow(mag_calib)) / n_calib)}%)."
    )
  }

  # 4. Fit the calibration model
  mag <- geomag_calib_fit(
    mag = mag,
    mag_calib = mag_calib,
    method = calib_method,
    stap = tag$stap
  )
  if (
    !quiet &&
      isFALSE(calib_data) &&
      attr(mag, "geomag_calib")$optim$n_known == 0
  ) {
    cli::cli_alert_warning(
      "No stationary period with known location: the intensity is not anchored to the WMM and can be biased."
    )
  }

  # 5. Perform tilt compensation
  gn <- sqrt(rowSums(acc^2))

  mag$pitch <- asin(-acc[, 1] / gn)
  mag$roll <- atan2(acc[, 2] / gn, acc[, 3] / gn)

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

  # 6. Compute and store outputs
  mag$F <- sqrt(rowSums(mr^2))
  mag$I <- -asin(mag$magnetic_zcp / mag$F)
  # Package convention is North=0, East=90.
  mag$H <- (atan2(-mag$magnetic_ycp, mag$magnetic_xcp) * 180 / pi + 360) %% 360

  tag$param$geomag_calib <- attr(mag, "geomag_calib")
  tag$param$geomag_calib$calib_data <- ifelse(
    isTRUE(calib_data),
    directory,
    FALSE
  )
  tag$param$geomag_calib$rm_outlier <- rm_outlier
  tag$param$geomag_calib$static_thr_hard <- static_thr_hard
  tag$param$geomag_calib$static_thr_outlier <- static_thr_outlier
  tag$param$geomag_calib$calib_thr_extreme <- calib_thr_extreme
  attr(mag, "geomag_calib") <- NULL

  tag$mag_calib <- mag_calib
  tag$magnetic <- mag

  return(tag)
}

#' Classify Static and Moving Samples From Acceleration
#'
#' @description
#' Computes a logical `is_static` flag for each row in `tag$magnetic` using the
#' acceleration magnitude.
#'
#' The classification is done in these steps:
#' 1. Compute the acceleration norm `gn = sqrt(x^2 + y^2 + z^2)` for each sample.
#' 2. Apply the hard threshold `abs(gn - 1) < static_thr_hard` to build the
#'    initial static candidates.
#' 3. If `use_activity = TRUE` and `tag$acceleration` is available, cluster the
#'    positive activity `value` samples into low- and high-activity groups and
#'    set samples matching the high-activity group (by date) to `FALSE`.
#' 4. Remove outliers among the remaining candidate static samples using a MAD
#'    rule on `gn` with threshold `static_thr_outlier`.
#'
#' Samples with missing acceleration are returned as `NA`.
#'
#'
#' @param tag A `GeoPressureR` tag object containing a `$magnetic` data frame
#'   with `acceleration_x`, `acceleration_y`, and `acceleration_z`. With
#'   `use_activity = TRUE`, the `value` column of `tag$acceleration` is used as
#'   an activity signal.
#' @param static_thr_hard Numeric or `NULL`. Hard threshold around 1 g used to
#'   build the initial candidate static set. If `NULL`, the default `0.1` is
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
  required_cols <- c("acceleration_x", "acceleration_y", "acceleration_z")
  if (!all(required_cols %in% names(mag))) {
    cli::cli_abort(
      "Magnetic data must contain {.field acceleration_x}, {.field acceleration_y}, and {.field acceleration_z}."
    )
  }

  if (is.null(static_thr_hard)) {
    static_thr_hard <- 0.1
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
    # Match by date to keep the row order of tag$magnetic (merge() sorts by date).
    is_static[acc$value[match(mag$date, acc$date)] > mean(km$centers)] <- FALSE
  }

  # Finish with a robust outlier filter on the candidate static samples.
  # which() keeps samples with missing acceleration as NA instead of erroring.
  idx <- which(is_static)
  is_static[idx] <- !is_outlier(
    gn[idx],
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
