#!/usr/bin/env Rscript

supported_formats <- c("html", "pdf", "docx")

usage <- function() {
  cat(
    paste(
      "Usage:",
      "  Rscript .research-template/scripts/publish_qmd.R path/to/document.qmd",
      "  Rscript scripts/publish_qmd.R path/to/document.qmd",
      "",
      "Outputs:",
      "  publish/html/",
      "  publish/pdf/",
      "  publish/docx/",
      "  publish/references/",
      "",
      "The script reads the QMD YAML to determine which of html, pdf, and docx",
      "formats to render. It also reads the YAML bibliography field, copies the",
      "bibliography file into publish/references, and copies cited attachment files",
      "from Better BibTeX file fields into publish/references.",
      sep = "\n"
    )
  )
}

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
if (length(script_arg) == 0) {
  stop("Could not determine script path. Run with Rscript scripts/publish_qmd.R.", call. = FALSE)
}

script_path <- normalizePath(sub("^--file=", "", script_arg[1]), mustWork = TRUE)
script_dir <- dirname(script_path)
args <- commandArgs(trailingOnly = TRUE)

if (length(args) > 0 && args[1] %in% c("-h", "--help")) {
  usage()
  quit(status = 0)
}

find_repo_root <- function(start_dir) {
  git_root <- suppressWarnings(system2(
    "git",
    c("-C", shQuote(start_dir), "rev-parse", "--show-toplevel"),
    stdout = TRUE,
    stderr = FALSE
  ))

  if (length(git_root) > 0 && nzchar(git_root[1])) {
    return(normalizePath(git_root[1], mustWork = TRUE))
  }

  if (basename(script_dir) == "scripts") {
    return(normalizePath(file.path(script_dir, ".."), mustWork = TRUE))
  }

  normalizePath(getwd(), mustWork = TRUE)
}

find_default_qmd <- function(repo_root) {
  qmd_dir <- file.path(repo_root, "qmd")
  if (!dir.exists(qmd_dir)) {
    return(character())
  }

  list.files(qmd_dir, pattern = "\\.qmd$", full.names = TRUE, recursive = FALSE)
}

if (length(args) == 0) {
  default_root <- find_repo_root(getwd())
  qmd_candidates <- find_default_qmd(default_root)

  if (length(qmd_candidates) != 1) {
    usage()
    stop(
      "Pass a QMD path explicitly. Could not infer exactly one QMD in qmd/.",
      call. = FALSE
    )
  }

  qmd_file <- normalizePath(qmd_candidates[1], mustWork = TRUE)
} else {
  qmd_file <- normalizePath(args[1], mustWork = TRUE)
}

