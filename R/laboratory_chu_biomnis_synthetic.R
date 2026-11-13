
# ============================================================
# DENGUE MEDICO-ECONOMIC ANALYSIS
# LABORATORY ACTIVITY - LOCAL VS OUTSOURCED
# SYNTHETIC CHU / BIOMNIS WORKFLOW
# ============================================================

# Author: Marie-Noelle Nogeant
# Year: 2026
#
# Methodological adaptation of laboratory activity analyses
# developed during a public health research internship.
#
# All observations are synthetic.
# No actual CHU or Biomnis data are included.
# ============================================================


# ============================================================
# 1. PACKAGES
# ============================================================

required_packages <- c(
  "dplyr",
  "tidyr",
  "ggplot2",
  "patchwork",
  "readr"
)

missing_packages <- required_packages[
  !vapply(
    required_packages,
    requireNamespace,
    logical(1),
    quietly = TRUE
  )
]

if (length(missing_packages) > 0) {
  stop(
    "Please install the missing packages: ",
    paste(missing_packages, collapse = ", ")
  )
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(patchwork)
  library(readr)
})


# ============================================================
# 2. CONFIGURATION
# ============================================================

SEED_GLOBAL <- 20260424
set.seed(SEED_GLOBAL)

# Identify project directory
project_dir <- getwd()

if (!dir.exists(file.path(project_dir, "R"))) {
  project_dir <- path.expand(
    "~/Documents/dengue-medico-economic-analysis"
  )
}

if (!dir.exists(file.path(project_dir, "R"))) {
  stop(
    "Project directory not found. ",
    "Please set the working directory to the repository root."
  )
}

# Output directories
data_dir <- file.path(
  project_dir,
  "data",
  "simulated",
  "laboratory"
)

tables_dir <- file.path(
  project_dir,
  "outputs",
  "tables"
)

figures_dir <- file.path(
  project_dir,
  "outputs",
  "figures"
)

for (directory in c(
  data_dir,
  tables_dir,
  figures_dir
)) {
  dir.create(
    directory,
    recursive = TRUE,
    showWarnings = FALSE
  )
}


# ============================================================
# 3. STUDY PERIODS
# ============================================================

# Monthly approximations of the original study windows.
# These dates do not reproduce exact epidemiological weeks.

study_periods <- tibble(
  period = c(
    "P1 - Baseline 2022-2023",
    "P2 - Epidemic 2023-2024",
    "P3 - Baseline 2025"
  ),
  start_date = as.Date(c(
    "2022-07-01",
    "2023-07-01",
    "2025-05-01"
  )),
  end_date = as.Date(c(
    "2023-06-30",
    "2024-06-30",
    "2025-11-30"
  ))
)

period_levels <- study_periods$period

# Full monthly observation window
all_months <- seq(
  as.Date("2022-06-01"),
  as.Date("2025-11-01"),
  by = "month"
)

stopifnot(length(all_months) == 42)


# ============================================================
# 4. PERIOD CLASSIFICATION
# ============================================================

classify_period <- function(dates) {
  
  case_when(
    dates >= as.Date("2022-07-01") &
      dates <= as.Date("2023-06-30") ~
      "P1 - Baseline 2022-2023",
    
    dates >= as.Date("2023-07-01") &
      dates <= as.Date("2024-06-30") ~
      "P2 - Epidemic 2023-2024",
    
    dates >= as.Date("2025-05-01") &
      dates <= as.Date("2025-11-30") ~
      "P3 - Baseline 2025",
    
    TRUE ~ "Outside study periods"
  )
}


# ============================================================
# 5. LABORATORY TEST CLASSIFICATION
# ============================================================

# Diagnostic categories adapted from the original workflow

test_types <- c(
  "Serology IgG",
  "Blood PCR",
  "CSF PCR",
  "NS1 antigen"
)

# Main indicators displayed in the original figure
figure_tests <- c(
  "Serology IgG",
  "Blood PCR",
  "NS1 antigen"
)

