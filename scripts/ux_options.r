# Reusable display helpers for Quarto analysis documents.

#' Render a compact interactive DT table
#'
#' @param data Data frame or tibble to display
#' @param page_length Number of rows shown by default
#' @param filter Position for column filters; use "top", "bottom", or "none"
#' @param buttons Export/action buttons to show
#' @param search If TRUE, show the global DataTables search box
#' @param scroll_y Height of the vertical scroll area, such as "400px"; use NULL
#'   for no vertical scroll
#' @param scroll_x If TRUE, allow horizontal scrolling
#' @param paging If TRUE, use DataTables pagination
#' @param wrap_text If TRUE, allow table cells to wrap onto multiple lines
#' @param font_size Optional CSS font size in pixels; supported values are
#'   12, 13, and 14
#' @param escape Passed to DT::datatable(); set FALSE when column names contain
#'   intentional HTML such as <br>
#' @return DT htmlwidget
make_dt_table <- function(
  data,
  page_length = nrow(data),
  filter = "top",
  buttons = c("copy", "csv"),
  search = TRUE,
  scroll_y = NULL,
  scroll_x = TRUE,
  paging = TRUE,
  wrap_text = FALSE,
  font_size = NULL,
  escape = TRUE
) {
  if (!requireNamespace("DT", quietly = TRUE)) {
    stop(
      "The DT package is required for make_dt_table(). ",
      "Install it with install.packages('DT').",
      call. = FALSE
    )
  }

  n_rows <- nrow(data)
  page_length <- min(page_length, n_rows)
  page_lengths <- unique(c(10, 25, n_rows))
  page_length_labels <- as.character(page_lengths)
  wrapper_classes <- character()
  dom_controls <- paste0(
    if (length(buttons) > 0) "B" else "",
    if (isTRUE(search)) "f" else "",
    "rtip"
  )

  table_options <- list(
    dom = dom_controls,
    buttons = buttons,
    pageLength = page_length,
    lengthMenu = list(
      c(page_lengths, -1),
      c(page_length_labels, "All")
    ),
    scrollX = scroll_x,
    autoWidth = TRUE,
    paging = paging,
    columnDefs = list(
      list(className = "dt-left", targets = "_all")
    )
  )

  if (!is.null(scroll_y)) {
    table_options$scrollY <- scroll_y
    table_options$scrollCollapse <- TRUE
  }

  if (wrap_text) {
    wrapper_classes <- c(wrapper_classes, "dt-wrap")
    table_options$scrollX <- FALSE
  }

  if (!is.null(font_size)) {
    font_size <- as.integer(font_size)

    if (!font_size %in% c(12L, 13L, 14L)) {
      stop(
        "font_size must be one of 12, 13, or 14.",
        call. = FALSE
      )
    }

    wrapper_classes <- c(wrapper_classes, paste0("dt-font-", font_size))
  }

  table_widget <- DT::datatable(
    data,
    rownames = FALSE,
    filter = filter,
    extensions = "Buttons",
    class = "cell-border stripe compact hover",
    options = table_options,
    escape = escape
  )

  if (length(wrapper_classes) > 0) {
    table_widget <- htmltools::tagList(
      htmltools::div(
        class = paste(wrapper_classes, collapse = " "),
        table_widget
      )
    )
  }

  table_widget
}
