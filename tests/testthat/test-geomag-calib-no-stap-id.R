library(GeoPressureR)
library(GeoMagR)
library(testthat)

test_that("geomag_calib works when magnetic data has no stap_id", {
  withr::with_dir(system.file("extdata", package = "GeoMagR"), {
    tag <- GeoPressureR::tag_create("14DM", quiet = TRUE)
    tag$magnetic$stap_id <- NULL

    expect_false("stap_id" %in% names(tag$magnetic))

    out <- geomag_calib(tag, quiet = TRUE)

    expect_true(all(
      c(
        "magnetic_xc",
        "magnetic_yc",
        "magnetic_zc"
      ) %in%
        names(out$magnetic)
    ))
    expect_false("stap_id" %in% names(out$magnetic))
    expect_true(
      out$param$geomag_calib$calib_method %in%
        c(
          "sphere",
          "ellipse",
          "near-sphere"
        )
    )
  })
})

test_that("geomag_calib maps retired methods with a warning", {
  withr::with_dir(system.file("extdata", package = "GeoMagR"), {
    tag <- GeoPressureR::tag_create("14DM", quiet = TRUE)
    tag$magnetic$stap_id <- NULL

    expect_warning(
      out <- geomag_calib(tag, calib_method = "ellipse_stap", quiet = TRUE),
      "retired"
    )
    expect_equal(out$param$geomag_calib$calib_method, "ellipse")
  })
})

test_that("geomag_calib reports rmse_I as the inclination angle residual", {
  geomag_calib_to_calibrated <- getFromNamespace(
    "geomag_calib_to_calibrated",
    "GeoMagR"
  )
  withr::with_dir(system.file("extdata", package = "GeoMagR"), {
    tag <- GeoPressureR::tag_create("14DM", quiet = TRUE)
    tag$magnetic$stap_id <- NULL
    out <- geomag_calib(tag, quiet = TRUE)
  })
  p <- out$param$geomag_calib
  mc <- out$mag_calib
  M <- geomag_calib_to_calibrated(
    mc[, c("magnetic_x", "magnetic_y", "magnetic_z")],
    p$offset,
    p$rotM,
    p$radius_shape
  )
  A <- as.matrix(mc[, c("acceleration_x", "acceleration_y", "acceleration_z")])
  sI <- -rowSums(M * A) / sqrt(rowSums(M^2)) / sqrt(rowSums(A^2))
  # Groups are days without stap_id; their inclination is the mean sin(I)
  dI <- asin(sI) - asin(stats::ave(sI, as.Date(mc$date)))
  expect_equal(p$optim$rmse_I, sqrt(mean(dI^2)) * 180 / pi, tolerance = 1e-6)
})

test_that("geomag_calib is silent with quiet = TRUE", {
  withr::with_dir(system.file("extdata", package = "GeoMagR"), {
    tag <- GeoPressureR::tag_create("14DM", quiet = TRUE)
    tag$magnetic$stap_id <- NULL
    expect_silent(geomag_calib(tag, quiet = TRUE))
    expect_silent(geomag_calib(tag, calib_data = tag$magnetic, quiet = TRUE))
  })
})
