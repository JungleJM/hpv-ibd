#!/usr/bin/env Rscript

options(
  repos = c(CRAN = "https://cloud.r-project.org"),
  install.packages.compile.from.source = "never"
)

cran_packages <- c(
  # Reference repo dependencies from nasal-mast-cells
  "tidyverse",
  "here",
  "DT",
  "htmltools",
  "lme4",
  "Seurat",
  "SeuratObject",

  # Quarto / R Markdown authoring
  "quarto",
  "rmarkdown",
  "knitr",
  "tinytex",
  "bslib",
  "downlit",
  "xml2",

  # Data import/export
  "readxl",
  "writexl",
  "openxlsx",
  "janitor",
  "fs",

  # Statistics for draft analyses
  "rstatix",
  "epitools",
  "epiR",
  "oddsratio",
  "emmeans",
  "broom",
  "broom.helpers",
  "effectsize",
  "DescTools",
  "vcd",
  "coin",
  "exact2x2",
  "PMCMRplus",

  # Tables
  "gt",
  "gtsummary",
  "flextable",
  "officer",
  "kableExtra",
  "reactable",
  "formattable",

  # Graphs and publication figures
  "ggpubr",
  "patchwork",
  "cowplot",
  "ggrepel",
  "ggtext",
  "viridis",
  "RColorBrewer",
  "paletteer",

  # Screenshots and image handling
  "webshot2",
  "magick",
  "png",

  # Bibliographies / Zotero
  "RefManageR",
  "bib2df",
  "c2z",
  "remotes"
)

installed <- rownames(installed.packages())
missing <- setdiff(cran_packages, installed)

cat("CRAN mirror:", getOption("repos")[["CRAN"]], "\n")
cat("Requested packages:", length(cran_packages), "\n")
cat("Already installed:", length(intersect(cran_packages, installed)), "\n")
cat("Missing:", length(missing), "\n")

if (length(missing) > 0) {
  install.packages(missing, dependencies = TRUE)
} else {
  cat("All requested CRAN packages are already installed.\n")
}

remaining_missing <- setdiff(cran_packages, rownames(installed.packages()))

if (length(remaining_missing) > 0) {
  cat("\nPackages still missing after install attempt:\n")
  cat(paste0("- ", remaining_missing), sep = "\n")
  quit(status = 1)
}

cat("\nResearch R package stack is installed.\n")
