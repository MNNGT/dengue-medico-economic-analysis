
# Dengue Epidemiological Surveillance Dashboard

An interactive epidemiological surveillance dashboard developed with R Shiny.

This application demonstrates reproducible data management, automated quality control, descriptive epidemiological analysis, and interactive data visualization.

**All datasets are entirely synthetic.**

## Features

### Overview

- Interactive comparison of epidemiological periods P1, P2 and P3.
- Selection of five surveillance indicators.
- Weekly epidemic curves aligned by relative week.
- Calendar-time visualizations.
- Key epidemiological indicators (KPIs).
- Interactive filtering by study period and week range.

### Comparisons

- Comparison of average weekly activity between periods.
- Descriptive statistics: totals, weekly means and peaks.
- CSV export of filtered data.
- CSV export of statistical summaries.
- High-resolution PNG export of epidemiological curves.

### Data Quality

Eight automated validation checks covering:

- Required variables.
- Missing values.
- Date validity.
- Relative epidemiological weeks.
- Non-negative surveillance indicators.
- Integer-valued counts.
- Duplicate period-week combinations.
- Expected study-period coverage.

## Data

The application uses:

`data/epidemiology_relative_weeks_synthetic.csv`

This dataset was generated using the synthetic R workflows available in the main repository.

Study periods:

| Period | Duration |
|---|---:|
| P1 — Baseline 2022–2023 | 47 weeks |
| P2 — Epidemic scenario 2023–2024 | 47 weeks |
| P3 — Reference 2025 | 31 weeks |

These are illustrative analytical periods, not official epidemic boundaries.

## Technologies

- R
- Shiny
- ggplot2
- Git and GitHub

## Running the Application Locally

Install the required R packages if necessary:

```r
install.packages(c("shiny", "ggplot2"))
```

From the repository root in RStudio:

```r
shiny::runApp("shiny")
```

Alternatively, open `shiny/app.R` in RStudio and select **Run App**.

## Methodological Limitations

- All observations are synthetic.
- Healthcare encounters do not necessarily represent unique individuals.
- Surveillance indicators have different definitions and should not be treated as interchangeable.
- Comparisons between periods are descriptive rather than causal.
- P3 is shorter than P1 and P2; weekly averages facilitate comparisons.
- The application is not an official Santé publique France publication.

## Project

Part of the [Dengue Medico-Economic Analysis](https://github.com/MNNGT/dengue-medico-economic-analysis) research portfolio.

The repository also contains nine R analytical scripts, scientific figures, technical documentation, and a Quarto research report.
