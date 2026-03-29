#' Calibrate raw magnetic data using ellipsoid or sphere fitting
#'
#' Calibrates raw 3D magnetic field sensor data by fitting an ellipsoid or sphere,
#' correcting for hard and soft iron effects. Supports calibration with or without
#' stationary periods of known location (STAP). See [STMicroelectronics Design Tip](https://www.st.com/resource/en/design_tip/dm00286302-ellipsoid-or-sphere-fitting-for-sensor-calibration-stmicroelectronics.pdf) #nolintr
#' for fitting details.
#'
#' @param mag data.frame. Raw magnetic data; must contain `magnetic_x`, `magnetic_y`, `magnetic_z`.
#' @param mag_calib data.frame. Calibration data (typically a subset of `mag`), same columns as
#' `mag`.
#' @param method character. Calibration method; one of `"sphere"`, `"ellipse"`, `"near-sphere"`,
#' `"ellipse_stap"`, `"sphere_stap"`.
#' @param stap data.frame or NULL. Stationary period info for *_stap methods. Must contain
#' `stap_id`, `known_lon`, `known_lat`.
#' @param control list. Control parameters for optimization (see [stats::optim()]).
#'
#' @return A data.frame like `mag` with additional columns: `magnetic_xc`, `magnetic_yc`,
#' `magnetic_zc` (calibrated values).
#'         Calibration parameters are returned as the `mag_calib` attribute (a list).
#' @noRd
geomag_calib_fit <- function(
  mag,
  mag_calib,
  method = "ellipse",
  stap = NULL,
  control = list(maxit = 10000)
) {
  # Validate required columns and method choice.
  stopifnot(is.data.frame(mag), is.data.frame(mag_calib))
  required_cols <- c("magnetic_x", "magnetic_y", "magnetic_z")
  stopifnot(all(required_cols %in% names(mag)))
  stopifnot(all(required_cols %in% names(mag_calib)))
  valid_methods <- c(
    "sphere",
    "ellipse",
    "near-sphere",
    "ellipse_stap",
    "sphere_stap"
  )
  if (!method %in% valid_methods) {
    stop(
      "Invalid method: method must be one of ",
      paste(valid_methods, collapse = ", ")
    )
  }

  # Compute pitch and roll for mag_calib if acceleration present (used in stap methods)
  if (
    all(
      c("acceleration_x", "acceleration_y", "acceleration_z") %in%
        names(mag_calib)
    )
  ) {
    gn <- sqrt(
      mag_calib$acceleration_x^2 +
        mag_calib$acceleration_y^2 +
        mag_calib$acceleration_z^2
    )
    mag_calib$pitch <- asin(-mag_calib$acceleration_x / gn)
    mag_calib$roll <- atan2(
      mag_calib$acceleration_y / gn,
      mag_calib$acceleration_z / gn
    )
  }

  # Magnetic calibration data as matrices
  Bx <- as.numeric(mag_calib$magnetic_x)
  By <- as.numeric(mag_calib$magnetic_y)
  Bz <- as.numeric(mag_calib$magnetic_z)

  # If using *_stap methods, prepare stationary period info
  if (grepl("_stap$", method)) {
    stopifnot(!is.null(stap))
    stopifnot(is.data.frame(stap))
    stopifnot("stap_id" %in% names(stap))

    B <- cbind(Bx, By, Bz)

    # Build known list of reference field at stap locations
    known_list <- lapply(
      stap$stap_id[!is.na(stap$known_lat)],
      function(stap_id) {
        idx <- match(stap_id, stap$stap_id)
        if (any(mag$stap_id == stap_id)) {
          tmp <- wmm::GetMagneticFieldWMM(
            lon = stap$known_lon[idx],
            lat = stap$known_lat[idx],
            height = 0,
            time = mean(mag$date[mag$stap_id == stap_id])
          )
          data.frame(
            stap_id = stap_id,
            f = as.numeric(unlist(tmp$f)) / 100000,
            i = as.numeric(unlist(tmp$i))
          )
        } else {
          data.frame(stap_id = NA_real_, f = NA_real_, i = NA_real_)
        }
      }
    )
    known <- if (length(known_list) > 0) {
      do.call(rbind, known_list)
    } else {
      data.frame(stap_id = numeric(0), f = numeric(0), i = numeric(0))
    }

    G <- round(mag_calib$stap_id)
  }

  # Fit models according to the chosen method
  if (method == "sphere") {
    # Simple sphere fit (hard iron only)
    D <- cbind(Bx * 2, By * 2, Bz * 2, rep(1, length(Bx)))
    f <- Bx^2 + By^2 + Bz^2
    v <- solve(t(D) %*% D) %*% t(D) %*% f
    offset <- v[1:3]
    radius_amplitude <- sqrt(sum(v[1:3]^2) + v[4])
    radius_shape <- c(1, 1, 1)
    rotM <- rot(0, 0, 0)
  } else if (method == "ellipse") {
    # Full ellipsoid fit
    D <- cbind(
      Bx^2,
      By^2,
      Bz^2,
      2 * Bx * By,
      2 * Bx * Bz,
      2 * By * Bz,
      2 * Bx,
      2 * By,
      2 * Bz
    )
    v <- solve(t(D) %*% D, t(D) %*% rep(1, length(Bx)))
    A <- matrix(
      c(
        v[1],
        v[4],
        v[5],
        v[7],
        v[4],
        v[2],
        v[6],
        v[8],
        v[5],
        v[6],
        v[3],
        v[9],
        v[7],
        v[8],
        v[9],
        -1
      ),
      4,
      4,
      byrow = TRUE
    )
    offset <- solve(-A[1:3, 1:3], v[7:9])
    Tm <- diag(4)
    Tm[4, 1:3] <- t(offset)
    AT <- Tm %*% A %*% t(Tm)
    eig <- eigen(AT[1:3, 1:3] / -AT[4, 4], symmetric = FALSE)
    rotM <- eig$vectors[, 3:1]
    ev <- rev(eig$values)
    radius <- sqrt(1 / ev)
    radius_amplitude <- prod(radius)^(1 / 3)
    radius_shape <- radius / radius_amplitude
  } else if (method == "near-sphere") {
    # Near-sphere (constrained ellipsoid, rarely used)
    x2 <- Bx^2
    y2 <- By^2
    z2 <- Bz^2
    D <- cbind(
      x2 + y2 - 2 * z2,
      x2 - 2 * y2 + z2,
      4 * Bx * By,
      2 * Bx * Bz,
      2 * By * Bz,
      2 * Bx,
      2 * By,
      2 * Bz,
      rep(1, length(Bx))
    )
    R <- x2 + y2 + z2
    b <- solve(t(D) %*% D, t(D) %*% R)
    mtx <- matrix(
      c(
        3,
        1,
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        3,
        1,
        -2,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        3,
        -2,
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        2,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        1
      ),
      10,
      10,
      byrow = TRUE
    )
    v <- mtx %*% c(-1 / 3, b)
    nn <- v[10]
    v <- -v[1:9]
    A <- matrix(
      c(
        v[1],
        v[4],
        v[5],
        v[7],
        v[4],
        v[2],
        v[6],
        v[8],
        v[5],
        v[6],
        v[3],
        v[9],
        v[7],
        v[8],
        v[9],
        -nn
      ),
      4,
      4,
      byrow = TRUE
    )
    offset <- solve(-A[1:3, 1:3], v[7:9])
    Tm <- diag(4)
    Tm[4, 1:3] <- t(offset)
    AT <- Tm %*% A %*% t(Tm)
    eig <- eigen(AT[1:3, 1:3] / -AT[4, 4], symmetric = FALSE)
    rotM <- eig$vectors[, 3:1]
    ev <- rev(eig$values)
    radius <- sqrt(1 / ev)
    radius_amplitude <- prod(radius)^(1 / 3)
    radius_shape <- radius / radius_amplitude
  } else if (method == "sphere_stap") {
    # Sphere fit + per-stap amplitude scaling using known reference
    calculate_err_sphere_stap <- function(params, B, G) {
      radius_stap <- params[4:length(params)]
      M <- geomag_calib_to_calibrated(
        B,
        offset = params[1:3],
        rotM = diag(3),
        radius_shape = c(1, 1, 1),
        radius_amplitude = radius_stap[G],
        rotate_back = FALSE
      )
      err1 <- mean((sqrt(rowSums(M^2)) - 1)^2, na.rm = TRUE)
      M_off <- M * radius_stap[G]
      M_F <- sqrt(rowSums(M_off^2))
      G_id <- which(G %in% known$stap_id)
      if (length(G_id) > 0) {
        known_id <- match(G[G_id], known$stap_id)
        M_known <- as.numeric(unlist(M_F[G_id]))
        known_f <- as.numeric(unlist(known$f[known_id]))
        err2 <- mean(((M_known / known_f) - 1)^2, na.rm = TRUE)
        err1 + err2
      } else {
        err1
      }
    }
    B <- cbind(Bx, By, Bz)
    initial_params <- c(rep(0, 3), rep(0.4, max(G, na.rm = TRUE)))
    lower <- c(apply(B, 2, min) - 0.1, rep(0.05, max(G, na.rm = TRUE)))
    upper <- c(apply(B, 2, max) + 0.1, rep(5, max(G, na.rm = TRUE)))
    result <- stats::optim(
      par = initial_params,
      fn = calculate_err_sphere_stap,
      B = B,
      G = G,
      method = "L-BFGS-B",
      lower = lower,
      upper = upper,
      control = list(maxit = 1000)
    )
    offset <- result$par[1:3]
    radius_amplitude <- result$par[4:length(result$par)]
    radius_shape <- c(1, 1, 1)
    rotM <- rot(0, 0, 0)

    # Ellipsoid fit + per-stap scaling/rotation using known reference
  } else if (method == "ellipse_stap") {
    calculate_err_ellipse_stap <- function(params, B, G, err_type = c(1, 2)) {
      err <- 0
      radius <- c(1, params[7:8])
      radius_stap <- params[9:length(params)]
      M <- geomag_calib_to_calibrated(
        B,
        offset = params[1:3],
        rotM = rot(params[4:6]),
        radius_shape = radius,
        radius_amplitude = radius_stap[G],
        rotate_back = FALSE
      )

      if (1 %in% err_type) {
        mn <- sqrt(rowSums(M^2))
        e <- (mn - 1)^2
        err <- err + mean(e, na.rm = TRUE)
      }
      if (2 %in% err_type) {
        radius_amplitude <- radius_stap * prod(radius)^(1 / 3)
        M_off <- M * radius_amplitude[G]
        M_F <- sqrt(rowSums(M_off^2))
        G_id <- which(G %in% known$stap_id)
        if (length(G_id) > 0) {
          known_id <- match(G[G_id], known$stap_id)
          M_known <- as.numeric(unlist(M_F[G_id]))
          known_f <- as.numeric(unlist(known$f[known_id]))
          err2 <- ((M_known / known_f) - 1)^2
          err <- err + mean(err2, na.rm = TRUE)
        }
      }
      radius_shape <- radius / prod(radius)^(1 / 3)
      err <- err + 0.05 * sum(log(radius_shape)^2)
      err
    }
    B <- cbind(Bx, By, Bz)
    initial_params <- c(
      colMeans(B, na.rm = TRUE), # offset
      0,
      0,
      0, # rot_angles
      1,
      1, # radius ratio
      rep(0.4, max(G, na.rm = TRUE))
    )
    lower <- c(
      apply(B, 2, min, na.rm = TRUE) - 0.1,
      rep(-pi, 3),
      0.3,
      0.3,
      rep(0.05, max(G, na.rm = TRUE))
    )
    upper <- c(
      apply(B, 2, max, na.rm = TRUE) + 0.1,
      rep(pi, 3),
      3,
      3,
      rep(5, max(G, na.rm = TRUE))
    )
    result <- stats::optim(
      par = initial_params,
      fn = calculate_err_ellipse_stap,
      B = B,
      G = G,
      err_type = c(1, 2),
      method = "L-BFGS-B",
      lower = lower,
      upper = upper,
      control = control
    )
    offset <- result$par[1:3]
    rot_angles <- result$par[4:6]
    rotM <- rot(rot_angles)
    radius_shape <- c(1, result$par[7:8])
    radius_amplitude <- result$par[9:length(result$par)] *
      prod(radius_shape)^(1 / 3)
    radius_shape <- radius_shape / prod(radius_shape)^(1 / 3)
  }

  # Align rotation and shape (helper: rot_align)
  out <- rot_align(rotM, radius_shape)
  rotM <- out$rotM
  radius_shape <- out$radius_shape

  magnetic_xYZ <- geomag_calib_to_calibrated(
    mag[, required_cols, drop = FALSE],
    offset = offset,
    rotM = rotM,
    radius_shape = radius_shape
  )
  mag$magnetic_xc <- magnetic_xYZ[, 1]
  mag$magnetic_yc <- magnetic_xYZ[, 2]
  mag$magnetic_zc <- magnetic_xYZ[, 3]

  # We also apply the transformation to the calibration data to get fit_rmse
  calib_radius_amplitude <- NULL
  if (method %in% c("sphere_stap", "ellipse_stap")) {
    calib_radius_amplitude <- radius_amplitude[round(mag_calib$stap_id)]
  }

  calib_xYZ <- geomag_calib_to_calibrated(
    mag_calib[, required_cols, drop = FALSE],
    offset = offset,
    rotM = rotM,
    radius_shape = radius_shape,
    radius_amplitude = calib_radius_amplitude
  )

  # Base diagnostics
  optim_info <- list(
    fit_rmse = sqrt(mean((sqrt(rowSums(calib_xYZ^2)) - 1)^2, na.rm = TRUE)),
    n_obs = nrow(calib_xYZ)
  )

  # Add stap-specific info
  if (method %in% c("sphere_stap", "ellipse_stap")) {
    optim_info$n_stap <- length(unique(round(mag_calib$stap_id)))

    optim_info$convergence <- result$convergence
    optim_info$value <- result$value
    optim_info$counts <- result$counts
    optim_info$message <- result$message %||% NA_character_
  }

  # Attach metric as attribute
  attr(mag, "geomag_calib") <- list(
    calib_method = method,
    radius_amplitude = radius_amplitude,
    radius_shape = radius_shape,
    offset = offset,
    rotM = rotM,
    optim = optim_info
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
      xyz <- xyz / matrix(
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
