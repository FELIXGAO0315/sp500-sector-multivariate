# SP500 Sector Multivariate Analysis

Multivariate analysis of S&P 500 sector returns using PCA and CCA, with a theoretical review of Sparse CCA via the Penalized Matrix Decomposition framework. Duke STA 832 Final Project.

**Authors:** Yuan Gao, Tingzhou Wei, Yijie Huang

---

## Overview

This project consists of two components:

**Part I — Data Project.** We analyze daily log-returns of eleven S&P 500 SPDR sector ETFs (2018–2024) using two classical multivariate techniques:
- **Principal Component Analysis (PCA):** to identify the dominant axes of variation in sector returns and extract interpretable latent factors (market factor, cyclical-defensive spread, energy idiosyncratic factor, interest-rate factor).
- **Canonical Correlation Analysis (CCA):** to quantify the linear relationship between cyclical sectors (Technology, Financials, Industrials, etc.) and defensive sectors (Healthcare, Utilities, Consumer Staples, Real Estate).

We also discuss the appropriateness of these methods given the non-normality and time-series structure of financial return data.

**Part II — Review Project.** We provide a self-contained mathematical review of **Sparse Canonical Correlation Analysis (Sparse CCA)**, covering:
- The Witten–Tibshirani–Hastie (2009) PMD formulation and coordinate ascent algorithm
- Consistency and minimax optimality theory in high dimensions
- Connections to Sparse PCA, Reduced-Rank Regression, the Graphical Lasso, and PLS
- Limitations and directions for future work

---

## Repository Structure

```
sp500-sector-multivariate/
├── final_project.Rmd       # Main report (knit to PDF)
├── final_project.pdf       # Compiled report
└── README.md
```

---

## Data

Data are downloaded automatically at knit time via the [`quantmod`](https://cran.r-project.org/package=quantmod) package from Yahoo Finance. No manual download is required. The eleven sector ETFs used are:

| ETF | Sector | Group |
|-----|--------|-------|
| XLK | Technology | Cyclical |
| XLY | Consumer Discretionary | Cyclical |
| XLF | Financials | Cyclical |
| XLI | Industrials | Cyclical |
| XLB | Materials | Cyclical |
| XLC | Communication Services | Cyclical |
| XLV | Health Care | Defensive |
| XLP | Consumer Staples | Defensive |
| XLU | Utilities | Defensive |
| XLRE | Real Estate | Defensive |
| XLE | Energy | Other |

Sample period: **January 2, 2018 – December 31, 2024** (~1,760 trading days).

---

## Requirements

All analysis is done in **R** via R Markdown. The following packages are required and will be auto-installed if missing:

```r
quantmod, PerformanceAnalytics, corrplot, ggplot2, ggcorrplot,
factoextra, CCA, CCP, MVN, reshape2, dplyr, tidyr,
gridExtra, knitr, kableExtra, xts, zoo, scales, viridis
```

To compile the report:

```r
rmarkdown::render("final_project.Rmd")
```

---

## Methods

| Method | Purpose | R Package |
|--------|---------|-----------|
| PCA | Dimension reduction, factor extraction | base `prcomp` |
| Mardia's Test | Multivariate normality assessment | `MVN` |
| CCA | Cross-group canonical correlations | `CCA` |
| Wilks' Λ Test | Significance of canonical correlations | `CCP` |

---

## Key Results

- **PCA:** The first PC (market factor) explains ~60% of total variance; four PCs together explain ~85%. Each PC has a clear economic interpretation.
- **CCA:** All four canonical correlations between cyclical and defensive sectors are highly significant ($p < 0.001$). The first canonical pair ($\hat{\rho}_1^* \approx 0.93$) captures the broad market factor; the second captures a risk-rotation effect.
- **Sparse CCA:** Under $s$-sparsity assumptions, the SCCA estimator achieves the minimax-optimal rate $O(\sqrt{s \log p / n})$, enabling consistent estimation even when $p \gg n$.

