# GeoMagR 0.3.0

## Calibration

`geomag_calib()` now has a single gravity-aided fit, chosen from a benchmark on 77 tags of 13
species (5-min to 6-hourly logging). Results change for every tag.

* The fit makes the field intensity and the inclination measured against gravity constant within
  each stationary period (or day without `stap_id`), anchored to the WMM at stationary periods
  with a known location. The sensor scale is kept. Median static inclination error on stationary
  periods of unknown location: 2.1° (previous default `ellipse_stap`: 2.3°, which failed on 5
  tags).
* `calib_method` is `"ellipse"` (default) or `"sphere"`. `"near-sphere"`, `"sphere_stap"` and
  `"ellipse_stap"` are retired and map to the new fit with a warning.
* Only static samples are used. With field data, flights of at least 12 samples are added with
  the flight-mean acceleration (birds that rest in a single orientation, e.g. owls), and all flight
  samples are tilt-corrected with the flight-mean acceleration instead of single snapshots.
* Give a stationary period with a known location (e.g. the equipment site): without it, the
  intensity is not anchored and `geomag_calib()` warns.
* `calib_thr_extreme` is now the maximum difference from the median raw norm, not an absolute
  norm. The preliminary sphere fit and MAD filter of `rm_outlier` are removed.
* A missing calibration directory now gives an error instead of silently using field data.
* `geomag_calib_rotate()` is vectorised (same output, about 1000 times faster on 5-min data).

## Behaviour changes

* `tag_static()` now uses `static_thr_hard = 0.1` by default (was 0.15), the same as
  `geomag_calib()`, so acceleration plots of an uncalibrated tag match the calibration.
* `plot_mag(type = "histogram")`: the observation panel now shows each sample minus its
  stationary-period mean, whose SD estimates `sd_e_*`. It previously showed observation minus WMM,
  whose SD mixes `sd_e_*` and `sd_m_*`.

# GeoMagR 0.2.3

Faster likelihood maps and documentation updates. Results are unchanged (`all.equal()` to 0.2.2
on the bundled `14DM` example).

* `geomag_map()` computes the likelihood with its closed form, a Gaussian of the mean of the
  observations with variance `sd_m^2 + sd_e^2 / n`, instead of looping over every map cell. It is
  about 20 times faster on the `14DM` example and more than 100 times faster on large maps.
* Simpler code for `geomag_map_ref()` and the sample selection of `geomag_map()`.
* The documentation now gives the units of the `sd_*` arguments, which samples are used, the
  return value of `geomag_map_ref()` (a two-layer `SpatRaster`), and the `use_activity` step of
  `tag_static()`.
* The getting-started vignette now calls `tag_set_map()` before `geomag_calib()`, so the
  `ellipse_stap` calibration uses the known breeding site as in the movement-model vignette.

# GeoMagR 0.2.2

Bug fixes only. Results on the bundled `14DM` example are unchanged, except for one calibration
sample that was wrongly dropped before.

## Magnetic likelihood

* `geomag_map(quiet = TRUE)` no longer shows the progress bar of the default reference map.
* `clean_I()` now excludes non-finite inclination. A single `NA` inclination on a static sample
  previously turned the whole inclination likelihood map of its stationary period into `NA`.

## Calibration

* `geomag_calib()` no longer fails when the magnetic data contain `NA`: incomplete rows are
  removed before the calibration outlier filter.
* The centred-norm filter of the calibration data (`0.25 < norm < 0.65`) was misaligned, which
  added all-`NA` rows and dropped valid samples.
* `geomag_calib()` now errors when `calib_data` is a path to a directory that does not exist,
  instead of silently using field data.
* The `sphere_stap` method now uses the optimiser `control` settings like `ellipse_stap`.
* The `*_stap` methods no longer need R >= 4.4 (`%||%` removed).
* `tag$param$geomag_calib$rotM` is now the identity (not a permutation) for the `sphere` and
  `sphere_stap` methods. Calibrated values are unchanged.
* `tag_static()` keeps samples with missing acceleration as `NA` instead of failing, and
  `use_activity = TRUE` no longer depends on the row order of `tag$magnetic`.

## Plots

* `plot_mag(type = "timeseries")`: outlier legend labels for intensity and inclination were
  swapped.
* `plot_mag(type = "histogram")`: facet labels now show σ instead of the literal `σ`.
* Plots with a `path` work on R 4.1 and 4.2, and the WMM reference no longer depends on the
  session time zone.
* The colour palette has the right length when there is a single stationary period.