# Fictional laboratory sources
source_types <- c(
  "Local laboratory (synthetic)",
  "Outsourced laboratory (synthetic)"
)


# ============================================================
# 6. SYNTHETIC DATA GENERATION
# ============================================================

# The synthetic scenario includes:
#
# - Higher testing volumes during the epidemic period.
# - Different local and outsourced testing proportions.
# - Missing PCR observations from September to December 2022.
# - A simulated outsourcing interruption in November 2023.
#
# All parameters are illustrative.

synthetic_data <- expand_grid(
  date = all_months,
  test_type = test_types,
  source = source_types
) %>%
  mutate(
    
    # Study period
    period = classify_period(date),
    
    # Illustrative baseline monthly volumes
    base_monthly = case_when(
      test_type == "Serology IgG" ~ 42,
      test_type == "Blood PCR" ~ 95,
      test_type == "CSF PCR" ~ 8,
      test_type == "NS1 antigen" ~ 28,
      TRUE ~ 0
    ),
    
    # Illustrative share performed locally
    local_share = case_when(
      test_type == "Serology IgG" ~ 0.88,
      test_type == "Blood PCR" ~ 0.72,
      test_type == "CSF PCR" ~ 0.80,
      test_type == "NS1 antigen" ~ 0.90,
      TRUE ~ 0.50
    ),
    
    # Allocation between local and outsourced activity
    source_share = if_else(
      source == source_types[1],
      local_share,
      1 - local_share
    ),
    
    # Illustrative epidemic multiplier
    epidemic_multiplier = if_else(
      period == "P2 - Epidemic 2023-2024",
      2.8,
      1.0
    ),
    
    # Illustrative seasonal variation
    seasonal_multiplier =
      1 + 0.15 * sin(
        2 * pi *
          (as.integer(format(date, "%m")) - 1) /
          12
      ),
    
    # Fictional disruption affecting outsourced activity
    simulated_disruption =
      date == as.Date("2023-11-01") &
      source == source_types[2],
    
    disruption_multiplier = if_else(
      simulated_disruption,
      0.10,
      1.00
    ),
    
    # Expected testing volumes
    expected_volume =
      base_monthly *
      source_share *
      epidemic_multiplier *
      seasonal_multiplier *
      disruption_multiplier *
      runif(n(), 0.85, 1.15),
    
    # Poisson simulation
    generated_tests = rpois(
      n(),
      lambda = expected_volume
    ),
    
    # Missing PCR observations
    missing_data =
      test_type %in% c("Blood PCR", "CSF PCR") &
      date >= as.Date("2022-09-01") &
      date <= as.Date("2022-12-01"),
    
    # Missing data must not become zero observations
    tests = if_else(
      missing_data,
      NA_integer_,
      generated_tests
    )
  ) %>%
  select(
    date,
    period,
    test_type,
    source,
    tests,
    missing_data,
    simulated_disruption
  )


# ============================================================
# 7. DATA GENERATION CHECKS
# ============================================================

stopifnot(
  nrow(synthetic_data) ==
    length(all_months) *
    length(test_types) *
    length(source_types),
  
  all(
    synthetic_data$tests[
      !is.na(synthetic_data$tests)
    ] >= 0
  ),
  
  sum(is.na(synthetic_data$tests)) == 16
)

cat("\n========================================\n")
cat("SYNTHETIC LABORATORY DATA GENERATED\n")
cat("========================================\n")

cat(
  "\nNumber of months:",
  length(all_months),
  "\n"
)

cat(
  "Number of diagnostic categories:",
  length(test_types),
  "\n"
)

cat(
  "Number of laboratory sources:",
  length(source_types),
  "\n"
)

cat(
  "Total synthetic records:",
  nrow(synthetic_data),
  "\n"
)

cat(
  "Missing source-level records:",
  sum(is.na(synthetic_data$tests)),
  "\n"
)


# ============================================================
# 8. MONTHLY AGGREGATION
# ============================================================

