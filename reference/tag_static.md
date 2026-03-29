# Classify Static and Moving Samples From Acceleration

Computes a logical `is_static` flag for each row in `tag$magnetic` using
the acceleration magnitude.

The classification is done in three steps:

1.  Compute the acceleration norm `gn = sqrt(x^2 + y^2 + z^2)` for each
    sample.

2.  Apply the hard threshold `abs(gn - 1) < static_thr_hard` to build
    the initial static candidates.

3.  If `tag$acceleration` is available, cluster the positive `value`
    samples into low- and high-activity groups, force the high-activity
    group to `FALSE`, then remove outliers among the remaining candidate
    static points using a MAD rule with threshold `static_thr_outlier`.

## Usage

``` r
tag_static(
  tag,
  static_thr_hard = NULL,
  static_thr_outlier = NULL,
  use_activity = FALSE
)
```

## Arguments

- tag:

  A `GeoPressureR` tag object containing a `$magnetic` data frame with
  `acceleration_x`, `acceleration_y`, and `acceleration_z`. If
  `tag$acceleration` is present, its `value` column is used as an
  activity signal.

- static_thr_hard:

  Numeric or `NULL`. Hard threshold around 1 g used to build the initial
  candidate static set. If `NULL`, the default `0.15` is used.

- static_thr_outlier:

  Numeric or `NULL`. MAD threshold used to remove outliers among the
  candidate static samples. If `NULL`, the default `3` is used.

- use_activity:

  Logical. If `TRUE` and `tag$acceleration` is available, use activity
  clustering to flag high-activity samples as moving before MAD outlier
  filtering.

## Value

The input tag object with `tag$magnetic$is_static` added or updated.
`tag$magnetic$is_static` is a logical vector where `TRUE` denotes
samples considered static and `FALSE` denotes samples considered moving.

## Examples

``` r
library(GeoPressureR)
withr::with_dir(system.file("extdata", package = "GeoMagR"), {
  tag <- tag_create("14DM", quiet = TRUE)
  tag_static_obj <- tag_static(tag)
  table(tag_static_obj$magnetic$is_static)

  # A stricter hard threshold keeps fewer samples as static
  tag_static_strict <- tag_static(tag, static_thr_hard = 0.05, static_thr_outlier = 2)
  table(tag_static_strict$magnetic$is_static)
})
#> 
#> FALSE  TRUE 
#>   952   998 
```
