# Bibliography Guide

This project uses Zotero with Better BibTeX to maintain an auto-updating bibliography file that Quarto can cite from. The current bibliography export is:

```text
data/biblio/IBD Anal Cancer.bib
```

## Goal

Use Zotero as the source of truth for references, let Better BibTeX keep the `.bib` file updated, and point Quarto documents at that `.bib` file.

This gives us:

- Stable Better BibTeX citation keys.
- A project-local bibliography file for reproducible Quarto rendering.
- `file = {...}` attachment paths that can later be used to copy cited PDFs into a `publish/papers/` folder.

## Zotero Setup

1. Install Zotero.
2. Install Better BibTeX for Zotero: <https://retorque.re/zotero-better-bibtex/>
3. In Zotero, create or use a project collection, for example `IBD Anal Cancer`.
4. Add manuscript references to that collection.
5. Right-click the Zotero collection and choose `Export Collection...`.
6. Choose the `Better BibTeX` export format.
7. Save the export to:

```text
data/biblio/IBD Anal Cancer.bib
```

8. Enable `Keep updated` during export.

With `Keep updated`, Zotero/Better BibTeX updates this `.bib` file when the collection changes. It does not copy PDFs into the repository by itself. The `.bib` file only records file paths such as:

```bibtex
file = {/Users/jmath/Zotero/storage/.../Paper title.pdf}
```

Those paths are enough for a future publish script to copy only cited PDFs into a publish folder.

## Better BibTeX Export Settings

In Zotero:

```text
Settings/Preferences -> Better BibTeX -> Export
```

Make sure the exported fields include `file`. If there is a setting such as `Fields to omit from export`, do not include `file` there.

Other fields such as `abstract`, `langid`, or `copyright` are optional. Keeping `file` is the important part for later document grabbing.

## Quarto YAML

QMD files in this project live in `qmd/`, so the bibliography path is relative to that folder.

Use this in each QMD:

```yaml
bibliography: "../data/biblio/IBD Anal Cancer.bib"
```

The quotes matter. Without quotes, Positron's visual citation picker may not recognize the file path correctly because the filename contains spaces.

Example:

```yaml
---
title: "High-Risk HPV and Anal Cancer amongst IBD Patients"
format:
  html:
    toc: false
bibliography: "../data/biblio/IBD Anal Cancer.bib"
---
```

An alternative is to rename the file to avoid spaces:

```text
data/biblio/ibd-anal-cancer.bib
```

Then use:

```yaml
bibliography: "../data/biblio/ibd-anal-cancer.bib"
```

## Citation Keys

The older local `qmd/references.bib` file used shorter keys such as:

```markdown
[@albuquerque2023]
[@slesser2013]
```

The Better BibTeX export uses keys such as:

```markdown
[@albuquerqueAnalHighriskHuman2023]
[@slesserSystematicReviewAnal2013]
```

Prefer the Better BibTeX keys from `data/biblio/IBD Anal Cancer.bib`. Mixing old and new keys can create duplicate-looking references and makes later PDF collection less clean.

How to tell which key is the Better BibTeX key:

- Open `data/biblio/IBD Anal Cancer.bib`.
- Look at the entry name immediately after the entry type.
- For example, in this entry:

```bibtex
@article{albuquerqueAnalHighriskHuman2023,
```

the Better BibTeX citation key is:

```markdown
[@albuquerqueAnalHighriskHuman2023]
```

In the Positron citation picker, the safest choice for this workflow is the entry that matches the key in `data/biblio/IBD Anal Cancer.bib`. In your current setup, the older shorter keys such as `albuquerque2023` appear with a small `Z`, which indicates they are coming from live Zotero rather than from the exported Better BibTeX bibliography file.

If you are unsure which citation to choose:

1. Search the title or author in the picker.
2. Compare the shown citation key to the key in `data/biblio/IBD Anal Cancer.bib`.
3. Choose the matching Better BibTeX key.

Using the Better BibTeX key matters because it keeps the QMD citation, exported `.bib` metadata, and `file = {...}` PDF attachment path tied to the same record.

## Positron Visual Citation Picker

With the quoted bibliography path, Positron Visual mode currently works with this system.

The picker may show two kinds of results:

- Entries from the document `.bib` file.
- Live Zotero entries, marked with a small `Z`.

That is expected. The document `.bib` entries are the safest ones for this workflow because they correspond to the Better BibTeX auto-export and include the `file = {...}` attachment paths.

If a citation only appears as a Zotero result, add the item to the Zotero project collection and let Better BibTeX update `data/biblio/IBD Anal Cancer.bib`.

## Can Live Zotero Results Be Removed From The Picker?

Maybe partially, but there does not appear to be a clean per-document switch that says "only show bibliography entries and never show Zotero entries."

