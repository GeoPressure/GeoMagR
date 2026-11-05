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
