# Research Stack

This repo uses a reusable R package stack for Quarto-based research drafts, tables, graphs, common statistical tests, Excel/CSV data, screenshots, and Zotero-backed bibliography work.

## Install Command

```sh
./install-research-stack.sh
```

Equivalent direct R command:

```sh
Rscript scripts/install_research_stack.R
```

## Package Groups

Reference packages copied from `nasal-mast-cells` source usage:

- `tidyverse`, `here`, `DT`, `htmltools`, `lme4`, `Seurat`, `SeuratObject`

Quarto / R Markdown:

- `quarto`, `rmarkdown`, `knitr`, `tinytex`, `bslib`, `downlit`, `xml2`

Data import/export:

- `readxl`, `writexl`, `openxlsx`, `janitor`, `fs`

Statistics:

- `rstatix`, `epitools`, `epiR`, `oddsratio`, `emmeans`, `broom`, `broom.helpers`, `effectsize`, `DescTools`, `vcd`, `coin`, `exact2x2`, `PMCMRplus`

Tables:

- `gt`, `gtsummary`, `flextable`, `officer`, `kableExtra`, `reactable`, `formattable`

Graphs and publication figures:

- `ggpubr`, `patchwork`, `cowplot`, `ggrepel`, `ggtext`, `viridis`, `RColorBrewer`, `paletteer`

Screenshots and images:

- `webshot2`, `magick`, `png`

Bibliographies / Zotero:

- `RefManageR`, `bib2df`, `c2z`, `remotes`

`RefManageR::ReadZotero()` is the main supported path for pulling bibliography records from Zotero user or group libraries into R.

## Commands Run

```sh
git clone ssh://git@appliedsci.tail90eacc.ts.net:411/gitea_admin/nasal-mast-cells.git /tmp/nasal-mast-cells.FafXGr
git clone ssh://git@appliedsci.tail90eacc.ts.net:411/gitea_admin/hpv-ibd.git .
Rscript scripts/install_research_stack.R
Rscript -e 'tinytex::install_tinytex()'
chmod +x install-research-stack.sh
git add scripts/install_research_stack.R install-research-stack.sh docs/research-stack.md
git commit -m "Add reusable research R package stack"
git push origin main
```
