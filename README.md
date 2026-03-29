
<!-- README.md is generated from README.Rmd. Please edit that file -->

# GeoMagR

<p align="center">

<img src="man/figures/logo.png" alt="GeoMagR logo" width="180" />
</p>

<!-- badges: start -->

[![Lifecycle:
stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![R-CMD-check](https://github.com/GeoPressure/GeoMagR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/GeoPressure/GeoMagR/actions/workflows/R-CMD-check.yaml)
[![pkgdown.yaml](https://github.com/GeoPressure/GeoMagR/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/GeoPressure/GeoMagR/actions/workflows/pkgdown.yaml)
[![jarl](https://github.com/GeoPressure/GeoMagR/actions/workflows/jarl-check.yml/badge.svg)](https://github.com/GeoPressure/GeoMagR/actions/workflows/jarl-check.yml)
[![format](https://github.com/GeoPressure/GeoMagR/actions/workflows/format-check.yml/badge.svg)](https://github.com/GeoPressure/GeoMagR/actions/workflows/format-check.yml)
[![Codecov test
coverage](https://codecov.io/gh/GeoPressure/GeoMagR/graph/badge.svg)](https://app.codecov.io/gh/GeoPressure/GeoMagR)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19217142.svg)](https://doi.org/10.5281/zenodo.19217142)
<!-- badges: end -->

**GeoMagR** is an R package to estimate animal geolocation based on
triaxis magnetic field measurements, including:

- **Magnetic calibration:** Correct magnetic distortion using field-data
  or in-vitro data.
- **Likelihood map estimation:** Compute spatial likelihood maps using
  the World Magnetic Model (WMM), comparing observed and known intensity
  and inclination.
- **Interactive visualization:** Explore raw and calibrated data,
  ellipsoid fits, and 3D scatterplots.

GeoMagR is designed to work seamlessly with
[GeoPressureR](https://geopressure.org/GeoPressureR), enabling
high-resolution migratory track reconstruction using multi-sensor
archival tags.

------------------------------------------------------------------------

## 📦 Installation

To install the latest version from GitHub:

``` r
# install.packages("pak")
pak::pkg_install("GeoPressure/GeoMagR")
```

------------------------------------------------------------------------

## 🛠️ Example Usage

``` r
library(GeoMagR)
library(GeoPressureR)

withr::with_dir(system.file("extdata", package = "GeoMagR"), {
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

If you use GeoMagR in your research, please cite:

> Nussbaumer, R. (2025). GeoMagR: Geolocation by Magnetic Field.
> <https://github.com/GeoPressure/GeoMagR>

For citation information in R:

``` r
citation("GeoMagR")
```
