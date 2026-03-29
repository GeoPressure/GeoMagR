
<!-- README.md is generated from README.Rmd. Please edit that file and use devtools::build_readme() -->

# GeoMagR <img src="man/figures/logo.png" align="right" height="139"/>

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
- **Interactive visualization:** Explore raw and calibrated magnetic
  data with dedicated interactive plots.

GeoMagR is designed to work seamlessly with
[GeoPressureR](https://geopressure.org/GeoPressureR), enabling
high-resolution migratory track reconstruction using multi-sensor
archival tags.

## 📦 Installation

To install the latest version from GitHub:

``` r
# install.packages("pak")
pak::pkg_install("GeoPressure/GeoMagR")
```

## 📘 Vignettes

For full workflows, see the vignettes:

- [Getting Started with
  GeoMagR](https://geopressure.org/GeoMagR/articles/getting-started.html)
- [Movement Model with Magnetic
  Likelihoods](https://geopressure.org/GeoMagR/articles/movement-model-magnetic-likelihood.html)

## 📚 Citation

If you use GeoMagR in your research, please cite:

> Nussbaumer, R. (2025). GeoMagR: Geolocation by Magnetic Field. Zenodo.
> <https://doi.org/10.5281/zenodo.19217183>. Available at:
> <https://github.com/GeoPressure/GeoMagR>

For citation information in R with list(title = “GeoMagR: Geolocation by
Magnetic Field”, author = list(list(given = “Raphaël”, family =
“Nussbaumer”, role = c(“aut”, “cre”), email = “<rafnuss@gmail.com>”,
comment = NULL)), year = “2025”, note = “R package version 0.1.0”, url =
“<https://github.com/GeoPressure/GeoMagR>”)
