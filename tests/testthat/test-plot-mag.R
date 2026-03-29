library(GeoPressureR)
library(GeoMagR)
library(testthat)

test_that("plot_mag covers the updated 3D branches", {
  setwd(system.file("extdata", package = "GeoMagR"))

  tag <- GeoPressureR::tag_create("14DM", quiet = TRUE)
  tag <- GeoPressureR::tag_label(tag, quiet = TRUE)
  tag <- geomag_calib(tag, quiet = TRUE)

  expect_s3_class(plot_mag(tag, "magnetic"), "plotly")
  expect_s3_class(plot_mag(tag, "magnetic_c"), "plotly")
  expect_s3_class(plot_mag(tag, "magnetic_cp"), "plotly")
  expect_s3_class(plot_mag(tag, "magnetic_calib"), "plotly")
  expect_s3_class(plot_mag(tag, "acceleration"), "plotly")
  expect_s3_class(plot_mag(tag, "acceleration_p"), "plotly")
  expect_s3_class(plot_mag(tag, "timeseries"), "plotly")
  path <- data.frame(
    start = min(tag$magnetic$date),
    end = max(tag$magnetic$date),
    stap_id = tag$stap$stap_id[1],
    lon = 7.27,
    lat = 46.19
  )
  expect_s3_class(
    plot_mag(tag, "timeseries", stap_id = tag$stap$stap_id[1], path = path),
    "plotly"
  )
  expect_error(plot_mag(tag, "histogram"))
  expect_s3_class(
    plot_mag(tag, "histogram", stap_id = tag$stap$stap_id[1], path = path),
    "ggplot"
  )
  expect_error(plot_mag(tag, "unknown"))
})

test_that("plot_mag works without stap_id in magnetic and mag_calib", {
  setwd(system.file("extdata", package = "GeoMagR"))

  tag <- GeoPressureR::tag_create("14DM", quiet = TRUE)
  tag <- GeoPressureR::tag_label(tag, quiet = TRUE)
  tag <- geomag_calib(tag, quiet = TRUE)

  tag$magnetic$stap_id <- NULL
  tag$mag_calib$stap_id <- NULL

  expect_s3_class(plot_mag(tag, "magnetic"), "plotly")
  expect_s3_class(plot_mag(tag, "magnetic_calib"), "plotly")
  expect_s3_class(plot_mag(tag, "calib"), "plotly")
  expect_s3_class(plot_mag(tag, "timeseries"), "plotly")
})
