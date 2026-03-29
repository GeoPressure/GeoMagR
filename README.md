
<!-- README.md is generated from README.Rmd. Please edit that file -->

# GeoMag

<p align="center">

<img src="man/figures/logo.png" alt="GeoMagR logo" width="180" />
</p>

<!-- badges: start -->

[![R-CMD-check](https://github.com/GeoPressure/GeoMag/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/GeoPressure/GeoMag/actions/workflows/R-CMD-check.yaml)
[![lint](https://github.com/GeoPressure/GeoMag/actions/workflows/lint.yaml/badge.svg)](https://github.com/GeoPressure/GeoMag/actions/workflows/lint.yaml)
[![Lifecycle:
stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
<!-- badges: end -->

**GeoMag** is an R package to estimate animal geolocation based on
triaxis magnetic field measurements, including:

- **Magnetic calibration:** Correct magnetic distortion using in-situ or
  in-vitro data.
- **Likelihood map estimation:** Compute spatial likelihood maps using
  the World Magnetic Model (WMM), comparing observed and known intensity
  and inclination.
- **Interactive visualization:** Explore raw and calibrated data,
  ellipsoid fits, and 3D scatterplots.

GeoMag is designed to work seamlessly with
[GeoPressureR](https://geopressure.org/GeoPressureR), enabling
high-resolution migratory track reconstruction using multi-sensor
archival tags.

------------------------------------------------------------------------

## 📦 Installation

To install the latest version from GitHub:

``` r
# install.packages("pak")
pak::pkg_install("GeoPressure/GeoMag")
```

------------------------------------------------------------------------

## 🛠️ Example Usage

``` r
library(GeoMag)
library(GeoPressureR)

withr::with_dir(system.file("extdata", package = "GeoMag"), {
  # Create a GeoPressureR tag object (see GeoPressureR documentation)
  tag <- tag_create("14DM")

  # Label the tag
  tag <- tag_label(tag)
})

# Calibrate the tag's magnetic data
tag <- geomag_calib(tag)

# Interactive 3D plot of calibrated magnetic field
plot_mag(tag, type = "acceleration")
plot_mag(tag, type = "magnetic")
plot_mag(tag, type = "calib")

# Compute the spatial likelihood map for each stationary period
tag <- geomag_map(tag)

plot(tag, "map_magnetic")
```

------------------------------------------------------------------------

## 📚 Citation

If you use GeoMag in your research, please cite:

> Nussbaumer, R. (2025). GeoMag: Magnetic Field-Based Geolocation in R.
> <https://github.com/GeoPressure/GeoMag>

For citation information in R:

``` r
citation("GeoMag")
```
