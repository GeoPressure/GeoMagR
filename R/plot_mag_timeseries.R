plot_mag_timeseries <- function(tag, cols, stap_id, path) {
  if (!"I" %in% names(tag$magnetic)) {
    cli::cli_abort(c(
      x = "Magnetic data has not yet been calibrated.",
      ">" = "Please run {.fun geomag_calib} first."
    ))
  }
  mag <- tag$magnetic
  mag$clean_F <- clean_F(mag)
  mag$clean_I <- clean_I(mag)

  mag_long <- mag |>
    dplyr::mutate(I = .data$I * 180 / pi) |>
    tidyr::pivot_longer(
      cols = c("I", "F"),
      names_to = "variable",
      values_to = "value"
    ) |>
    dplyr::mutate(
      clean = dplyr::if_else(
        .data$variable == "I",
        .data$clean_I,
        .data$clean_F,
        missing = FALSE
      ),
      stap_id = factor(.data$stap_id)
    ) |>
    dplyr::select("date", "stap_id", "variable", "value", "clean")

  mag_clean <- mag_long |>
    dplyr::filter(.data$clean)
  mag_out <- mag_long |>
    dplyr::filter(!.data$clean)

  has_multi_stap <- dplyr::n_distinct(mag_clean$stap_id, na.rm = TRUE) > 1
  if (has_multi_stap && nrow(mag_clean) > 0) {
    segments <- mag_clean |>
      dplyr::group_by(.data$stap_id, .data$variable) |>
      dplyr::summarise(
        start = min(date),
        end = max(date),
        mean_val = mean(.data$value, na.rm = TRUE),
        .groups = "drop"
      )
  } else {
    segments <- mag_clean[
      0,
      c("date", "stap_id", "variable", "value"),
      drop = FALSE
    ] |>
      dplyr::transmute(
        start = .data$date,
        end = .data$date,
        mean_val = .data$value,
        stap_id = .data$stap_id,
        variable = .data$variable
      )
  }

  if (!is.null(path)) {
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
  }

  p <- ggplot2::ggplot() +
    ggplot2::geom_point(
      data = mag_clean,
      ggplot2::aes(x = .data$date, y = .data$value),
      color = "grey40",
      size = 1.5,
      alpha = 0.5,
      show.legend = FALSE
    )

  if (nrow(mag_out) > 0) {
    p <- p +
      ggplot2::geom_point(
        data = mag_out,
        ggplot2::aes(
          x = .data$date,
          y = .data$value,
          color = "Outlier"
        ),
        size = 1.8,
        alpha = 0.95
      )
  }

  if (has_multi_stap && nrow(segments) > 0) {
    p <- p +
      ggplot2::geom_segment(
        data = segments,
        ggplot2::aes(
          x = .data$start,
          xend = .data$end,
          y = .data$mean_val,
          yend = .data$mean_val,
          color = .data$stap_id
        ),
        linewidth = 1.2,
        show.legend = FALSE
      )
  }

  if (!is.null(path)) {
    p <- p +
      ggplot2::geom_segment(
        data = path_long,
        ggplot2::aes(
          x = .data$start,
          xend = .data$end,
          y = .data$val,
          yend = .data$val
        ),
        color = "red",
        linewidth = 1.2,
        show.legend = FALSE
      )
  }

  if ((has_multi_stap && nrow(segments) > 0) || nrow(mag_out) > 0) {
    cols_plot <- c()
    if (has_multi_stap && nrow(segments) > 0) {
      stap_levels <- levels(droplevels(segments$stap_id))
      cols_plot <- c(cols_plot, cols[stap_levels])
    }
    if (nrow(mag_out) > 0) {
      cols_plot <- c(cols_plot, Outlier = "#F3C623")
    }
    p <- p + ggplot2::scale_color_manual(values = cols_plot)
  }

  p <- p +
    ggplot2::facet_wrap(
      ~variable,
      ncol = 1,
      scales = "free_y",
      labeller = ggplot2::labeller(
        variable = c(
          I = "inclination (\u00B0)",
          F = "Intensity (nT)"
        )
      )
    ) +
    ggplot2::theme_minimal()

  p_plotly <- plotly::ggplotly(p)

  if (!is.null(p_plotly$x$data)) {
    for (i in seq_along(p_plotly$x$data)) {
      nm <- p_plotly$x$data[[i]]$name
      if (is.null(nm) || !nzchar(nm)) {
        p_plotly$x$data[[i]]$showlegend <- FALSE
        next
      }
      nm <- strsplit(nm, ",", fixed = TRUE)[[1]][1]
      is_outlier <- identical(nm, "Outlier")
      if (is_outlier) {
        ax <- p_plotly$x$data[[i]]$yaxis
        panel <- if (identical(ax, "y2")) "F" else "I"
        nm <- paste0("Outlier (", panel, ")")
      }
      p_plotly$x$data[[i]]$name <- nm
      p_plotly$x$data[[i]]$legendgroup <- nm
      p_plotly$x$data[[i]]$showlegend <- is_outlier
    }
  }

  p_plotly <- p_plotly |>
    plotly::layout(
      showlegend = TRUE,
      legend = list(
        orientation = "h",
        x = 1,
        xanchor = "right",
        y = 1,
        yanchor = "top",
        bgcolor = "rgba(255,255,255,0.45)",
        borderwidth = 0,
        font = list(size = 10)
      )
    )

  htmlwidgets::onRender(
    p_plotly,
    "function(el, x) {
      function autoscale() {
        var gd = document.getElementById(el.id);
        if (!gd || !gd._fullLayout) return;
        var relayout = {};
        Object.keys(gd._fullLayout).forEach(function(k) {
          if (/^xaxis[0-9]*$/.test(k) || /^yaxis[0-9]*$/.test(k)) {
            relayout[k + '.autorange'] = true;
          }
        });
        Plotly.relayout(gd, relayout);
      }
      el.on('plotly_restyle', function() {
        setTimeout(autoscale, 0);
      });
    }"
  )
}
