plot_mag_magnetic <- function(
  tag,
  cols,
  mag_origin = c("data", "calib"),
  variant = c("raw", "corr", "corr_proj"),
  stap_id = NULL
) {
  mag_origin <- match.arg(mag_origin)
  mag <- if (mag_origin == "data") {
    tag$magnetic
  } else {
    tag$mag_calib
  }
  if (is.null(mag) || nrow(mag) == 0) {
    cli::cli_abort(c(
      x = "Calibration magnetic data is missing.",
      ">" = "Please run {.fun geomag_calib} first."
    ))
  }

  variant <- match.arg(variant)
  cols_xyz <- switch(
    variant,
    raw = c("magnetic_x", "magnetic_y", "magnetic_z"),
    corr = c("magnetic_xc", "magnetic_yc", "magnetic_zc"),
    corr_proj = c("magnetic_xcp", "magnetic_ycp", "magnetic_zcp"),
  )

  if (variant != "raw" && !all(cols_xyz %in% names(mag))) {
    cli::cli_abort(c(
      x = "Calibrated magnetic data is missing.",
      ">" = "Please run {.fun geomag_calib} first."
    ))
  }

  title <- switch(
    variant,
    raw = glue::glue("Raw magnetic"),
    corr = "Magnetic corrected with calibration",
    corr_proj = "Magnetic corrected and projected"
  )
  if (mag_origin == "calib") {
    title <- paste0("Calibration - ", title)
  }

  p <- plotly::plot_ly() |>
    add_3d_scatter(
      mag,
      cols_xyz[1],
      cols_xyz[2],
      cols_xyz[3],
      "stap_id",
      cols
    ) |>
    plotly::layout(
      title = list(
        text = title
      ),
      scene = list(
        aspectmode = "data"
      )
    )

  # Overlay fitted ellipsoids when calibration metadata is available.
  if ("geomag_calib" %in% names(tag$param)) {
    n_radius <- length(tag$param$geomag_calib$radius_amplitude)

    # By default, show periods with minimum and maximum fitted amplitudes.
    if (is.null(stap_id)) {
      tstap <- table(mag$stap_id)
      poss_stap <- as.numeric(names(tstap[tstap > 5]))
      poss_stap <- poss_stap[poss_stap >= 1 & poss_stap <= n_radius]
      if (length(poss_stap) >= 2) {
        stap_id <- poss_stap[c(
          which.min(tag$param$geomag_calib$radius_amplitude[poss_stap]),
          which.max(tag$param$geomag_calib$radius_amplitude[poss_stap])
        )]
      } else if (length(poss_stap) == 1) {
        stap_id <- poss_stap
      } else {
        stap_id <- 1L
      }
    }
    stap_id <- as.integer(round(stap_id))
    stap_id[stap_id < 0] <- n_radius + 1L + stap_id[stap_id < 0]
    stap_id <- unique(stap_id[stap_id >= 1 & stap_id <= n_radius])
    if (length(stap_id) == 0) {
      return(p)
    }

    for (i_stap in stap_id) {
      if (variant == "raw") {
        radius <- tag$param$geomag_calib$radius_shape *
          tag$param$geomag_calib$radius_amplitude[i_stap]
        offset <- tag$param$geomag_calib$offset
        rotM <- tag$param$geomag_calib$rotM
      } else {
        radius <- c(1, 1, 1) * tag$param$geomag_calib$radius_amplitude[i_stap]
        offset <- c(0, 0, 0)
        rotM <- diag(3)
      }

      p <- p |>
        add_ellipsoid_mesh(
          radius = radius,
          offset = offset,
          rotM = rotM,
          color = cols[i_stap]
        )
    }
    # Mark the calibrated origin in corrected variants.
    if (variant != "raw") {
      p <- p |>
        plotly::add_markers(
          x = 0,
          y = 0,
          z = 0,
          marker = list(color = "red", size = 10),
          name = "Origin",
          showlegend = FALSE
        )
    }
  }

  p
}
