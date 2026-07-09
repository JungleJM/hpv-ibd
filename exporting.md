# Exporting QMD Drafts

From the repo root, run:

```sh
Rscript scripts/publish_qmd.R "qmd/your-draft.qmd"
```

For this draft:

```sh
Rscript scripts/publish_qmd.R "qmd/IBD and Anal Cancer, and Relations to HPV, Perianal Disease.qmd"
```

The script reads the QMD YAML `format:` block and renders the declared outputs to:

```text
publish/html/
publish/pdf/
publish/docx/
```

It also reads the QMD `bibliography:` field and copies the `.bib` file plus cited Better BibTeX `file = {...}` attachments to:

```text
publish/references/
```

The manifest is written to:

```text
publish/references/references-manifest.csv
```