# Aggregate local and outsourced laboratory activity.
# If all source observations are missing, retain NA.

monthly_summary <- synthetic_data %>%
  group_by(
    date,
    period,
    test_type
  ) %>%
  summarise(
    
    total_tests = if (
      all(is.na(tests))
    ) {
      NA_integer_
    } else {
      as.integer(
        sum(tests, na.rm = TRUE)
      )
    },
    
    reporting_sources = sum(
      !is.na(tests)
    ),
    
    .groups = "drop"
  ) %>%
  arrange(
    test_type,
    date
  )


# ============================================================
# 9. PERIOD-LEVEL ANALYSIS
# ============================================================

# Calculate observed totals and monthly averages.
# Monthly averages use months with available data.

period_summary <- synthetic_data %>%
  filter(
    period %in% period_levels
  ) %>%
  group_by(
    period,
    test_type,
    source
  ) %>%
  summarise(
    
    expected_months = n(),
    
    observed_months = sum(
      !is.na(tests)
    ),
    
    missing_months = sum(
      is.na(tests)
    ),
    
    total_tests = sum(
      tests,
      na.rm = TRUE
    ),
    
    .groups = "drop"
  ) %>%
  mutate(
    
    mean_monthly_tests = if_else(
      observed_months > 0,
      total_tests / observed_months,
      NA_real_
    ),
    
    coverage_pct = round(
      100 * observed_months / expected_months,
      1
    )
  ) %>%
  arrange(
    period,
    test_type,
    source
  )


# ============================================================
# 10. DATA COMPLETENESS ANALYSIS
# ============================================================

missingness_summary <- synthetic_data %>%
  group_by(
    period,
    test_type,
    source
  ) %>%
  summarise(
    
    expected_months = n(),
    
    missing_months = sum(
      is.na(tests)
    ),
    
    missing_pct = round(
      100 * missing_months / expected_months,
      1
    ),
    
    .groups = "drop"
  )

cat("\nDATA COMPLETENESS SUMMARY\n")

print(
  missingness_summary %>%
    filter(missing_months > 0),
  n = Inf
)


# ============================================================
# 11. PERIOD SUMMARY VERIFICATION
# ============================================================

cat("\n========================================\n")
cat("PERIOD-LEVEL LABORATORY ACTIVITY\n")
cat("========================================\n")

print(
  period_summary,
  n = Inf,
  width = Inf
)

stopifnot(
  nrow(monthly_summary) ==
    length(all_months) * length(test_types),
  
  sum(is.na(monthly_summary$total_tests)) == 8,
  
  nrow(period_summary) == 24,
  
  all(period_summary$observed_months > 0),
  
  all(period_summary$coverage_pct <= 100)
)


# ============================================================
# 12. GRAPHICAL CONFIGURATION
# ============================================================

test_colors <- c(
  "Serology IgG" = "#2E75B6",
  "Blood PCR" = "#217346",
  "NS1 antigen" = "#C55A11"
)

source_colors <- c(
  "Local laboratory (synthetic)" = "#4472C4",
  "Outsourced laboratory (synthetic)" = "#ED7D31"
)

period_colors <- c(
  "P1 - Baseline 2022-2023" = "#DCEAF5",
  "P2 - Epidemic 2023-2024" = "#F6DADA",
  "P3 - Baseline 2025" = "#DDEFD8"
)

theme_scientific <- theme_minimal(
  base_size = 11
) +
  theme(
    plot.title = element_text(
      face = "bold",
      size = 12
    ),
    plot.subtitle = element_text(
      size = 10
    ),
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    ),
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    strip.text = element_text(
      face = "bold"
    )
  )


# ============================================================
# 13. BACKGROUND STUDY PERIODS
# ============================================================

period_bands <- study_periods %>%
  transmute(
    period,
    xmin = start_date,
    xmax = end_date
  )


# ============================================================
# 14. PREPARE MONTHLY FIGURE DATA
# ============================================================

