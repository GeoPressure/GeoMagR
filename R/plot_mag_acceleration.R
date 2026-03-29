plot_mag_acceleration <- function(
  tag,
  static_thr_hard = NULL,
  static_thr_outlier = NULL,
  variant = c("acceleration", "acceleration_p")
) {
  variant <- match.arg(variant)
  need_static <- !("is_static" %in%
    names(tag$magnetic) &&
    is.null(static_thr_hard) &&
    is.null(static_thr_outlier))

  if (need_static) {
    tag <- tag_static(
      tag = tag,
      static_thr_hard = static_thr_hard,
      static_thr_outlier = static_thr_outlier
    )
  }
  tag$magnetic$is_static_label <- factor(
    ifelse(tag$magnetic$is_static, "Static", "Moving"),
    c("Moving", "Static")
  )
  cols_acc <- switch(
    variant,
    acceleration = c("acceleration_x", "acceleration_y", "acceleration_z"),
    acceleration_p = c("acceleration_xp", "acceleration_yp", "acceleration_zp")
  )
  axis_titles <- switch(
    variant,
    acceleration = list(
      title = "Raw Acceleration (sensor frame)",
      x = "X (forward)",
      y = "Y (right)",
      z = "Z (down)"
    ),
    acceleration_p = list(
      title = "Projected Acceleration (Horizontal plane of Earth)",
      x = "X_p (forward)",
      y = "Y_p (right)",
      z = "Z_p (down)"
    )
  )
  if (variant == "acceleration_p" && !all(cols_acc %in% names(tag$magnetic))) {
    cli::cli_abort(c(
      x = "Projected acceleration data is missing.",
      ">" = "Please run {.fun geomag_calib} first."
    ))
  }

  p <- plotly::plot_ly() |>
    add_3d_scatter(
      data = tag$magnetic,
      xcol = cols_acc[1],
      ycol = cols_acc[2],
      zcol = cols_acc[3],
      colorcol = "is_static_label",
      colors = viridisLite::viridis(5)
    ) |>
    add_ellipsoid_mesh(color = "lightblue") |>
    plotly::layout(
      title = axis_titles$title,
      legend = list(
        title = list(
          text = switch(
            variant,
            acceleration = "Static / Moving - raw acceleration",
            acceleration_p = "Static / Moving - projected acceleration"
          )
        )
      ),
      scene = list(
        aspectmode = "data",
        xaxis = list(title = axis_titles$x),
        yaxis = list(title = axis_titles$y),
        zaxis = list(title = axis_titles$z)
      )
    )

  if (variant == "acceleration_p") {
    p <- p |>
      plotly::add_trace(
        x = c(0, 0),
        y = c(0, 0),
        z = c(0, 1),
        type = "scatter3d",
        mode = "lines",
        line = list(color = "red", width = 4),
        name = "Reference gravity field"
      )
  }
  p
}
