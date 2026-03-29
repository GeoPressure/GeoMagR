# Calibrate Magnetic and Acceleration Data for 3-Axis Sensors

Performs tilt compensation and magnetic calibration for 3-axis sensor
data, with support for field-data and in vitro calibration routines,
outlier removal, and computation of orientation and field parameters.
This function is designed for use with `GeoPressureR` tag objects and
can utilize calibration datasets if available.

### Workflow

1.  **Magnetic Data Calibration:**

    - Select calibration data source (raw or from calibration dataset).

    - Optionally remove extreme or outlier values.

    - Fit and apply a calibration model (sphere/ellipse or their stap
      variants).

2.  **Tilt Compensation:**

    - Compute pitch and roll from acceleration.

    - Project acceleration and calibrated magnetic data into the
      horizontal plane of the Earth frame.

3.  **Orientation and Field Parameters:**

    - Calculate heading, field intensity, and inclination.

    - Store calibration metadata and processed data in the tag object.

## Usage

``` r
geomag_calib(
  tag,
  calib_data = NULL,
  calib_method = NULL,
  rm_outlier = TRUE,
  static_thr_hard = 0.1,
  static_thr_outlier = 3,
  quiet = FALSE
)
```

## Arguments

- tag:

  A `GeoPressureR` tag object containing magnetic and acceleration data.

- calib_data:

  Logical, character, or `NULL`. If `TRUE`, uses calibration data from
  `magCalib/` subfolder. If `FALSE`, calibrates using field-data
  calibration. If a character path, uses calibration data from the
  specified directory. If `NULL`, auto-detects calibration folder.

- calib_method:

  Character. Calibration method, one of `"sphere"`, `"ellipse"`,
  `"near-sphere"`, `"sphere_stap"`, or `"ellipse_stap"`. If `NULL`,
  chosen automatically.

- rm_outlier:

  Logical. If `TRUE`, removes outliers from calibration data
  (recommended).

- static_thr_hard:

  Numeric. Hard threshold around 1 g used when classifying static
  samples. Passed to
  [`tag_static()`](https://geopressure.org/GeoMagR/reference/tag_static.md).

- static_thr_outlier:

  Numeric. MAD threshold used to remove outliers among candidate static
  samples. Passed to
  [`tag_static()`](https://geopressure.org/GeoMagR/reference/tag_static.md).

- quiet:

  Logical. If `TRUE`, suppresses progress messages.

## Value

Modified `GeoPressureR` tag object. The `$magnetic` data frame contains:

- `date`: Timestamp (POSIXct or numeric)

- `acceleration_x`, `acceleration_y`, `acceleration_z`: Raw acceleration
  data

- `magnetic_x`, `magnetic_y`, `magnetic_z`: Raw magnetic data

- `is_static`: Scaled MAD of acceleration (0 = static, \>1 = movement)

- `pitch`, `roll`: Orientation angles (radian)

- `acceleration_xp`, `acceleration_yp`, `acceleration_zp`: Projected
  acceleration in NED frame

- `magnetic_xc`, `magnetic_yc`, `magnetic_zc`: Calibrated magnetic data

- `magnetic_xcp`, `magnetic_ycp`, `magnetic_zcp`: Calibrated magnetic
  data projected in NED frame

- `H`: Magnetic heading / yaw (degrees). Computed from the calibrated
  magnetic axes after tilt compensation. 0 = North, 90 = East, 180 =
  South, 270 = West. Range \[0, 360).

- `F`: Magnetic field intensity (Gauss)

- `I`: Inclination (radian) Also returns (invisibly) the calibration
  dataset used (`tag$mag_calib`) and calibration parameters
  (`tag$param$geomag_calib`).

## Examples

``` r
library(GeoPressureR)
#> Registered S3 method overwritten by 'GeoPressureR':
#>   method    from   
#>   print.tag pkgdown
withr::with_dir(system.file("extdata", package = "GeoMagR"), {
  tag <- tag_create("14DM", quiet = TRUE)
  tag <- tag_label(tag, quiet = TRUE)
  tag <- geomag_calib(tag, quiet = TRUE)
  tag$param$geomag_calib
  head(tag$magnetic)
})
#> ℹ Using raw magnetic data for calibration data
#>                  date magnetic_x magnetic_y magnetic_z acceleration_x
#> 1 2015-07-15 00:00:00    0.30368    0.12848   -0.14048     -1.0158691
#> 2 2015-07-15 04:00:00   -0.02016   -0.26800   -0.37840     -0.4349365
#> 3 2015-07-15 08:00:00   -0.19648    0.05904   -0.42176     -0.3776245
#> 4 2015-07-15 12:00:00    0.09968    0.16864   -0.33072     -0.9479370
#> 5 2015-07-15 16:00:00    0.28208   -0.12928   -0.22688     -0.9280396
#> 6 2015-07-15 20:00:00    0.26384   -0.12560   -0.26272     -1.0314331
#>   acceleration_y acceleration_z stap_id is_static magnetic_xc magnetic_yc
#> 1    0.115905762      0.2175903       1      TRUE  0.29552062  0.18547623
#> 2   -0.013183594      1.9647217       1     FALSE -0.01051949 -0.27627041
#> 3   -0.115295410      1.1094971       1     FALSE -0.15331763  0.09683036
#> 4   -0.112731934      0.7674561       1     FALSE  0.10926414  0.23048965
#> 5   -0.008361816      1.0251465       1     FALSE  0.26252971 -0.11046512
#> 6   -0.004760742      0.1928101       1      TRUE  0.24452869 -0.10581544
#>   magnetic_zc     pitch         roll acceleration_xp acceleration_yp
#> 1 -0.06559619 1.3327149  0.489447620   -1.387779e-16    0.000000e+00
#> 2 -0.32140008 0.2178549 -0.006710058    0.000000e+00   -1.734723e-18
#> 3 -0.38749907 0.3264234 -0.103545172    0.000000e+00    0.000000e+00
#> 4 -0.27609632 0.8849994 -0.145847404    0.000000e+00    0.000000e+00
#> 5 -0.14845232 0.7357053 -0.008156523   -1.110223e-16    0.000000e+00
#> 6 -0.18655343 1.3859400 -0.024686342   -3.053113e-16    0.000000e+00
#>   acceleration_zp magnetic_xcp magnetic_ycp magnetic_zcp         F         I
#> 1        1.045356   0.09817334   0.19453926   -0.2802734 0.3550165 0.9099384
#> 2        2.012331  -0.07933465  -0.27842079   -0.3097126 0.4239505 0.8191117
#> 3        1.177657  -0.27201992   0.05625973   -0.3253889 0.4278293 0.8641717
#> 4        1.224860  -0.16813456   0.18791724   -0.2787673 0.3758900 0.8354809
#> 5        1.382842   0.09560850  -0.11167229   -0.2855710 0.3211892 1.0953867
#> 6        1.049311  -0.13580609  -0.11038805   -0.2741615 0.3252589 1.0026549
#>           H
#> 1 116.77759
#> 2 285.90464
#> 3  11.68528
#> 4  48.18016
#> 5 229.43143
#> 6 320.89455
```
