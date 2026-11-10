#' Calibrate raw magnetic data with a gravity-aided sphere or ellipsoid fit
#'
#' Estimates the hard-iron offset (and, for `"ellipse"`, the soft-iron shape) from static
#' samples, using that within each group (stationary period, or day without `stap_id`) the field
#' intensity and the inclination measured against the acceleration (gravity) are constant. Groups
#' at stationary periods of known location are anchored to the WMM intensity and inclination. The
#' sensor scale is kept (geometric mean of the soft-iron radii = 1), which avoids the degenerate
#' "large sphere through a small cap" solutions of free-scale fits when the bird only adopts a few
#' orientations.
#'
#' @param mag data.frame. Magnetic data with `magnetic_x`, `magnetic_y`, `magnetic_z` (and
#'   `stap_id`, `date` to compute the reference field at known stationary periods).
#' @param mag_calib data.frame. Static calibration samples with `magnetic_x/y/z`,
#'   `acceleration_x/y/z`, `date` and optionally `stap_id`.
#' @param method character. `"ellipse"` (hard and soft iron) or `"sphere"` (hard iron only).
#' @param stap data.frame or NULL. Stationary periods with `stap_id`, `known_lat`, `known_lon`.
#' @param control list. `maxit` for [stats::optim()] and `shape_penalty`, the
#'   soft-iron regularisation of `"ellipse"`.
#'
#' @return `mag` with calibrated `magnetic_xc`, `magnetic_yc`, `magnetic_zc`. The fitted
#'   parameters are returned in the `geomag_calib` attribute (a list).
#' @noRd
geomag_calib_fit <- function(
  mag,
  mag_calib,
  method = "ellipse",
  stap = NULL,
  control = list(maxit = 1000, shape_penalty = 0.01)
) {
  ellipse <- method == "ellipse"
  mag_cols <- c("magnetic_x", "magnetic_y", "magnetic_z")

  # Evenly thinned to at most 20000 samples for speed
  k <- unique(round(seq(
    1,
    nrow(mag_calib),
    length.out = min(nrow(mag_calib), 20000)
  )))
  B <- as.matrix(mag_calib[k, mag_cols])
  A <- as.matrix(mag_calib[
    k,
    c("acceleration_x", "acceleration_y", "acceleration_z")
  ])
  A <- A / sqrt(rowSums(A^2))

  # Groups of constant field: stationary periods, or days without stap_id
  by_stap <- "stap_id" %in% names(mag_calib)
  grp_all <- if (by_stap) {
    round(mag_calib$stap_id)
  } else {
    as.numeric(as.Date(mag_calib$date))
  }
  ug <- unique(grp_all[k])
  G <- match(grp_all[k], ug)
  nG <- tabulate(G, length(ug))

  # WMM intensity (G) and sin(inclination) at stationary periods of known location
  kf <- rep(NA_real_, length(ug))
  ki <- kf
  if (by_stap && !is.null(stap) && "known_lat" %in% names(stap)) {
    sk <- stap[!is.na(stap$known_lat) & stap$stap_id %in% ug, ]
    w <- vapply(
      seq_len(nrow(sk)),
      \(i) {
        r <- wmm::GetMagneticFieldWMM(
          sk$known_lon[i],
          sk$known_lat[i],
          0,
          mean(mag$date[mag$stap_id %in% sk$stap_id[i]])
        )
        c(r$f / 1e5, sin(r$i * pi / 180))
      },
      numeric(2)
    )
    kf[match(sk$stap_id, ug)] <- w[1, ]
    ki[match(sk$stap_id, ug)] <- w[2, ]
  }

  # Pseudo-Huber loss limits the weight of residual non-static samples and spikes. The sensor
  # gain is not fitted: it trades off with the offset and runs to any bound it is given.
  hub <- function(r) 0.02^2 * (sqrt(1 + (r / 0.02)^2) - 1)
  par2cal <- function(p) {
    list(
      offset = p[1:3],
      rotM = if (ellipse) rot(p[4:6]) else diag(3),
      radius_shape = if (ellipse) exp(c(p[7:8], -p[7] - p[8])) else c(1, 1, 1)
    )
  }
  fit_stats <- function(p) {
    cl <- par2cal(p)
    M <- geomag_calib_to_calibrated(B, cl$offset, cl$rotM, cl$radius_shape)
    Fn <- sqrt(rowSums(M^2))
    sI <- -rowSums(M * A) / Fn
    Fg <- ifelse(is.na(kf), rowsum(Fn, G)[, 1] / nG, kf)
    sg <- ifelse(is.na(ki), rowsum(sI, G)[, 1] / nG, ki)
    # Absolute intensity residual (scaled by a typical 0.45 G): a relative one shrinks as the
    # sphere grows, which favours a large offset when the bird adopts only a few orientations.
    list(rF = (Fn - Fg[G]) / 0.45, rI = sI - sg[G], Fg = Fg, sI = sI)
  }
  fn <- function(p) {
    s <- fit_stats(p)
    # Earth's field is 0.22-0.67 G: without this bound, constancy residuals are scale free and an
    # offset far from the data trivially satisfies them.
    Fu <- s$Fg[is.na(kf)]
    pen <- sum(nG[is.na(kf)] * (pmax(Fu - 0.75, 0.18 - Fu, 0) / 0.01)^2)
    if (ellipse) {
      pen <- pen +
        control$shape_penalty * length(s$rF) * sum(c(p[7:8], -p[7] - p[8])^2)
    }
    sum(hub(s$rF)) + sum(hub(s$rI)) + pen
  }

  # Multi-start: algebraic sphere centre and the two hemispheres of the dip
  F0 <- if (all(is.na(kf))) 0.5 else stats::median(kf, na.rm = TRUE)
  v <- qr.solve(cbind(2 * B, 1), rowSums(B^2))
  starts <- list(
    v[1:3],
    colMeans(B) + 0.8 * F0 * colMeans(A),
    colMeans(B) - 0.8 * F0 * colMeans(A)
  )
  fits <- lapply(starts, \(o) {
    stats::optim(
      c(o, if (ellipse) rep(0, 5)),
      fn,
      method = "BFGS",
      control = list(maxit = control$maxit)
    )
  })
  result <- fits[[which.min(vapply(fits, \(r) r$value, numeric(1)))]]
  cl <- par2cal(result$par)
  s <- fit_stats(result$par)

  # Align rotation and shape (helper: rot_align)
  out <- rot_align(cl$rotM, cl$radius_shape)
  rotM <- out$rotM
  radius_shape <- out$radius_shape

  magnetic_xYZ <- geomag_calib_to_calibrated(
    mag[, mag_cols, drop = FALSE],
    offset = cl$offset,
    rotM = rotM,
    radius_shape = radius_shape
  )
  mag$magnetic_xc <- magnetic_xYZ[, 1]
  mag$magnetic_yc <- magnetic_xYZ[, 2]
  mag$magnetic_zc <- magnetic_xYZ[, 3]

  # Fitted field intensity of each group, indexed by stap_id (median without stap_id)
  radius_amplitude <- if (by_stap) {
    replace(rep(NA_real_, max(ug)), ug, s$Fg)
  } else {
    stats::median(s$Fg)
  }

  # Normalised residual of all calibration samples to get fit_rmse
  calib_xYZ <- geomag_calib_to_calibrated(
    mag_calib[, mag_cols, drop = FALSE],
    offset = cl$offset,
    rotM = rotM,
    radius_shape = radius_shape,
    radius_amplitude = s$Fg[match(grp_all, ug)]
  )

  attr(mag, "geomag_calib") <- list(
    calib_method = method,
    radius_amplitude = radius_amplitude,
    radius_shape = radius_shape,
    offset = cl$offset,
    rotM = rotM,
    optim = list(
      fit_rmse = sqrt(mean((sqrt(rowSums(calib_xYZ^2)) - 1)^2, na.rm = TRUE)),
      n_obs = nrow(calib_xYZ),
      n_group = length(ug),
      n_known = sum(!is.na(kf)),
      rmse_F = sqrt(mean(s$rF^2)),
      # Angle residual: d sin(I) = cos(I) dI, so the sin(I) residual understates it
      rmse_I = sqrt(mean((asin(s$sI) - asin(s$sI - s$rI))^2)) * 180 / pi,
      convergence = result$convergence,
      value = result$value
    )
  )

  mag
}

