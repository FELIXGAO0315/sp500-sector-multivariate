# Multivariate Analysis of S&P 500 Sector Returns
### and a Review of Sparse Canonical Correlation Analysis

**STAT Final Project**
*Authors: Yuan Gao, Tingzhou Wei, Yijie Huang*

---

## Overview

This project has two parts, both contained in a single R Markdown document.

**Part I — Data Project.** An empirical multivariate analysis of the daily log-returns of 11 S&P 500 sector ETFs over 2018–2024. We apply Principal Component Analysis (PCA) to recover the factor structure of sector returns, and Canonical Correlation Analysis (CCA) to quantify the linear relationship between *cyclical* and *defensive* sector groups.

**Part II — Review Project.** A theoretical review of **Sparse Canonical Correlation Analysis (SCCA)** following Witten, Tibshirani, and Hastie (2009). We cover the mathematical formulation (the Penalised Matrix Decomposition framework), the coordinate-ascent algorithm, consistency and variable-selection theorems, minimax lower bounds, and connections to sparse PCA, reduced-rank regression, the graphical lasso, and PLS.

---

## File Structure

```
.
├── final_project.Rmd              # Main source — knit this
├── final_project.pdf              # Rendered output (generated)
├── sector_returns_cache.rds       # Auto-generated data cache (binary)
├── sector_returns_cache.csv       # Auto-generated data cache (plain text)
└── README.md                      # This file
```

The two cache files are created automatically on the first knit. You do **not** need to commit or share them — they can be regenerated from the Rmd.

---

## Requirements

### System
- **R** ≥ 4.2.0
- A LaTeX distribution with XeLaTeX (TinyTeX, TeX Live, or MiKTeX all work)
- Internet connection — **first knit only** (see Data Pipeline below)

### R Packages
```r
install.packages(c(
  "quantmod", "PerformanceAnalytics", "corrplot",
  "ggplot2", "ggcorrplot", "CCA", "CCP",
  "reshape2", "dplyr", "tidyr", "gridExtra",
  "knitr", "kableExtra", "xts", "zoo",
  "scales", "viridis"
))
```

The `packages` chunk inside the Rmd also auto-installs any missing packages.

> **Note:** We intentionally avoid `factoextra` (brittle `rlang` dependency), `MVN` (repeated API breakages across versions), and `e1071` (skew/kurt computed manually). All visualisations and tests are implemented in base R + `ggplot2`.

---

## How to Reproduce

1. Clone or download the project folder.
2. Open `final_project.Rmd` in RStudio.
3. Click **Knit** (or run `rmarkdown::render("final_project.Rmd")` from the console).

**Timing.** First knit: ~2–4 minutes (downloads 11 ETFs from Yahoo Finance). Subsequent knits: ~30 seconds (reads local cache).

---

## Data Pipeline

Because Yahoo Finance is a free public API and can be flaky (rate-limiting, transient network errors, schema changes), we use a **three-tier** loading strategy to keep the document reproducible:

1. **Local cache** — if `sector_returns_cache.rds` exists in the working directory, it is loaded directly. No network needed. This is what happens on all knits after the first.
2. **Yahoo Finance download** — if no cache exists, each of the 11 ETFs is fetched independently via `quantmod::getSymbols()` with up to **3 retries** and **exponential back-off**. Successful downloads are merged, cleaned, and saved as both `.rds` (fast binary) and `.csv` (human-readable backup).
3. **Failure diagnostics** — if any ticker still fails after 3 retries, the script halts and prints exactly which ticker(s) failed, so the user can either wait and retry or manually supply a CSV.

### Common data operations

| Goal | Action |
|------|--------|
| Refresh data | Delete `sector_returns_cache.rds` **and** `sector_returns_cache.csv`, then knit |
| Run fully offline | Ensure both cache files are present; that's all |
| Hand-supply data (Yahoo down) | Put a CSV with columns `Date, Technology, Cons.Disc, Financials, Industrials, Materials, HealthCare, Cons.Staples, Utilities, RealEstate, Energy, Comm.Serv` into the working dir as `sector_returns_cache.csv`, then load into R and `saveRDS()` as `sector_returns_cache.rds`. Values must be daily log-returns, not prices. |

---

## Method Summary

### Part I
- **EDA.** Summary statistics, kernel density estimates with *per-sector* normal overlays, correlation heatmap (block-reordered), manual Mardia's multivariate normality test, cumulative return paths, 60-day annualised rolling volatility.
- **PCA.** On the centred covariance matrix. Scree plot + cumulative variance explained, eigenvalue table, loadings heatmap for PC1–PC4, biplot (ggplot2 implementation, coloured by contribution), and PC1/PC2 score trajectories over time.
- **CCA.** Between cyclical sectors (X, $p_1 = 6$) and defensive sectors (Y, $p_2 = 4$), with Energy excluded due to idiosyncratic dynamics. Sequential Wilks' Λ significance tests, canonical loadings, canonical-variate scatter plots, and pre-COVID vs post-COVID sub-period robustness.

### Part II
- Mathematical formulation of SCCA via the Penalised Matrix Decomposition (PMD).
- Coordinate-ascent algorithm with soft-thresholding, convergence analysis, sequential deflation for higher-order pairs.
- Variants: regularised CCA, group-sparse CCA, probabilistic SCCA, SVD regularisation.
- Theoretical properties: $O(\sqrt{s\log p / n})$ consistency (Gao–Ma–Zhou 2015), variable selection consistency (Mai–Zhang 2019), matching minimax lower bounds.
- Connections to sparse PCA, reduced-rank regression, graphical lasso, and PLS.
- Discussion of limitations (non-convexity, tuning, deflation bias, inference).

---

## Troubleshooting

**`rlang 1.1.X required but only 1.1.Y available` (or similar)**
Restart R (RStudio: *Session → Restart R*), then `install.packages("rlang")` *before* loading any other packages, then restart R once more. Re-knit.

**`getSymbols` fails with HTTP errors**
Yahoo is rate-limiting or temporarily down. Wait a few minutes and retry, or hand-supply the CSV as described in the table above.

**`! LaTeX Error: File ... not found` / XeLaTeX missing**
Install TinyTeX from within R:
```r
install.packages("tinytex")
tinytex::install_tinytex()
```

**Every knit is slow (not just the first)**
The cache isn't being created. Check that the working directory is writeable and that no antivirus / sync tool is deleting `.rds` files.

**Mardia test returns `NaN`**
The covariance matrix is singular. This happens if any two sectors are perfectly collinear — check for duplicate columns in `R`.

---

## Repository Hygiene

If you use Git, we recommend a `.gitignore` with at least:

```
# R / RStudio
.Rhistory
.RData
.Ruserdata
.Rproj.user/

# Knitr output
*.log
*.aux
*.out
*.toc
final_project_files/

# Local data cache (regenerated on knit)
sector_returns_cache.rds
sector_returns_cache.csv

# OS
.DS_Store
Thumbs.db
```

---

## References

Full bibliography is in the References section at the end of `final_project.Rmd`. Key works include Witten, Tibshirani, and Hastie (2009), Gao, Ma, and Zhou (2015), Fama and French (1993, 2015), and Bai and Ng (2002).

---

## Academic Integrity

This project was prepared for coursework. All code, figures, and prose are the original work of the authors. All third-party results, datasets, and ideas are cited in the References.