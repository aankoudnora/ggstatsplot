#' @title Histogram for distribution of a numeric variable
#' @name gghistostats
#'
#' @description
#'
#' Histogram with statistical details from one-sample test included in the plot
#' as a subtitle.
#'
#' @section Summary of graphics:
#'
#' ```{r child="man/rmd-fragments/gghistostats_graphics.Rmd"}
#' ```
#'
#' @param ... Currently ignored.
#' @param binwidth The width of the histogram bins. Can be specified as a
#'   numeric value, or a function that calculates width from `x`. The default is
#'   to use the `max(x) - min(x) / sqrt(N)`. You should always check this value
#'   and explore multiple widths to find the best to illustrate the stories in
#'   your data.
#' @param bin.args A list of additional aesthetic arguments to be passed to the
#'   `stat_bin` used to display the bins. Do not specify `binwidth` argument in
#'   this list since it has already been specified using the dedicated argument.
#' @param centrality.line.args A list of additional aesthetic arguments to be
#'   passed to the [`ggplot2::geom_line()`] used to display the lines
#'   corresponding to the centrality parameter.
#' @inheritParams statsExpressions::one_sample_test
#' @inheritParams ggbetweenstats
#'
#' @inheritSection statsExpressions::one_sample_test One-sample tests
#'
#' @seealso \code{\link{grouped_gghistostats}}, \code{\link{ggdotplotstats}},
#'  \code{\link{grouped_ggdotplotstats}}
#'
#' @autoglobal
#'
#' @details For details, see:
#' <https://indrajeetpatil.github.io/ggstatsplot/articles/web_only/gghistostats.html>
#'
#' @examplesIf identical(Sys.getenv("NOT_CRAN"), "true")
#' # for reproducibility
#' set.seed(123)
#'
#' # creating a plot
#' p <- gghistostats(
#'   data            = ToothGrowth,
#'   x               = len,
#'   xlab            = "Tooth length",
#'   centrality.type = "np"
#' )
#'
#' # looking at the plot
#' p
#'
#' # extracting details from statistical tests
#' extract_stats(p)
#' @export
gghistostats <- function(
  data,
  x,
  binwidth = NULL,
  xlab = NULL,
  title = NULL,
  subtitle = NULL,
  caption = NULL,
  type = "parametric",
  test.value = 0,
  bf.prior = 0.707,
  bf.message = TRUE,
  effsize.type = "g",
  conf.level = 0.95,
  tr = 0.2,
  digits = 2L,
  ggtheme = ggstatsplot::theme_ggstatsplot(),
  results.subtitle = TRUE,
  bin.args = list(color = "black", fill = "grey50", alpha = 0.7),
  centrality.plotting = TRUE,
  centrality.type = type,
  centrality.line.args = list(color = "blue", linewidth = 1, linetype = "dashed"),
  ggplot.component = NULL,
  ...
) {
  # data -----------------------------------

  x <- ensym(x)
  data <- tidyr::drop_na(select(data, {{ x }}))
  x_vec <- pull(data, {{ x }})
  type <- stats_type_switch(type)

  # statistical analysis ------------------------------------------

  if (results.subtitle) {
    .f.args <- list(
      data = data,
      x = {{ x }},
      test.value = test.value,
      effsize.type = effsize.type,
      conf.level = conf.level,
      digits = digits,
      tr = tr,
      bf.prior = bf.prior
    )

    # subtitle with statistical results
    subtitle_df <- .eval_f(one_sample_test, !!!.f.args, type = type)
    subtitle <- .extract_expression(subtitle_df)

    # BF message
    if (type == "parametric" && bf.message) {
      caption_df <- .eval_f(one_sample_test, !!!.f.args, type = "bayes")
      caption <- .extract_expression(caption_df)
    }
  }

  # plot -----------------------------------

  plot_hist <- ggplot(data, mapping = aes(x = {{ x }})) +
    exec(
      stat_bin,
      mapping  = aes(y = after_stat(count), fill = after_stat(count)),
      binwidth = binwidth %||% .binwidth(x_vec),
      !!!bin.args
    ) +
    scale_y_continuous(
      sec.axis = sec_axis(
        transform = ~ . / nrow(data),
        labels = function(x) insight::format_percent(x, digits = 0L),
        name = "proportion"
      )
    ) +
    guides(fill = "none")

  # centrality plotting -------------------------------------

  if (isTRUE(centrality.plotting)) {
    plot_hist <- .histo_labeller(
      plot_hist,
      x = x_vec,
      type = stats_type_switch(centrality.type),
      tr = tr,
      digits = digits,
      centrality.line.args = centrality.line.args
    )
  }

  # annotations -------------------------------

  plot_hist +
    labs(
      x        = xlab %||% as_name(x),
      y        = "count",
      title    = title,
      subtitle = subtitle,
      caption  = caption
    ) +
    ggtheme +
    ggplot.component
}


#' @noRd
.binwidth <- function(x) (max(x, na.rm = TRUE) - min(x, na.rm = TRUE)) / sqrt(length(x))


#' @title Grouped histograms for distribution of a numeric variable
#' @name grouped_gghistostats
#'
#' @description
#'
#' Helper function for `ggstatsplot::gghistostats` to apply this function
#' across multiple levels of a given factor and combining the resulting plots
#' using `ggstatsplot::combine_plots`.
#'
#' @inheritParams gghistostats
#' @inheritParams grouped_ggbetweenstats
#' @inheritDotParams gghistostats -title
#'
#' @seealso \code{\link{gghistostats}}, \code{\link{ggdotplotstats}},
#'  \code{\link{grouped_ggdotplotstats}}
#'
#' @autoglobal
#'
#' @inherit gghistostats return references
#' @inherit gghistostats return details
#'
#' @examplesIf identical(Sys.getenv("NOT_CRAN"), "true")
#' # for reproducibility
#' set.seed(123)
#'
#' # plot
#' grouped_gghistostats(
#'   data            = iris,
#'   x               = Sepal.Length,
#'   test.value      = 5,
#'   grouping.var    = Species,
#'   plotgrid.args   = list(nrow = 1),
#'   annotation.args = list(tag_levels = "i")
#' )
#' @export
grouped_gghistostats <- function(
  data,
  x,
  grouping.var,
  binwidth = NULL,
  plotgrid.args = list(),
  annotation.args = list(),
  ...
) {
  .grouped_list(data, {{ grouping.var }}) %>%
    purrr::pmap(
      .f = gghistostats,
      x = {{ x }},
      binwidth = binwidth %||% .binwidth(pull(data, {{ x }})),
      ...
    ) %>%
    combine_plots(plotgrid.args, annotation.args)
}
