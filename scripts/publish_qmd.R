#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)

if (length(script_arg) == 0) {
  stop("Could not determine script path. Run with Rscript scripts/publish_qmd.R.", call. = FALSE)
}

script_path <- normalizePath(sub("^--file=", "", script_arg[1]), mustWork = TRUE)
repo_root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)

qmd_file <- file.path(
  repo_root,
  "qmd",
  "IBD and Anal Cancer, and Relations to HPV, Perianal Disease.qmd"
)
qmd_input <- file.path(
  "qmd",
  "IBD and Anal Cancer, and Relations to HPV, Perianal Disease.qmd"
)

publish_dir <- file.path(repo_root, "publish")
reference_dir <- file.path(publish_dir, "references")
dir.create(reference_dir, recursive = TRUE, showWarnings = FALSE)

formats <- c("html", "pdf", "docx")
old_wd <- setwd(repo_root)
on.exit(setwd(old_wd), add = TRUE)

for (format in formats) {
  out_dir <- file.path("..", "publish", format)
  dir.create(file.path(publish_dir, format), recursive = TRUE, showWarnings = FALSE)

  status <- system2(
    "quarto",
    c("render", shQuote(qmd_input), "--to", format, "--output-dir", shQuote(out_dir))
  )

  if (!identical(status, 0L)) {
    stop(sprintf("Quarto render failed for format: %s", format), call. = FALSE)
  }

  unlink(file.path(publish_dir, format, "figures"), recursive = TRUE, force = TRUE)
}

qmd_lines <- readLines(qmd_file, warn = FALSE)
bib_line <- grep("^bibliography:\\s*", qmd_lines, value = TRUE)

if (length(bib_line) == 0) {
  stop("No bibliography field found in QMD YAML.", call. = FALSE)
}

bib_rel <- sub("^bibliography:\\s*", "", bib_line[1])
bib_rel <- trimws(gsub('^["\']|["\']$', "", bib_rel))
bib_file <- normalizePath(file.path(dirname(qmd_file), bib_rel), mustWork = TRUE)

invisible(file.copy(
  bib_file,
  file.path(reference_dir, basename(bib_file)),
  overwrite = TRUE
))

citation_matches <- gregexpr("@[-A-Za-z0-9_:.]+", qmd_lines, perl = TRUE)
cited_keys <- unique(unlist(regmatches(qmd_lines, citation_matches), use.names = FALSE))
cited_keys <- sub("^@", "", cited_keys)
cited_keys <- cited_keys[nzchar(cited_keys)]

bib_lines <- readLines(bib_file, warn = FALSE)
entry_starts <- grep("^@[A-Za-z]+\\{", bib_lines)
entry_ends <- c(entry_starts[-1] - 1L, length(bib_lines))

entries <- list()
for (i in seq_along(entry_starts)) {
  block <- bib_lines[entry_starts[i]:entry_ends[i]]
  key <- sub("^@[A-Za-z]+\\{([^,]+),.*$", "\\1", block[1])
  entries[[key]] <- block
}

manifest <- data.frame(
  citation_key = character(),
  source = character(),
  destination = character(),
  status = character(),
  stringsAsFactors = FALSE
)

safe_name <- function(path) {
  name <- basename(path)
  gsub("[^A-Za-z0-9._ -]+", "_", name)
}

for (key in cited_keys) {
  block <- entries[[key]]

  if (is.null(block)) {
    manifest <- rbind(
      manifest,
      data.frame(
        citation_key = key,
        source = NA_character_,
        destination = NA_character_,
        status = "citation key not found in bibliography",
        stringsAsFactors = FALSE
      )
    )
    next
  }

  file_line <- grep("^\\s*file\\s*=", block, value = TRUE)

  if (length(file_line) == 0) {
    manifest <- rbind(
      manifest,
      data.frame(
        citation_key = key,
        source = NA_character_,
        destination = NA_character_,
        status = "no file field",
        stringsAsFactors = FALSE
      )
    )
    next
  }

  file_value <- sub("^\\s*file\\s*=\\s*\\{(.*)\\}\\s*,?\\s*$", "\\1", file_line[1])
  sources <- trimws(strsplit(file_value, ";", fixed = TRUE)[[1]])
  sources <- sources[nzchar(sources)]
  sources <- sources[file.exists(sources)]

  if (length(sources) == 0) {
    manifest <- rbind(
      manifest,
      data.frame(
        citation_key = key,
        source = file_value,
        destination = NA_character_,
        status = "file path not found",
        stringsAsFactors = FALSE
      )
    )
    next
  }

  pdf_sources <- sources[tolower(tools::file_ext(sources)) == "pdf"]
  if (length(pdf_sources) > 0) {
    sources <- pdf_sources
  }

  for (source in sources) {
    destination <- file.path(reference_dir, paste0(key, " - ", safe_name(source)))
    copied <- file.copy(source, destination, overwrite = TRUE)
    manifest <- rbind(
      manifest,
      data.frame(
        citation_key = key,
        source = source,
        destination = destination,
        status = if (copied) "copied" else "copy failed",
        stringsAsFactors = FALSE
      )
    )
  }
}

write.csv(
  manifest,
  file.path(reference_dir, "references-manifest.csv"),
  row.names = FALSE
)

message("Published outputs to: ", publish_dir)
message("Copied referenced papers to: ", reference_dir)
