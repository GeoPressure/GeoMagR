#' Apply Rotation Matrix to Sensor Data for Frame Alignment
#'
#' @description
#' Rotates each row of a 3-column matrix of sensor data from the sensor's frame to the
#' world (NED) frame, using per-row roll, pitch, and yaw angles. This is typically used for tilt
#' compensation of acceleration or magnetic data.
#'
#' @param a Numeric matrix (N x 3), each row is a 3-vector in the sensor frame.
#' @param roll Numeric vector of roll angles (radians), length 1 or nrow(a).
#' @param pitch Numeric vector of pitch angles (radians), length 1 or nrow(a).
#' @param yaw Numeric vector of yaw angles (radians), length 1 or nrow(a). Default: 0.
#'
#' @return A numeric matrix (N x 3), where each row is the rotated vector in the world/NED frame.
#'
#' @examples
#' # Example: Rotate a single vector by roll = 0.1 rad, pitch = 0.2 rad, yaw = 0
#' v <- matrix(c(1, 0, 0), ncol = 3)
#' geomag_calib_rotate(v, roll = 0.1, pitch = 0.2)
#'
#' @noRd
geomag_calib_rotate <- function(a, roll, pitch, yaw = 0) {
  # Validate dimensions and angle inputs.
  if (is.null(roll) || length(roll) == 0) {
    cli::cli_abort("{.arg roll} cannot be {.val NULL} or empty")
  }
  if (is.null(pitch) || length(pitch) == 0) {
    cli::cli_abort("{.arg pitch} cannot be {.val NULL} or empty")
  }
  if (is.null(yaw) || length(yaw) == 0) {
    cli::cli_abort("{.arg yaw} cannot be {.val NULL} or empty")
  }
  assertthat::assert_that(assertthat::are_equal(dim(a)[2], 3))

  # Recycle scalar angles to row-wise vectors.
  if (length(roll) == 1) {
    roll <- rep(roll, nrow(a))
  }
  if (length(pitch) == 1) {
    pitch <- rep(pitch, nrow(a))
  }
  if (length(yaw) == 1) {
    yaw <- rep(yaw, nrow(a))
  }

  assertthat::assert_that(assertthat::are_equal(nrow(a), length(roll)))
  assertthat::assert_that(assertthat::are_equal(nrow(a), length(pitch)))
  assertthat::assert_that(assertthat::are_equal(nrow(a), length(yaw)))

  # Vectorised rot(roll, pitch, yaw) %*% a[i, ] = Rz %*% Ry %*% Rx %*% a[i, ]
  cr <- cos(roll)
  sr <- sin(roll)
  cp <- cos(pitch)
  sp <- sin(pitch)
  cy <- cos(yaw)
  sy <- sin(yaw)
  y1 <- cr * a[, 2] - sr * a[, 3]
  z1 <- sr * a[, 2] + cr * a[, 3]
  x2 <- cp * a[, 1] + sp * z1
  z2 <- -sp * a[, 1] + cp * z1
  cbind(cy * x2 - sy * y1, sy * x2 + cy * y1, z2, deparse.level = 0)
}
