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
    dplyr::group_by(.data$outcome_id) |>
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
      ci_upper_percent = 100 * .data$ci_upper_proportion,
      odds = .data$numerator / .data$negative,
      reference_odds = .data$odds[.data$group == "Non-IBD"][[1]],
      odds_ratio_vs_non_ibd = .data$odds / .data$reference_odds,
      reference_numerator = .data$numerator[.data$group == "Non-IBD"][[1]],
      reference_negative = .data$negative[.data$group == "Non-IBD"][[1]],
      log_odds_ratio_se_vs_non_ibd = dplyr::if_else(
        .data$group == "Non-IBD",
        NA_real_,
        sqrt(
          1 / .data$numerator +
            1 / .data$negative +
            1 / .data$reference_numerator +
            1 / .data$reference_negative
        )
      ),
      odds_ratio_ci_lower_vs_non_ibd = dplyr::if_else(
        .data$group == "Non-IBD",
        NA_real_,
        exp(
          log(.data$odds_ratio_vs_non_ibd) -
            .data$z_score * .data$log_odds_ratio_se_vs_non_ibd
        )
      ),
      odds_ratio_ci_upper_vs_non_ibd = dplyr::if_else(
        .data$group == "Non-IBD",
        NA_real_,
        exp(
          log(.data$odds_ratio_vs_non_ibd) +
            .data$z_score * .data$log_odds_ratio_se_vs_non_ibd
        )
      )
    ) |>
    dplyr::ungroup() |>
    dplyr::select(
      -"reference_odds",
      -"reference_numerator",
      -"reference_negative"
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

format_count_with_percent <- function(numerator, percent) {
  result <- paste0(
    formatC(
      numerator,
      format = "d",
      big.mark = ","
    ),
    " (",
    formatC(percent, format = "f", digits = 4),
    "%)"
  )

  result
}

get_data_collection_display_labels <- function() {
  result <- c(
    anal_cancer_dysplasia_total = "Anal Cancer or Dysplasia (total)",
    perianal_disease_anal_cancer_dysplasia_5y =
      "Anal Cancer or Dysplasia 5 years after Perianal Disease diagnosis",
    anal_hrhpv_anal_cancer_dysplasia_5y =
      "Anal cancer or dysplasia 5 years after HR-HPV diagnosis",
    anal_hrhpv_total =
      "Positive High-Risk HPV diagnosis in anal area (total)"
  )

  result
}

get_data_collection_outcome_order <- function() {
  result <- c(
    "anal_cancer_dysplasia_total",
    "perianal_disease_anal_cancer_dysplasia_5y",
    "anal_hrhpv_anal_cancer_dysplasia_5y",
    "anal_hrhpv_total"
  )

  result
}

make_group_headers <- function(data_collection) {
  result <- data_collection |>
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

  result
}

prepare_data_collection_display_data <- function(
  data_collection = calculate_proportion_stats(),
  chi_square_results = run_data_collection_chi_square(data_collection)
) {
  display_labels <- get_data_collection_display_labels()
  outcome_order <- get_data_collection_outcome_order()
  group_headers <- make_group_headers(data_collection)

  display_data <- data_collection |>
    dplyr::mutate(
      outcome_id = factor(
        .data$outcome_id,
        levels = outcome_order
      )
    ) |>
    dplyr::arrange(.data$outcome_id) |>
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
        as.character(.data$outcome_id),
        !!!display_labels
      ),
      value = format_count_with_percent(
        .data$numerator,
        .data$percent_4dp
      )
    ) |>
    dplyr::select(
      "outcome_id",
      "outcome_label",
      "group",
      "denominator",
      "group_header",
      "value"
    )

  result <- display_data
  result
}

make_data_collection_table <- function(
  data_collection = calculate_proportion_stats(),
  chi_square_results = run_data_collection_chi_square(data_collection)
) {
  display_data <- prepare_data_collection_display_data(
    data_collection,
    chi_square_results
  )

  result <- display_data |>
    dplyr::select(
      Measure = outcome_label,
      group_header,
      value
    ) |>
    tidyr::pivot_wider(
      names_from = group_header,
      values_from = value
    )

  result
}

make_patient_type_data_collection_table <- function(
  data_collection = calculate_proportion_stats(),
  chi_square_results = run_data_collection_chi_square(data_collection)
) {
  display_data <- prepare_data_collection_display_data(
    data_collection,
    chi_square_results
  )

  result <- display_data |>
    dplyr::select(
      `Patient Type` = group_header,
      outcome_label,
      value
    ) |>
    tidyr::pivot_wider(
      names_from = outcome_label,
      values_from = value
    )

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
  patient_type_display_table <- make_patient_type_data_collection_table(
    stats,
    chi_square_results
  )

  result <- list(
    data_collection = data_collection,
    stats = stats,
    chi_square_results = chi_square_results,
    display_table = display_table,
    patient_type_display_table = patient_type_display_table
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
  print(analysis_result$patient_type_display_table)
}