monthly_plot <- monthly_summary %>%
  filter(
    test_type %in% figure_tests
  ) %>%
  arrange(
    test_type,
    date
  ) %>%
  group_by(test_type) %>%
  mutate(
    
    # Separate line segments at missing observations
    line_segment = cumsum(
      is.na(total_tests)
    )
  ) %>%
  ungroup()


# ============================================================
# 15. PANEL A - MONTHLY LABORATORY ACTIVITY
# ============================================================

pA <- ggplot() +
  
  # Highlight study periods
  geom_rect(
    data = period_bands,
    aes(
      xmin = xmin,
      xmax = xmax,
      ymin = -Inf,
      ymax = Inf,
      fill = period
    ),
    alpha = 0.25,
    inherit.aes = FALSE
  ) +
  
  scale_fill_manual(
    values = period_colors,
    guide = "none"
  ) +
  
  # Monthly testing curves
  geom_line(
    data = monthly_plot,
    aes(
      x = date,
      y = total_tests,
      color = test_type,
      group = interaction(
        test_type,
        line_segment
      )
    ),
    linewidth = 0.9,
    na.rm = TRUE
  ) +
  
  geom_point(
    data = monthly_plot,
    aes(
      x = date,
      y = total_tests,
      color = test_type
    ),
    size = 1.5,
    na.rm = TRUE
  ) +
  
  # Mark the fictional outsourcing disruption
  geom_vline(
    xintercept = as.Date("2023-11-01"),
    linetype = "dashed",
    color = "#ED7D31",
    linewidth = 0.6
  ) +
  
  annotate(
    "text",
    x = as.Date("2023-11-01"),
    y = Inf,
    label = "Simulated\noutsourcing\ninterruption",
    vjust = 1.2,
    hjust = -0.1,
    size = 2.6,
    color = "#B45F06"
  ) +
  
  scale_color_manual(
    values = test_colors
  ) +
  
  scale_x_date(
    date_breaks = "4 months",
    date_labels = "%b %Y"
  ) +
  
  scale_y_continuous(
    labels = scales::label_comma(),
    expand = expansion(
      mult = c(0, 0.12)
    )
  ) +
  
  labs(
    title = "A - Monthly Dengue Laboratory Testing",
    subtitle = paste(
      "Synthetic local and outsourced activity.",
      "Blood PCR data missing: Sep-Dec 2022."
    ),
    x = NULL,
    y = "Number of tests",
    color = "Diagnostic test"
  ) +
  
  theme_scientific


# ============================================================
# 16. PREPARE PERIOD COMPARISON DATA
# ============================================================

period_plot <- period_summary %>%
  filter(
    test_type %in% figure_tests
  ) %>%
  mutate(
    
    period_label = factor(
      period,
      levels = period_levels,
      labels = c(
        "P1\n2022-23",
        "P2\n2023-24",
        "P3\n2025"
      )
    ),
    
    test_type = factor(
      test_type,
      levels = figure_tests
    )
  )


# ============================================================
# 17. PANEL B - LOCAL VS OUTSOURCED ACTIVITY
# ============================================================

# Mean monthly activity is used rather than raw totals
# because study periods have different durations and
# some early PCR observations are missing.

pB <- ggplot(
  period_plot,
  aes(
    x = period_label,
    y = mean_monthly_tests,
    fill = source
  )
) +
  
  geom_col(
    position = "stack",
    width = 0.65
  ) +
  
  facet_wrap(
    ~ test_type,
    scales = "free_y",
    nrow = 1
  ) +
  
  scale_fill_manual(
    values = source_colors
  ) +
  
  scale_y_continuous(
    labels = scales::label_comma()
  ) +
  
  labs(
    title = "B - Local vs Outsourced Testing by Study Period",
    subtitle = paste(
      "Mean tests per observed month",
      "- synthetic data"
    ),
    x = NULL,
    y = "Average monthly tests",
    fill = "Laboratory source"
  ) +
  
  theme_scientific +
  
  theme(
    axis.text.x = element_text(
      angle = 0,
      hjust = 0.5
    )
  )


