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

test_that("geomag_map ignores samples with NA stap_id", {
  withr::local_dir(system.file("extdata", package = "GeoMagR"))

  tag <- tag_create("14DM", quiet = TRUE) |>
    tag_label(quiet = TRUE) |>
    tag_set_map(extent = c(-18, 23, 0, 50), scale = 2) |>
    geomag_calib(quiet = TRUE)
  ref_map <- geomag_map_ref(tag, quiet = TRUE)
  out <- geomag_map(tag, ref_map = ref_map, quiet = TRUE)
  tag$magnetic$stap_id[1:5] <- NA
  out_na <- geomag_map(tag, ref_map = ref_map, quiet = TRUE)

  expect_true(all(is.finite(unlist(out_na$map_magnetic$data))))
  expect_equal(out_na$map_magnetic$data[-1], out$map_magnetic$data[-1])
})

test_that("geomag_calib averages flight acceleration over non-missing values", {
  withr::with_dir(system.file("extdata", package = "GeoMagR"), {
    tag <- GeoPressureR::tag_create("14DM", quiet = TRUE) |>
      GeoPressureR::tag_label(quiet = TRUE)
  })
  fl <- which(floor(tag$magnetic$stap_id) == 2 & tag$magnetic$stap_id %% 1 != 0)
  tag$magnetic$acceleration_x[fl[1]] <- NA
  out <- geomag_calib(tag, quiet = TRUE)
  acc <- colMeans(
    tag$magnetic[fl, c("acceleration_x", "acceleration_y", "acceleration_z")],
    na.rm = TRUE
  )
  expect_equal(
    out$magnetic$pitch[fl],
    rep(asin(-acc[[1]] / sqrt(sum(acc^2))), length(fl))
  )
})

test_that("tag_static with activity is reproducible and keeps the RNG", {
  withr::local_dir(system.file("extdata", package = "GeoMagR"))
  tag <- tag_create("14DM", quiet = TRUE)
  set.seed(1)
  seed <- .Random.seed
  a <- tag_static(tag, use_activity = TRUE)
  expect_identical(.Random.seed, seed)
  expect_identical(tag_static(tag, use_activity = TRUE), a)
})

test_that("geomag_map records unknown provenance of a ref_map without attribute", {
  withr::local_dir(system.file("extdata", package = "GeoMagR"))

  tag <- tag_create("14DM", quiet = TRUE) |>
    tag_label(quiet = TRUE) |>
    tag_set_map(extent = c(-18, 23, 0, 50), scale = 1) |>
    geomag_calib(quiet = TRUE)
  ref_map <- geomag_map_ref(tag, quiet = TRUE)
  attr(ref_map, "geomag_ref") <- NULL
  out <- geomag_map(tag, ref_map = ref_map, quiet = TRUE)

  expect_identical(out$param$geomag_map$ref_map$wmm_version, NA_character_)
})

test_that("geomag_calib keeps only flight samples within flight_window of a stop", {
  rot <- getFromNamespace("rot", "GeoMagR")
  set.seed(1)
  # Three one-day stationary periods at 5 min joined by 10-h flights across a field gradient
  frac <- (1:120) / 121
  stap_id <- c(rep(1, 288), 1 + frac, rep(2, 288), 2 + frac, rep(3, 288))
  fl <- stap_id %% 1 != 0
  F_true <- c(0.48, 0.40, 0.32)
  Fi <- stats::approx(1:3, F_true, stap_id)$y
  Ii <- stats::approx(1:3, c(64, 45, 25) * pi / 180, stap_id)$y
  date <- as.POSIXct("2020-01-01", tz = "UTC") + (seq_along(stap_id) - 1) * 300
  stap <- data.frame(
    stap_id = 1:3,
    start = date[match(1:3, stap_id)],
    end = date[length(stap_id) + 1 - match(1:3, rev(stap_id))]
  )
  # Random orientation at rest, level flight with random heading and zero-mean wingbeat
  xyz <- vapply(
    seq_along(date),
    \(i) {
      R <- if (fl[i]) rot(0, 0, stats::runif(1, 0, 2 * pi)) else rot(stats::runif(3, -pi, pi))
      c(t(R) %*% c(0, 0, 1), t(R) %*% (Fi[i] * c(cos(Ii[i]), 0, -sin(Ii[i]))))
    },
    numeric(6)
  ) |>
    t()
  tag <- structure(
    list(
      param = list(),
      magnetic = data.frame(
        date = date,
        acceleration_x = xyz[, 1],
        acceleration_y = xyz[, 2],
        acceleration_z = xyz[, 3] + fl * c(0.6, -0.6),
        magnetic_x = xyz[, 4] + 0.1,
        magnetic_y = xyz[, 5] - 0.05,
        magnetic_z = xyz[, 6] + 0.2,
        stap_id = stap_id
      ),
      stap = stap
    ),
    class = "tag"
  )
  err <- \(out) max(abs(out$param$geomag_calib$radius_amplitude - F_true))

  out <- geomag_calib(tag, calib_data = FALSE, quiet = TRUE)
  expect_equal(out$param$geomag_calib$flight_window, 1)
  expect_equal(sum(out$mag_calib$date %in% date[fl]), 44)
  expect_lt(err(out), 0.001)
  expect_gt(err(geomag_calib(tag, calib_data = FALSE, quiet = TRUE, flight_window = Inf)), 0.003)

  out0 <- geomag_calib(tag, calib_data = FALSE, quiet = TRUE, flight_window = 0)
  expect_false(any(out0$mag_calib$date %in% date[fl]))
  expect_lt(err(out0), 1e-6)
})
