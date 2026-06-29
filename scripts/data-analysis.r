#!/usr/bin/env Rscript

find_repo_root <- function(start_path = getwd()) {
  current_path <- normalizePath(start_path, mustWork = TRUE)

  repeat {
    data_file <- file.path(current_path, "data", "data-collection.csv")
    script_file <- file.path(current_path, "scripts", "data-analysis.r")

    if (file.exists(data_file) && file.exists(script_file)) {
      result <- current_path
      return(result)
    }

    parent_path <- dirname(current_path)

    if (identical(parent_path, current_path)) {
      stop("Could not find the repository root from: ", start_path)
    }

    current_path <- parent_path
  }
}

read_data_collection <- function(
  data_path = file.path(find_repo_root(), "data", "data-collection.csv")
) {
  required_columns <- c(
    "outcome_id",
    "outcome_label",
    "group",
    "denominator",
    "numerator"
  )

  data_collection <- readr::read_csv(
    data_path,
    show_col_types = FALSE
  )

  missing_columns <- setdiff(required_columns, names(data_collection))

  if (length(missing_columns) > 0) {
    stop(
      "Missing required column(s): ",
      paste(missing_columns, collapse = ", ")
    )
  }

  result <- data_collection |>
    dplyr::mutate(
      denominator = as.numeric(.data$denominator),
      numerator = as.numeric(.data$numerator)
    )

  result
}

calculate_proportion_stats <- function(data_collection = read_data_collection()) {
  z_score <- 1.96

  result <- data_collection |>
    dplyr::mutate(
      negative = .data$denominator - .data$numerator,
      proportion = .data$numerator / .data$denominator,
      percent = 100 * .data$proportion,
      percent_4dp = round(.data$percent, 4),
      z_score = z_score,
      standard_error_proportion = sqrt(
        .data$proportion * (1 - .data$proportion) / .data$denominator
      ),
      standard_error_percent_points = 100 * .data$standard_error_proportion,
      ci_half_width_proportion = .data$z_score *
        .data$standard_error_proportion,
      ci_half_width_percent_points = 100 *
        .data$ci_half_width_proportion,
      ci_lower_proportion = pmax(
        0,
        .data$proportion - .data$ci_half_width_proportion
      ),
      ci_upper_proportion = .data$proportion +
        .data$ci_half_width_proportion,
      ci_lower_percent = 100 * .data$ci_lower_proportion,
      ci_upper_percent = 100 * .data$ci_upper_proportion
    )

  result
}

run_outcome_chi_square <- function(outcome_data, correct = FALSE) {
  contingency_table <- outcome_data |>
    dplyr::select(
      numerator,
      negative
    ) |>
    as.matrix()

  rownames(contingency_table) <- outcome_data$group
  colnames(contingency_table) <- c("Outcome present", "Outcome absent")

  chi_square_test <- stats::chisq.test(
    contingency_table,
    correct = correct
  )

  result <- tibble::tibble(
    outcome_id = unique(outcome_data$outcome_id),
    statistic = unname(chi_square_test$statistic),
    degrees_freedom = unname(chi_square_test$parameter),
    p_value = chi_square_test$p.value,
    continuity_correction = correct
  )

  result
}

run_data_collection_chi_square <- function(
  data_collection = calculate_proportion_stats(),
  correct = FALSE
) {
  result <- data_collection |>
    dplyr::group_by(.data$outcome_id) |>
    dplyr::group_split() |>
    lapply(run_outcome_chi_square, correct = correct) |>
    dplyr::bind_rows()

  result
}

format_p_value <- function(p_value) {
  result <- dplyr::case_when(
    is.na(p_value) ~ "p=NA",
    p_value < 0.001 ~ "p<0.001",
    TRUE ~ paste0("p=", formatC(p_value, format = "f", digits = 3))
  )

  result
}

format_percent_with_p <- function(percent, p_value) {
  result <- paste0(
    formatC(percent, format = "f", digits = 4),
    "% (",
    format_p_value(p_value),
    ")"
  )

  result
}

make_data_collection_table <- function(
  data_collection = calculate_proportion_stats(),
  chi_square_results = run_data_collection_chi_square(data_collection)
) {
  display_labels <- c(
    anal_cancer_dysplasia_total = "Anal cancer/dysplasia",
    perianal_disease_anal_cancer_dysplasia_5y =
      "Perianal disease -> cancer/dysplasia within 5 years",
    anal_hrhpv_total = "Anal-area HR-HPV",
    anal_hrhpv_anal_cancer_dysplasia_5y =
      "Anal-area HR-HPV -> cancer/dysplasia within 5 years"
  )

  group_headers <- data_collection |>
    dplyr::distinct(
      .data$group,
      .data$denominator
    ) |>
    dplyr::mutate(
      group_header = paste0(
        .data$group,
        " (n=",
        formatC(
          .data$denominator,
          format = "d",
          big.mark = ","
        ),
        ")"
      )
    )

  display_data <- data_collection |>
    dplyr::left_join(
      chi_square_results |>
        dplyr::select(
          outcome_id,
          p_value
        ),
      by = "outcome_id"
    ) |>
    dplyr::left_join(
      group_headers,
      by = c("group", "denominator")
    ) |>
    dplyr::mutate(
      outcome_label = dplyr::recode(
        .data$outcome_id,
        !!!display_labels
      ),
      value = format_percent_with_p(.data$percent_4dp, .data$p_value)
    ) |>
    dplyr::select(
      Measure = outcome_label,
      group_header,
      value
    ) |>
    tidyr::pivot_wider(
      names_from = group_header,
      values_from = value
    )

  result <- display_data
  result
}

run_data_analysis <- function() {
  data_collection <- read_data_collection()
  stats <- calculate_proportion_stats(data_collection)
  chi_square_results <- run_data_collection_chi_square(stats)
  display_table <- make_data_collection_table(
    stats,
    chi_square_results
  )

  result <- list(
    data_collection = data_collection,
    stats = stats,
    chi_square_results = chi_square_results,
    display_table = display_table
  )

  result
}

script_file_args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
is_direct_script_run <- length(script_file_args) > 0 &&
  basename(sub("^--file=", "", script_file_args[[1]])) == "data-analysis.r"

if (is_direct_script_run) {
  analysis_result <- run_data_analysis()

  print(analysis_result$chi_square_results)
  print(analysis_result$display_table)
}