Positron/Quarto visual editing integrates directly with Zotero. The Quarto documentation says Zotero items appear alongside bibliography items with a small `Z` marker, and items inserted from Zotero can be added to the bibliography. Positron exposes citation-related options such as the Zotero library location, Zotero data directory, libraries to use, and whether to use Better BibTeX for citation keys/export.

Practical options:

- Leave Zotero results enabled. This is useful when searching outside the current project collection.
- Prefer non-`Z` bibliography results when you want to cite only from the exported project `.bib`.
- Check Positron settings for `Quarto`, `Zotero`, or `R Markdown -> Citations` options if the duplicated results become distracting.
- Avoid selecting live Zotero entries unless you are comfortable with Positron modifying the bibliography file.

References:

- Positron Visual Editor Zotero docs: <https://quarto.org/docs/tools/positron/visual-editor.html>
- Quarto Visual Editor citation options: <https://quarto.org/docs/visual-editor/options.html>

## Optional Source-Mode Citation Plugins

The built-in Positron Visual mode picker is currently enough for this project. Optional plugins may be useful if source-mode citation insertion becomes important.

### jinvim.vscode-zotero

Marketplace page: <https://marketplace.visualstudio.com/items?itemName=jinvim.vscode-zotero>

Summary:

- VS Code/Positron-style extension.
- Requires Zotero and Better BibTeX.
- Supports Quarto and LaTeX.
- Searches Zotero and inserts citations from a command/shortcut.
- Adds selected entries to the project `.bib` file.
- Detects the bibliography path from Quarto or LaTeX headers, then falls back to common files such as `bibliography.bib` or `references.bib`.
- Includes commands to open the PDF, Zotero entry, or DOI for a citation.
- Includes a `tidyBib` command that can add missing entries, remove unused entries, and sort the `.bib` file, while creating a backup.

Strengths:

- Most feature-complete for a Quarto + Zotero + Better BibTeX workflow.
- Explicitly designed to write both the in-text citation and the `.bib` entry.
- Has Open VSX availability for VS Code forks.
- Does not appear to be a small fork of the older `mblode` extension; it is its own TypeScript extension inspired by another Zotero workflow.

Risks:

- Relatively young and smaller-maintainer project.
- The author notes limited time and that Windows/Linux testing may be limited.
- It modifies `.bib` files directly. That can conflict with a Better BibTeX `Keep updated` export if both tools write to the same file.
- Its `tidyBib` command could remove intentionally retained references if used without checking the backup.

Project recommendation:

Try this first if you want source-mode citation insertion. Do not immediately use `tidyBib` on the Better BibTeX auto-export file until you have confirmed it preserves the fields you care about, especially `file`.

### mvuorre/zotero-citation-picker

Open VSX page: <https://open-vsx.org/extension/mvuorre/zotero-citation-picker>

Author's guide: <https://vuorre.com/posts/zotero-positron-vscode/>

Summary:

- Positron/VS Code extension forked from the `mblode/vscode-zotero` citation picker.
- Intended specifically for Quarto/Positron source-mode citation insertion.
- Uses Zotero and Better BibTeX.
- Adds the citation to the QMD and writes the selected reference to the document's associated `.bib` file.
- Supports search patterns such as `author:jaynes` according to the author's guide.

Strengths:

- Very directly aimed at the exact problem: source-mode citation insertion in Positron/Quarto.
- Simpler and likely easier to reason about than a broader extension.
- The author's guide explicitly describes the desired QMD + `.bib` workflow.

Risks:

- It is a fork, so long-term maintenance is uncertain.
- The author notes the change was submitted as a pull request upstream; if upstream later implements similar functionality, this fork could become redundant or drift.
- Smaller surface area than `jinvim.vscode-zotero`; fewer extra management features.
- Like any tool that writes `.bib` files, it may conflict with Better BibTeX auto-export if both write to the same file.

Project recommendation:

Worth testing if you want a focused source-mode picker with good author/search behavior. Treat it as optional convenience tooling, not the source of truth. Zotero + Better BibTeX auto-export should remain the source of truth.

## Recommended Current Workflow

1. Add papers to Zotero.
2. Add them to the `IBD Anal Cancer` Zotero collection.
3. Let Better BibTeX auto-update:

```text
data/biblio/IBD Anal Cancer.bib
```

4. In QMD files, use:

```yaml
bibliography: "../data/biblio/IBD Anal Cancer.bib"
```

5. Insert citations in Visual mode, preferring entries that come from the `.bib` file.
6. Use Better BibTeX citation keys consistently.
7. Consider `jinvim.vscode-zotero` or `mvuorre/zotero-citation-picker` only if source-mode citation insertion becomes important.
