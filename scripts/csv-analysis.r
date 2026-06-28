#!/usr/bin/env Rscript

find_repo_root <- function(start_path = getwd()) {
  current_path <- normalizePath(start_path, mustWork = TRUE)

  repeat {
    data_file <- file.path(current_path, "data", "hrhpv_group_counts.csv")
    script_file <- file.path(current_path, "scripts", "csv-analysis.r")

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

read_hrhpv_counts <- function(
  data_path = file.path(find_repo_root(), "data", "hrhpv_group_counts.csv")
) {
  required_columns <- c(
    "group",
    "outcome_positive",
    "outcome_negative",
    "total"
  )

  counts <- readr::read_csv(
    data_path,
    show_col_types = FALSE
  )

  missing_columns <- setdiff(required_columns, names(counts))

  if (length(missing_columns) > 0) {
    stop(
      "Missing required column(s): ",
      paste(missing_columns, collapse = ", ")
    )
  }

  result <- counts |>
    dplyr::mutate(
      outcome_positive = as.numeric(.data$outcome_positive),
      outcome_negative = as.numeric(.data$outcome_negative),
      total = as.numeric(.data$total)
    )

  result
}

make_hrhpv_contingency_table <- function(counts = read_hrhpv_counts()) {
  count_totals_match <- counts$outcome_positive + counts$outcome_negative ==
    counts$total

  if (!all(count_totals_match)) {
    bad_groups <- counts$group[!count_totals_match]

    stop(
      "Outcome positive + outcome negative does not equal total for: ",
      paste(bad_groups, collapse = ", ")
    )
  }

  contingency_table <- counts |>
    dplyr::select(
      outcome_positive,
      outcome_negative
    ) |>
    as.matrix()

  rownames(contingency_table) <- counts$group
  colnames(contingency_table) <- c("HR-HPV positive", "HR-HPV negative")

  result <- contingency_table
  result
}

run_hrhpv_chi_square <- function(
  counts = read_hrhpv_counts(),
  correct = FALSE
) {
  contingency_table <- make_hrhpv_contingency_table(counts)
  chi_square_test <- stats::chisq.test(contingency_table, correct = correct)

  summary_table <- tibble::tibble(
    test_name = "Pearson chi-square",
    statistic = unname(chi_square_test$statistic),
    degrees_freedom = unname(chi_square_test$parameter),
    p_value = chi_square_test$p.value,
    continuity_correction = correct
  )

  result <- list(
    counts = counts,
    contingency_table = contingency_table,
    test = chi_square_test,
    summary_table = summary_table,
    expected_counts = chi_square_test$expected,
    residuals = chi_square_test$residuals
  )

  result
}

run_hrhpv_pairwise_chi_square <- function(
  counts = read_hrhpv_counts(),
  comparisons = NULL,
  correct = FALSE,
  p_adjust_method = "holm"
) {
  if (is.null(comparisons)) {
    comparisons <- utils::combn(counts$group, 2, simplify = FALSE)
  }

  pairwise_rows <- lapply(
    comparisons,
    function(group_pair) {
      pair_counts <- counts |>
        dplyr::filter(.data$group %in% group_pair) |>
        dplyr::arrange(match(.data$group, group_pair))

      if (nrow(pair_counts) != 2) {
        stop(
          "Each pairwise comparison must match exactly two groups: ",
          paste(group_pair, collapse = " vs ")
        )
      }

      contingency_table <- make_hrhpv_contingency_table(pair_counts)
      chi_square_test <- stats::chisq.test(
        contingency_table,
        correct = correct
      )

      tibble::tibble(
        comparison = paste(group_pair, collapse = " vs "),
        group_1 = group_pair[[1]],
        group_2 = group_pair[[2]],
        statistic = unname(chi_square_test$statistic),
        degrees_freedom = unname(chi_square_test$parameter),
        p_value = chi_square_test$p.value,
        continuity_correction = correct
      )
    }
  )

  summary_table <- dplyr::bind_rows(pairwise_rows)
  adjusted_p_values <- stats::p.adjust(
    summary_table$p_value,
    method = p_adjust_method
  )

  summary_table <- summary_table |>
    dplyr::mutate(
      p_adjust_method = p_adjust_method,
      p_value_adjusted = adjusted_p_values
    )

  result <- summary_table
  result
}

run_csv_analysis <- function() {
  counts <- read_hrhpv_counts()

  result <- list(
    overall_chi_square = run_hrhpv_chi_square(counts),
    pairwise_chi_square = run_hrhpv_pairwise_chi_square(counts)
  )

  result
}

script_file_args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
is_direct_script_run <- length(script_file_args) > 0 &&
  basename(sub("^--file=", "", script_file_args[[1]])) == "csv-analysis.r"

if (is_direct_script_run) {
  analysis_result <- run_csv_analysis()

  print(analysis_result$overall_chi_square$contingency_table)
  print(analysis_result$overall_chi_square$summary_table)
  print(analysis_result$pairwise_chi_square)
}
