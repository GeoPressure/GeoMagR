plot_mag_histogram <- function(tag, cols, stap_id, path) {
  if (!"I" %in% names(tag$magnetic)) {
    cli::cli_abort(c(
      x = "Magnetic data has not yet been calibrated.",
      ">" = "Please run {.fun geomag_calib} first."
    ))
  }
  if (is.null(path)) {
    cli::cli_abort("{.arg path} is required for histogram plots.")
  }

  mag_i <- tag$magnetic[clean_I(tag$magnetic), , drop = FALSE]
  mag_f <- tag$magnetic[clean_F(tag$magnetic), , drop = FALSE]

  mag <- dplyr::bind_rows(
    mag_i |>
      dplyr::mutate(
        stap_id = factor(stap_id),
        variable = "I",
        value = .data$I * 180 / pi
      ) |>
      dplyr::select("date", "stap_id", "variable", "value"),
    mag_f |>
      dplyr::mutate(
        stap_id = factor(stap_id),
        variable = "F",
        value = .data$F
      ) |>
      dplyr::select("date", "stap_id", "variable", "value")
  )

  path <- path |>
    dplyr::mutate(stap_id = factor(stap_id))
  time <- as.POSIXct(rowMeans(cbind(path$start, path$end)))
  path[c("F", "I")] <- t(vapply(
    seq_len(nrow(path)),
    \(i) {
      out <- wmm::GetMagneticFieldWMM(path$lon[i], path$lat[i], 0, time[i])
      c(out$f / 100000, out$i)
    },
    numeric(2)
  ))
  path_long <- path |>
    dplyr::select("start", "end", "stap_id", "F", "I") |>
    tidyr::pivot_longer(
      cols = c("I", "F"),
      names_to = "variable",
      values_to = "val"
    ) |>
    dplyr::mutate(stap_id = factor(.data$stap_id))

  err <- mag |>
    dplyr::left_join(path_long, by = c("stap_id", "variable")) |>
    dplyr::mutate(
      err = .data$value - .data$val
    ) |>
    dplyr::select(-c("date", "start", "end", "value", "val"))

  err_stap <- err |>
    dplyr::group_by(.data$stap_id, .data$variable) |>
    dplyr::summarise(
      err = mean(err, na.rm = TRUE),
      .groups = "drop"
    )

  df <- rbind(
    err |> dplyr::mutate(type = "observation (\\u03c3_e)"),
    err_stap |> dplyr::mutate(type = "stap (\\u03c3_m)")
  )

  sds <- df |>
    dplyr::group_by(.data$type, .data$variable) |>
    dplyr::summarise(sd = stats::sd(err, na.rm = TRUE), .groups = "drop")

  ggplot2::ggplot(df, ggplot2::aes(x = .data$err)) +
    ggplot2::geom_histogram(bins = 40) +
    ggplot2::facet_grid(type ~ variable, scales = "free") +
    ggplot2::geom_text(
      data = sds,
      ggplot2::aes(
        x = Inf,
        y = Inf,
        label = paste0("SD=", round(.data$sd, 4))
      ),
      hjust = 1.1,
      vjust = 1.5,
      inherit.aes = FALSE
    ) +
    ggplot2::labs(x = "Error obs - WMM", y = NULL)
}