#' Map raw magnetic coordinates to the calibrated frame.
#'
#' @param xyz Numeric matrix with 3 columns.
#' @param offset Numeric vector of length 3.
#' @param rotM 3x3 rotation matrix.
#' @param radius_shape Numeric vector of length 3.
#' @param radius_amplitude Optional numeric vector of per-observation amplitudes.
#' @param rotate_back Logical, whether to rotate back to the original frame.
#'
#' @return Numeric matrix with 3 columns.
#' @noRd
geomag_calib_to_calibrated <- function(
  xyz,
  offset,
  rotM,
  radius_shape,
  radius_amplitude = NULL,
  rotate_back = TRUE
) {
  xyz <- as.matrix(xyz)
  stopifnot(ncol(xyz) == 3)

  xyz <- sweep(xyz, 2, offset, "-")
  xyz <- xyz %*% rotM
  xyz <- sweep(xyz, 2, radius_shape, "/")

  if (!is.null(radius_amplitude)) {
    if (length(radius_amplitude) == 1L) {
      xyz <- xyz / radius_amplitude
    } else {
      xyz <- xyz /
        matrix(
          rep(radius_amplitude, each = ncol(xyz)),
          ncol = ncol(xyz),
          byrow = TRUE
        )
    }
  }

  if (rotate_back) {
    xyz <- xyz %*% t(rotM)
  }
  xyz
}
