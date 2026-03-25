# Calibrate Magnetic and Acceleration Data for 3-Axis Sensors

Performs tilt compensation and magnetic calibration for 3-axis sensor
data, with support for in situ and in vitro calibration routines,
outlier removal, and computation of orientation and field parameters.
This function is designed for use with `GeoPressureR` tag objects and
can utilize calibration datasets if available.

### Workflow

1.  **Determine static/movement states:** Classify each data point as
    static or moving by evaluating acceleration signals.

2.  **Magnetic Data Calibration:**

    - Select calibration data source (raw or from calibration dataset).

    - Optionally remove extreme or outlier values.

    - Fit and apply a calibration model (sphere/ellipse or their stap
      variants).

3.  **Tilt Compensation:**

    - Compute pitch and roll from acceleration.

    - Project gravity and calibrated magnetic data into the horizontal
      plane of the Earth frame.

4.  **Orientation and Field Parameters:**

    - Calculate heading, field intensity, and inclination.

    - Store calibration metadata and processed data in the tag object.

## Usage

``` r
geomag_calib(
  tag,
  calib_data = NULL,
  calib_method = NULL,
  rm_outlier = TRUE,
  quiet = FALSE
)
```

## Arguments

- tag:

  A `GeoPressureR` tag object containing magnetic and acceleration data.

- calib_data:

  Logical, character, or `NULL`. If `TRUE`, uses calibration data from
  `magCalib/` subfolder. If `FALSE`, calibrates using in situ data. If a
  character path, uses calibration data from the specified directory. If
  `NULL`, auto-detects calibration folder.

- calib_method:

  Character. Calibration method, one of `"sphere"`, `"ellipse"`,
  `"near-sphere"`, `"sphere_stap"`, or `"ellipse_stap"`. If `NULL`,
  chosen automatically.

- rm_outlier:

  Logical. If `TRUE`, removes outliers from calibration data
  (recommended).

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

- `acceleration_xp`, `acceleration_yp`, `acceleration_zp`: Gravity
  projected in NED frame

- `is_outlier`: Logical, marks outliers in magnetic data

- `magnetic_xc`, `magnetic_yc`, `magnetic_zc`: Calibrated magnetic data

- `magnetic_xcp`, `magnetic_ycp`, `magnetic_zcp`: Calibrated magnetic
  data projected in NED frame

- `H`: Heading (radian, North=0)

- `F`: Magnetic field intensity (Gauss)

- `I`: Inclination (radian) Also returns (invisibly) the calibration
  dataset used (`tag$mag_calib`) and calibration parameters
  (`tag$param$geomag_calib`).

## Details

This function is part of the `GeoMag` package and is intended for use
with animal-attached tags that record magnetic and acceleration data. It
supports several calibration workflows and robust outlier detection.

## Examples

``` r
library(GeoPressureR)
withr::with_dir(system.file("extdata", package = "GeoMag"), {
  tag <- tag_create("14DM", quiet = TRUE)
  tag <- tag_label(tag, quiet = TRUE)
  tag <- geomag_calib(tag, quiet = TRUE)
  tag$param$geomag_calib
  head(tag$magnetic)
})
#> ℹ Using raw magnetic data for calibrationd data
#>                  date magnetic_x magnetic_y magnetic_z acceleration_x
#> 1 2015-07-15 00:00:00    0.30368    0.12848   -0.14048     -1.0158691
#> 2 2015-07-15 04:00:00   -0.02016   -0.26800   -0.37840     -0.4349365
#> 3 2015-07-15 08:00:00   -0.19648    0.05904   -0.42176     -0.3776245
#> 4 2015-07-15 12:00:00    0.09968    0.16864   -0.33072     -0.9479370
#> 5 2015-07-15 16:00:00    0.28208   -0.12928   -0.22688     -0.9280396
#> 6 2015-07-15 20:00:00    0.26384   -0.12560   -0.26272     -1.0314331
#>   acceleration_y acceleration_z stap_id act is_static magnetic_xc magnetic_yc
#> 1    0.115905762      0.2175903       1   0      TRUE  0.39723825   0.1464858
#> 2   -0.013183594      1.9647217       1  16     FALSE  0.09109835  -0.2572194
#> 3   -0.115295410      1.1094971       1   5     FALSE -0.07478949   0.0784787
#> 4   -0.112731934      0.7674561       1   6     FALSE  0.20327502   0.1895737
#> 5   -0.008361816      1.0251465       1   4     FALSE  0.37587817  -0.1168255
#> 6   -0.004760742      0.1928101       1   0      TRUE  0.35820024  -0.1127169
#>   magnetic_zc     pitch         roll acceleration_xp acceleration_yp
#> 1  -0.1302766 1.3327149  0.489447620   -1.447749e-16   -5.339696e-18
#> 2  -0.3813137 0.2178549 -0.006710058   -2.069471e-17   -1.628209e-18
#> 3  -0.4326430 0.3264234 -0.103545172    1.502298e-17    2.942592e-18
#> 4  -0.3331494 0.8849994 -0.145847404   -1.600553e-17   -4.933120e-18
#> 5  -0.2187364 0.7357053 -0.008156523   -1.457710e-16    8.385626e-19
#> 6  -0.2565629 1.3859400 -0.024686342   -2.950453e-16    2.117582e-22
#>   acceleration_zp magnetic_xcp magnetic_ycp magnetic_zcp         F         I
#> 1        1.045356  0.048872269   0.19053532   -0.3969082 0.4429766 1.1106837
#> 2        2.012331  0.006904472  -0.25977218   -0.3902968 0.4688932 0.9833863
#> 3        1.177657 -0.211428421   0.03334027   -0.3913040 0.4460184 1.0702638
#> 4        1.224860 -0.147681890   0.13914414   -0.3835054 0.4338749 1.0841534
#> 5        1.382842  0.132508263  -0.11860573   -0.4137058 0.4503090 1.1648149
#> 6        1.049311 -0.183540960  -0.11901552   -0.3987293 0.4547934 1.0690131
#>            H
#> 1 104.386208
#> 2 268.477497
#> 3   8.961214
#> 4  43.295020
#> 5 221.831144
#> 6 327.038962
```
