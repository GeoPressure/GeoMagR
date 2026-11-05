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
