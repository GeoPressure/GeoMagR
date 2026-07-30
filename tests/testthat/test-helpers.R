library(GeoMagR)
library(testthat)

test_that("clean_I and clean_F retain valid stationary observations", {
  clean_I <- getFromNamespace("clean_I", "GeoMagR")
  clean_F <- getFromNamespace("clean_F", "GeoMagR")
  mag <- data.frame(
    stap_id = c(1, 1, 1, 2, 2, 2),
    is_static = TRUE,
    I = c(0.1, 0.1, 0.1, 0.2, 0.2, 1.5),
    F = c(0.45, 0.45, 0.45, 0.5, 0.5, 0.6)
  )

  expect_equal(clean_I(mag), c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE))
  expect_equal(clean_F(mag), c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE))
})

test_that("tag_static classifies samples from acceleration magnitude", {
  tag <- list(
    magnetic = data.frame(
      acceleration_x = c(0, 0, 0),
      acceleration_y = c(0, 0, 0),
      acceleration_z = c(1, 1.02, 0.8)
    )
  )

  out <- tag_static(tag, static_thr_hard = 0.05)

  expect_equal(out$magnetic$is_static, c(TRUE, TRUE, FALSE))
})

test_that("calibration transform applies scalar and row-wise amplitudes", {
  geomag_calib_to_calibrated <- getFromNamespace(
    "geomag_calib_to_calibrated",
    "GeoMagR"
  )
  xyz <- rbind(c(2, 4, 6), c(4, 8, 12))

  expect_equal(
    geomag_calib_to_calibrated(
      xyz,
      offset = c(0, 0, 0),
      rotM = diag(3),
      radius_shape = c(2, 4, 6),
      radius_amplitude = 2
    ),
    rbind(c(0.5, 0.5, 0.5), c(1, 1, 1))
  )
  expect_equal(
    geomag_calib_to_calibrated(
      xyz,
      offset = c(0, 0, 0),
      rotM = diag(3),
      radius_shape = c(2, 4, 6),
      radius_amplitude = c(1, 2)
    ),
    rbind(c(1, 1, 1), c(1, 1, 1))
  )
})

test_that("geomag_calib_rotate recycles scalar angles and accepts row-wise angles", {
  geomag_calib_rotate <- getFromNamespace("geomag_calib_rotate", "GeoMagR")
  a <- rbind(c(1, 0, 0), c(0, 1, 0))

  expect_equal(geomag_calib_rotate(a, 0, 0), a)
  expect_equal(
    geomag_calib_rotate(a, 0, 0, c(pi / 2, 0)),
    rbind(c(0, 1, 0), c(0, 1, 0)),
    tolerance = 1e-12
  )
})

test_that("plot helpers assign fallback stationary-period identifiers", {
  plot_mag_add_stap_id <- getFromNamespace("plot_mag_add_stap_id", "GeoMagR")
  ref <- data.frame(date = 1:3, stap_id = c(1, 3, 5))

  expect_equal(
    plot_mag_add_stap_id(data.frame(date = c(1, 4, 2)), ref)$stap_id,
    c(1L, 2L, 3L)
  )
  expect_equal(
    plot_mag_add_stap_id(data.frame(date = 4:5), ref)$stap_id,
    c(1L, 1L)
  )
})