# ============================================================
# 18. COMBINE BOTH PANELS
# ============================================================

final_figure <- (
  pA / pB
) +
  
  plot_layout(
    heights = c(1.7, 1)
  ) +
  
  plot_annotation(
    
    title = paste(
      "Synthetic Dengue Laboratory Activity",
      "- Local vs Outsourced Testing"
    ),
    
    subtitle = paste(
      "Monthly activity and period-level comparisons",
      "| June 2022 - November 2025"
    ),
    
    caption = paste(
      "Entirely synthetic demonstration.",
      "Not observed CHU or Biomnis activity.",
      "Missing PCR values are not treated as zeros.",
      "The outsourcing interruption is fictional."
    ),
    
    theme = theme(
      plot.title = element_text(
        face = "bold",
        size = 15,
        hjust = 0.5
      ),
      plot.subtitle = element_text(
        size = 11,
        hjust = 0.5
      ),
      plot.caption = element_text(
        size = 8,
        hjust = 0
      )
    )
  )


# ============================================================
# 19. DISPLAY FIGURE
# ============================================================

print(final_figure)


# ============================================================
# 20. EXPORT FIGURE
# ============================================================

figure_path <- file.path(
  figures_dir,
  "laboratory_chu_biomnis_synthetic.png"
)

ggsave(
  filename = figure_path,
  plot = final_figure,
  width = 16,
  height = 10,
  dpi = 300,
  bg = "white"
)

stopifnot(
  file.exists(figure_path)
)

cat("\nFinal laboratory figure exported successfully\n")
cat("Figure saved to:", figure_path, "\n")


# ============================================================
# 21. EXPORT SYNTHETIC DATA
# ============================================================

# Intermediate synthetic source-level dataset
# This directory is excluded from Git version control.

synthetic_data_path <- file.path(
  data_dir,
  "chu_biomnis_synthetic_monthly.csv"
)

write_csv(
  synthetic_data,
  synthetic_data_path
)


# ============================================================
# 22. EXPORT ANALYTICAL TABLES
# ============================================================

output_tables <- list(
  
  "laboratory_chu_biomnis_monthly_synthetic.csv" =
    monthly_summary,
  
  "laboratory_chu_biomnis_period_synthetic.csv" =
    period_summary,
  
  "laboratory_chu_biomnis_missingness_synthetic.csv" =
    missingness_summary
)

for (filename in names(output_tables)) {
  
  write_csv(
    output_tables[[filename]],
    file.path(
      tables_dir,
      filename
    )
  )
}


# ============================================================
# 23. FINAL QUALITY CHECKS
# ============================================================

exported_tables <- file.path(
  tables_dir,
  names(output_tables)
)

stopifnot(
  file.exists(synthetic_data_path),
  file.exists(figure_path),
  all(file.exists(exported_tables)),
  length(exported_tables) == 3,
  
  # All values are simulated
  all(
    synthetic_data$tests[
      !is.na(synthetic_data$tests)
    ] >= 0
  ),
  
  # Missing PCR measurements are preserved
  sum(is.na(monthly_summary$total_tests)) == 8
)


# ============================================================
# 24. FINAL REPORT
# ============================================================

cat("\n========================================\n")
cat("CHU / BIOMNIS SYNTHETIC MODULE COMPLETED\n")
cat("========================================\n")

cat("\nMonthly observation window: 42 months\n")

cat(
  "Diagnostic categories:",
  length(test_types),
  "\n"
)

cat(
  "Laboratory sources:",
  length(source_types),
  "\n"
)

cat(
  "Exported figures: 1\n"
)

cat(
  "Exported result tables:",
  length(exported_tables),
  "\n"
)

cat(
  "\nAll data and results are synthetic.\n"
)

cat(
  "\nModule completed successfully\n"
)
