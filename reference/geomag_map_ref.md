# Compute Reference Magnetic Map from WMM

Computes raster maps of expected magnetic field intensity and
inclination over the region defined in the tag object, using the World
Magnetic Model (WMM).

## Usage

``` r
geomag_map_ref(tag, quiet = FALSE)
```

## Arguments

- tag:

  A GeoPressureR tag object.

- quiet:

  Logical. If TRUE, suppresses progress messages.

## Value

A list of two terra raster layers: `intensity` (Gauss) and `inclination`
(degrees).
