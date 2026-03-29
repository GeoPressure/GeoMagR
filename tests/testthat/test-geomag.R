library(GeoPressureR)
library(GeoMagR)
library(testthat)

setwd(system.file("extdata", package = "GeoMagR"))

tag <- GeoPressureR::tag_create("14DM", quiet = TRUE)

tag_static_obj <- tag_static(tag, static_thr_hard = 0.2, static_thr_outlier = 2)
expect_true("is_static" %in% names(tag_static_obj$magnetic))
expect_type(tag_static_obj$magnetic$is_static, "logical")

plot_mag(tag, "acceleration", static_thr_outlier = 2)
expect_error(plot_mag(tag, "acceleration_p"))
plot_mag(tag, "magnetic")
expect_error(plot_mag(tag, "magnetic_c"))
expect_error(plot_mag(tag, "magnetic_cp"))
expect_error(plot_mag(tag, "timeseries"))
expect_error(plot_mag(tag, "histogram"))

test_that("geomag calibration transform round-trips raw coordinates", {
  xyz <- matrix(
    c(
      0.4,
      -0.2,
      0.8,
      -0.3,
      0.7,
      0.1,
      0.2,
      0.5,
      -0.6
    ),
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
  restored <- sweep(calibrated, 2, radius_shape, "*")
  restored <- restored %*% t(rotM)
  restored <- sweep(restored, 2, offset, "+")

  expect_equal(restored, xyz, tolerance = 1e-12)
})

tag <- tag_label(tag, quiet = TRUE)


# Calib without stap: ellipse
tag2 <- geomag_calib(tag, static_thr_outlier = 2, quiet = TRUE)
expect_true(all(
  c("magnetic_xc", "magnetic_yc", "magnetic_zc") %in% names(tag2$magnetic)
))
expect_true(tag2$param$geomag_calib$calib_method == "ellipse")
plot_mag(tag2, "magnetic")
plot_mag(tag2, "magnetic_c")
plot_mag(tag2, "magnetic_cp")
plot_mag(tag2, "acceleration_p")
plot_mag(tag2, "timeseries")
expect_error(plot_mag(tag2, "histogram"))

# Calib with stap
tag <- tag_label(tag, quiet = TRUE)
# tag2 <- geomag_calib(tag, quiet = TRUE)
# plot_mag(tag2,"calib")

# Calib with known
tag <- tag_set_map(
  tag,
  extent = c(-18, 23, 0, 50),
  scale = 2,
  known = data.frame(
    stap_id = c(1, -1),
    known_lon = 7.27,
    known_lat = 46.19
  )
)
tag <- geomag_calib(tag, quiet = TRUE)
plot_mag(tag, "magnetic")
plot_mag(tag, "acceleration_p")
plot_mag(tag, "timeseries")
expect_error(plot_mag(tag2, "histogram"))

# GeoMagR
tag <- geomag_map(tag, quiet = TRUE)

plot(tag, "map_magnetic")

# Plot
path <- tag2path(tag)
plot_mag(tag, "timeseries", path = path)
plot_mag(tag2, "histogram", path = path)
