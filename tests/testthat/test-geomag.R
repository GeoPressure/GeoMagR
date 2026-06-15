library(GeoPressureR)
library(GeoMagR)
library(testthat)

test_that("rot rotates around the expected principal axes", {
  rot <- getFromNamespace("rot", "GeoMagR")

  expect_equal(
    drop(rot(pi / 2, 0, 0) %*% c(0, 1, 0)),
    c(0, 0, 1),
    tolerance = 1e-12
  )
  expect_equal(
    drop(rot(0, pi / 2, 0) %*% c(1, 0, 0)),
    c(0, 0, -1),
    tolerance = 1e-12
  )
  expect_equal(
    drop(rot(0, 0, pi / 2) %*% c(1, 0, 0)),
    c(0, 1, 0),
    tolerance = 1e-12
  )
})

test_that("geomag calibration transform round-trips raw coordinates", {
  rot <- getFromNamespace("rot", "GeoMagR")
  geomag_calib_to_calibrated <- getFromNamespace(
    "geomag_calib_to_calibrated",
    "GeoMagR"
  )
  xyz <- matrix(
    c(0.4, -0.2, 0.8, -0.3, 0.7, 0.1, 0.2, 0.5, -0.6),
    ncol = 3,
    byrow = TRUE
  )
  offset <- c(0.1, -0.05, 0.2)
  rotM <- rot(c(0.25, -0.1, 0.3))
  radius_shape <- c(1, 1.2, 0.85)

  calibrated <- geomag_calib_to_calibrated(
    xyz,
    offset = offset,
    rotM = rotM,
    radius_shape = radius_shape,
    rotate_back = FALSE
  )
  restored <- sweep(calibrated, 2, radius_shape, "*") |>
    (\(x) x %*% t(rotM))() |>
    sweep(2, offset, "+")

  expect_equal(restored, xyz, tolerance = 1e-12)
})

test_that("likelihood remains finite for critical cases", {
  likelihood <- getFromNamespace("likelihood", "GeoMagR")
  map <- matrix(c(0.3, 0.4, 0.5, 0.6), nrow = 2)

  expect_equal(likelihood(numeric(), map, 0, 0.01), matrix(1, 2, 2))
  expect_true(all(is.finite(likelihood(c(0.4, 0.41), map, 0, 0.001))))
  expect_equal(max(likelihood(c(0.4, 0.41), map, 0, 0.001)), 1)
})

test_that("geomag workflow records parameters and requires contiguous stap_id", {
  withr::local_dir(system.file("extdata", package = "GeoMagR"))

  tag <- tag_create("14DM", quiet = TRUE) |>
    tag_label(quiet = TRUE) |>
    tag_set_map(
      extent = c(-18, 23, 0, 50),
      scale = 2,
      known = data.frame(
        stap_id = c(1, -1),
        known_lon = 7.27,
        known_lat = 46.19
      )
    ) |>
    geomag_calib(quiet = TRUE)
  ref_map <- geomag_map_ref(tag, quiet = TRUE)
  out <- geomag_map(tag, ref_map = ref_map, quiet = TRUE)

  expect_equal(out$param$geomag_calib$calib_thr_extreme, 1)
  expect_equal(
    out$param$geomag_map$ref_map$wmm_version,
    as.character(utils::packageVersion("wmm"))
  )
  expect_error(geomag_map(tag, sd_e_f = 0, ref_map = ref_map, quiet = TRUE))

  tag$stap$stap_id[2] <- 3
  expect_error(
    geomag_map(tag, ref_map = ref_map, quiet = TRUE),
    "consecutive integers"
  )
})