repo_root <- find_repo_root(dirname(qmd_file))
qmd_input <- normalizePath(qmd_file, mustWork = TRUE)
qmd_rel <- sub(
  paste0("^", gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", repo_root), "/?"),
  "",
  qmd_input
)

publish_dir <- file.path(repo_root, "publish")
references_dir <- file.path(publish_dir, "references")
dir.create(references_dir, recursive = TRUE, showWarnings = FALSE)
unlink(file.path(references_dir, "files-manifest.csv"), force = TRUE)

read_front_matter <- function(path) {
  lines <- readLines(path, warn = FALSE)
  if (length(lines) < 3 || trimws(lines[1]) != "---") {
    return(character())
  }

  end <- which(trimws(lines[-1]) == "---")[1] + 1L
  if (is.na(end)) {
    return(character())
  }

  lines[2:(end - 1L)]
}

strip_quotes <- function(value) {
  trimws(gsub('^["\']|["\']$', "", trimws(value)))
}

yaml_scalar <- function(front_matter, key) {
  pattern <- paste0("^", key, "\\s*:\\s*(.*)$")
  match <- grep(pattern, front_matter, value = TRUE)
  if (length(match) == 0) {
    return(character())
  }

  value <- sub(pattern, "\\1", match[1])
  if (!nzchar(trimws(value))) {
    return(character())
  }

  strip_quotes(value)
}

yaml_list_block <- function(front_matter, key) {
  start <- grep(paste0("^", key, "\\s*:\\s*$"), front_matter)
  if (length(start) == 0) {
    return(character())
  }

  start <- start[1]
  if (start >= length(front_matter)) {
    return(character())
  }

  following <- front_matter[(start + 1L):length(front_matter)]
  end <- grep("^[A-Za-z0-9_-]+\\s*:", following)[1]
  if (!is.na(end)) {
    following <- following[seq_len(end - 1L)]
  }

  following
}

detect_formats <- function(front_matter) {
  scalar <- yaml_scalar(front_matter, "format")

  if (length(scalar) > 0) {
    if (grepl("^\\[", scalar)) {
      values <- gsub("^\\[|\\]$", "", scalar)
      formats <- trimws(strsplit(values, ",")[[1]])
    } else {
      formats <- scalar
    }

    return(intersect(formats, supported_formats))
  }

  block <- yaml_list_block(front_matter, "format")
  formats <- sub("^\\s{2}([A-Za-z0-9_-]+)\\s*:.*$", "\\1", block)
  formats <- formats[formats %in% supported_formats]
  unique(formats)
}

detect_bibliography <- function(front_matter, qmd_file) {
  scalar <- yaml_scalar(front_matter, "bibliography")

  if (length(scalar) > 0) {
    return(normalizePath(file.path(dirname(qmd_file), scalar), mustWork = TRUE))
  }

  block <- yaml_list_block(front_matter, "bibliography")
  bibs <- trimws(sub("^\\s*-\\s*", "", block))
  bibs <- strip_quotes(bibs)
  bibs <- bibs[nzchar(bibs)]

  if (length(bibs) == 0) {
    return(character())
  }

  normalizePath(file.path(dirname(qmd_file), bibs), mustWork = TRUE)
}

safe_name <- function(path) {
  gsub("[^A-Za-z0-9._ -]+", "_", basename(path))
}

copy_rendered_files <- function(render_dir, target_dir, format) {
  files <- list.files(render_dir, pattern = paste0("\\.", format, "$"), full.names = TRUE)

  if (length(files) == 0) {
    stop(sprintf("No .%s output found in render directory: %s", format, render_dir), call. = FALSE)
  }

  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
  copied <- file.copy(files, file.path(target_dir, basename(files)), overwrite = TRUE)

  if (!all(copied)) {
    stop(sprintf("Could not copy all .%s outputs to: %s", format, target_dir), call. = FALSE)
  }
}

extract_cited_keys <- function(qmd_file) {
  qmd_lines <- readLines(qmd_file, warn = FALSE)
  matches <- gregexpr("@[-A-Za-z0-9_:.]+", qmd_lines, perl = TRUE)
  keys <- unique(unlist(regmatches(qmd_lines, matches), use.names = FALSE))
  keys <- sub("^@", "", keys)
  keys[nzchar(keys)]
}

read_bib_entries <- function(bib_file) {
  bib_lines <- readLines(bib_file, warn = FALSE)
  starts <- grep("^@[A-Za-z]+\\{", bib_lines)

  if (length(starts) == 0) {
    return(list())
  }

  ends <- c(starts[-1] - 1L, length(bib_lines))
  entries <- list()

  for (i in seq_along(starts)) {
    block <- bib_lines[starts[i]:ends[i]]
    key <- sub("^@[A-Za-z]+\\{([^,]+),.*$", "\\1", block[1])
    entries[[key]] <- block
  }

  entries
}

file_field_paths <- function(entry_block) {
  file_line <- grep("^\\s*file\\s*=", entry_block, value = TRUE)
  if (length(file_line) == 0) {
    return(character())
  }

  value <- sub("^\\s*file\\s*=\\s*\\{(.*)\\}\\s*,?\\s*$", "\\1", file_line[1])
  paths <- trimws(strsplit(value, ";", fixed = TRUE)[[1]])
  paths[nzchar(paths)]
}

copy_reference_files <- function(qmd_file, bib_files, references_dir) {
  cited_keys <- extract_cited_keys(qmd_file)
  manifest <- data.frame(
    citation_key = character(),
    source = character(),
    destination = character(),
    status = character(),
    stringsAsFactors = FALSE
  )

  if (length(bib_files) == 0) {
    write.csv(manifest, file.path(references_dir, "references-manifest.csv"), row.names = FALSE)
    return(invisible(manifest))
  }

  for (bib_file in bib_files) {
    invisible(file.copy(
      bib_file,
      file.path(references_dir, basename(bib_file)),
      overwrite = TRUE
    ))
  }

  entries <- list()
  for (bib_file in bib_files) {
    entries <- c(entries, read_bib_entries(bib_file))
  }

  for (key in cited_keys) {
    block <- entries[[key]]

    if (is.null(block)) {
      manifest <- rbind(manifest, data.frame(
        citation_key = key,
        source = NA_character_,
        destination = NA_character_,
        status = "citation key not found in bibliography",
        stringsAsFactors = FALSE
      ))
      next
    }

    sources <- file_field_paths(block)

    if (length(sources) == 0) {
      manifest <- rbind(manifest, data.frame(
        citation_key = key,
        source = NA_character_,
        destination = NA_character_,
        status = "no file field",
        stringsAsFactors = FALSE
      ))
      next
    }

    existing_sources <- sources[file.exists(sources)]

    if (length(existing_sources) == 0) {
      manifest <- rbind(manifest, data.frame(
        citation_key = key,
        source = paste(sources, collapse = "; "),
        destination = NA_character_,
        status = "file path not found",
        stringsAsFactors = FALSE
      ))
      next
    }

    pdf_sources <- existing_sources[tolower(tools::file_ext(existing_sources)) == "pdf"]
    if (length(pdf_sources) > 0) {
      existing_sources <- pdf_sources
    }

    for (source in existing_sources) {
      destination <- file.path(references_dir, paste0(key, " - ", safe_name(source)))
      copied <- file.copy(source, destination, overwrite = TRUE)
      manifest <- rbind(manifest, data.frame(
        citation_key = key,
        source = source,
        destination = destination,
        status = if (copied) "copied" else "copy failed",
        stringsAsFactors = FALSE
      ))
    }
  }

  write.csv(manifest, file.path(references_dir, "references-manifest.csv"), row.names = FALSE)
  invisible(manifest)
}

front_matter <- read_front_matter(qmd_file)
formats <- detect_formats(front_matter)

if (length(formats) == 0) {
  stop("No supported formats found in QMD YAML. Supported formats: html, pdf, docx.", call. = FALSE)
}

bib_files <- detect_bibliography(front_matter, qmd_file)

render_root <- file.path(publish_dir, ".render")
unlink(render_root, recursive = TRUE, force = TRUE)
dir.create(render_root, recursive = TRUE, showWarnings = FALSE)

old_wd <- setwd(repo_root)
on.exit(setwd(old_wd), add = TRUE)

for (format in formats) {
  render_dir <- file.path(render_root, format)
  target_dir <- file.path(publish_dir, format)
  dir.create(render_dir, recursive = TRUE, showWarnings = FALSE)

  status <- system2(
    "quarto",
    c("render", shQuote(qmd_rel), "--to", format, "--output-dir", shQuote(render_dir))
  )

  if (!identical(status, 0L)) {
    stop(sprintf("Quarto render failed for format: %s", format), call. = FALSE)
  }

  copy_rendered_files(render_dir, target_dir, format)
}

copy_reference_files(qmd_file, bib_files, references_dir)
unlink(render_root, recursive = TRUE, force = TRUE)

message("Rendered formats: ", paste(formats, collapse = ", "))
message("Published outputs to: ", publish_dir)
message("Copied bibliography and cited references to: ", references_dir)
