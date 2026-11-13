
# ============================================================
# DENGUE MEDICO-ECONOMIC ANALYSIS
# LABORATORY COSTS — SYNTHETIC DATA WORKFLOW
# ============================================================

# Author: Marie-Noelle Nogeant
# Year: 2026
#
# Adapted from laboratory testing analyses conducted
# during a public health research internship.
#
# All observations, volumes and amounts are synthetic.
# No confidential laboratory data are included.
# ============================================================


# 1. CONFIGURATION -------------------------------------------

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)

# Reproducibility
SEED_GLOBAL <- 20260415
set.seed(SEED_GLOBAL)


# 2. PROJECT DIRECTORIES -------------------------------------

project_dir <- path.expand(
  "~/Documents/dengue-medico-economic-analysis"
)

# Synthetic input datasets
data_dir <- file.path(
  project_dir,
  "data",
  "simulated",
  "laboratory"
)

# Output directories
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

# Create directories if necessary
for (directory in c(data_dir, tables_dir, figures_dir)) {
  dir.create(
    directory,
    recursive = TRUE,
    showWarnings = FALSE
  )
}


# 3. LABORATORY TEST CLASSIFICATION --------------------------

# Main diagnostic categories from the original workflow
test_types <- c(
  "PCR (RNA)",
  "NS1 antigen",
  "Serology (IgG/IgM)"
)


# 4. STUDY PERIODS -------------------------------------------

# Monthly approximations of the original study periods

study_periods <- data.frame(
  period = c(
    "Baseline 2022-2023",
    "Epidemic 2023-2024",
    "Baseline 2025"
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


# 5. INITIAL VERIFICATION ------------------------------------

cat("\n========================================\n")
cat("LABORATORY COSTS WORKFLOW INITIALIZED\n")
cat("========================================\n")

cat("\nNumber of diagnostic categories:",
    length(test_types), "\n")

cat("Number of study periods:",
    nrow(study_periods), "\n")

cat("\nStudy periods:\n")
print(study_periods)

cat("\nSynthetic data directory:", data_dir, "\n")

cat("\nInitialization completed successfully\n")


# 6. GENERATE SYNTHETIC LABORATORY DATA ----------------------

# Fictional test codes and illustrative parameters
# These are NOT official NABM codes or tariffs.

test_catalog <- data.frame(
  code = c("SIM-PCR", "SIM-NS1", "SIM-SER"),
  libelle = c(
    "DENGUE ARN PCR",
    "DENGUE NS1 ANTIGEN",
    "DENGUE IGG IGM SEROLOGY"
  ),
  monthly_base = c(90, 70, 50),
  points_per_test = c(150, 70, 40)
)

# Illustrative euro value per B point
B_VALUE_DEMO <- 0.27


# 7. MONTHLY DATA GENERATION FUNCTION ------------------------

generate_laboratory_period <- function(
    start_date,
    end_date,
    period_name
) {
  
  months <- seq(
    from = start_date,
    to = end_date,
    by = "month"
  )
  
  # Three categories for every month
  test_id <- rep(
    seq_len(nrow(test_catalog)),
    times = length(months)
  )
  
  dates <- rep(
    months,
    each = nrow(test_catalog)
  )
  
  # Simulated monthly working days
  working_days <- rep(
    sample(19:23, length(months), replace = TRUE),
    each = nrow(test_catalog)
  )
  
  # Illustrative epidemic activity multiplier
  activity_multiplier <- if (
    period_name == "Epidemic 2023-2024"
  ) {
    3
  } else {
    1
  }
  
  # Generate synthetic testing volumes
  expected_volume <- (
    test_catalog$monthly_base[test_id] *
      activity_multiplier *
      runif(length(test_id), 0.8, 1.2)
  )
  
  executions <- rpois(
    length(test_id),
    lambda = expected_volume
  )
  
  # Total fictional B points
  total_B <- (
    executions *
      test_catalog$points_per_test[test_id]
  )
  
  # Simulated laboratory revenue
  revenue <- round(
    total_B *
      B_VALUE_DEMO *
      runif(length(test_id), 0.97, 1.03),
    2
  )
  
  # Keep the structure of the original laboratory data
  synthetic_data <- data.frame(
    code = test_catalog$code[test_id],
    libelle = test_catalog$libelle[test_id],
    mois = format(dates, "%Y-%m"),
    "nb jours" = working_days,
    "Exec." = executions,
    "Exec./jour" = round(
      executions / working_days,
      2
    ),
    CA = revenue,
    B = total_B,
    check.names = FALSE
  )
  
  return(synthetic_data)
}


# 8. CREATE THE THREE SYNTHETIC FILES ------------------------

file_names <- c(
  "22-23.csv",
  "23-24.csv",
  "2025.csv"
)

laboratory_files <- character(nrow(study_periods))

for (i in seq_len(nrow(study_periods))) {
  
  simulated_data <- generate_laboratory_period(
    start_date = study_periods$start_date[i],
    end_date = study_periods$end_date[i],
    period_name = study_periods$period[i]
  )
  
  file_path <- file.path(
    data_dir,
    file_names[i]
  )
  
  # Semicolon separator and decimal comma,
  # similar to the original source format
  write.csv2(
    simulated_data,
    file = file_path,
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  
  laboratory_files[i] <- file_path
}


# 9. GENERATION VERIFICATION ---------------------------------

stopifnot(
  length(laboratory_files) == 3,
  all(file.exists(laboratory_files))
)

cat("\n========================================\n")
cat("SYNTHETIC LABORATORY FILES GENERATED\n")
cat("========================================\n")

cat("\nNumber of files:", length(laboratory_files), "\n")

cat("\nGenerated files:\n")
print(basename(laboratory_files))

cat("\nOutput directory:", data_dir, "\n")

cat("\nGeneration completed successfully\n")


# 10. IMPORT AND CONSOLIDATE LABORATORY DATA -----------------

cat("\n========================================\n")
cat("LABORATORY DATA IMPORT AND CONSOLIDATION\n")
cat("========================================\n")

# Required columns from the original laboratory workflow
required_columns <- c(
  "code",
  "libelle",
  "mois",
  "nb jours",
  "Exec.",
  "Exec./jour",
  "CA",
  "B"
)

# Function to import one laboratory CSV file
read_laboratory_file <- function(file_path) {
  
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path)
  }
  
  df <- read_delim(
    file = file_path,
    delim = ";",
    locale = locale(
      encoding = "UTF-8",
      decimal_mark = ","
    ),
    col_types = cols(
      code = col_character(),
      libelle = col_character(),
      mois = col_character(),
      `nb jours` = col_integer(),
      `Exec.` = col_double(),
      `Exec./jour` = col_double(),
      CA = col_double(),
      B = col_double()
    ),
    show_col_types = FALSE
  )
  
  # Check column structure
  stopifnot(
    all(required_columns %in% names(df))
  )
  
  # Identify source file
  df$source_file <- basename(file_path)
  
  return(df)
}

# Import all three synthetic datasets
laboratory_list <- lapply(
  laboratory_files,
  read_laboratory_file
)

# Consolidate into one dataset
laboratory_data <- bind_rows(laboratory_list)


# 11. DATE PARSING AND STUDY PERIODS -------------------------

# Convert YYYY-MM to monthly dates
laboratory_data <- laboratory_data %>%
  mutate(
    date = as.Date(
      paste0(mois, "-01")
    ),
    
    period = study_periods$period[
      match(source_file, file_names)
    ]
  )


# 12. AUTOMATIC TEST CLASSIFICATION --------------------------

# Classify examination types from their labels
laboratory_data <- laboratory_data %>%
  mutate(
    test_type = case_when(
      grepl("IGG|IGM", toupper(libelle)) ~
        "Serology (IgG/IgM)",
      
      grepl("NS1", toupper(libelle)) ~
        "NS1 antigen",
      
      grepl("ARN|RNA|PCR", toupper(libelle)) ~
        "PCR (RNA)",
      
      TRUE ~ "Other"
    )
  )


# 13. DATA QUALITY VERIFICATION ------------------------------

stopifnot(
  nrow(laboratory_data) == 93,
  !anyNA(laboratory_data$date),
  !anyNA(laboratory_data$period),
  !anyNA(laboratory_data$test_type),
  all(laboratory_data$test_type %in% test_types),
  all(!is.na(laboratory_data$`Exec.`)),
  all(!is.na(laboratory_data$CA)),
  all(!is.na(laboratory_data$B))
)

cat("\nTotal imported observations:",
    nrow(laboratory_data), "\n")

cat("\nObservations by study period:\n")
print(table(laboratory_data$period))

cat("\nObservations by diagnostic category:\n")
print(table(laboratory_data$test_type))

cat("\nLaboratory data consolidation completed successfully\n")


# 14. LABORATORY ECONOMIC INDICATORS -------------------------

cat("\n========================================\n")
cat("LABORATORY ECONOMIC ANALYSIS\n")
cat("========================================\n")

# Calculate theoretical revenue using fictional B values
laboratory_data <- laboratory_data %>%
  mutate(
    theoretical_revenue_eur = B * B_VALUE_DEMO,
    
    observed_eur_per_B = if_else(
      B > 0,
      CA / B,
      NA_real_
    ),
    
    revenue_difference_pct = if_else(
      theoretical_revenue_eur > 0,
      100 * (CA - theoretical_revenue_eur) /
        theoretical_revenue_eur,
      NA_real_
    )
  )


# 15. REVENUE CONSISTENCY CHECK ------------------------------

revenue_quality <- laboratory_data %>%
  summarise(
    observations = n(),
    
    total_revenue_eur = round(
      sum(CA, na.rm = TRUE), 2
    ),
    
    theoretical_revenue_eur = round(
      sum(theoretical_revenue_eur, na.rm = TRUE), 2
    ),
    
    observed_eur_per_B = round(
      sum(CA, na.rm = TRUE) /
        sum(B, na.rm = TRUE),
      4
    ),
    
    mean_absolute_difference_pct = round(
      mean(abs(revenue_difference_pct), na.rm = TRUE),
      2
    )
  )

cat("\nREVENUE CONSISTENCY CHECK\n")
print(revenue_quality)


# 16. ECONOMIC SUMMARY BY STUDY PERIOD -----------------------

period_economic_summary <- laboratory_data %>%
  group_by(period) %>%
  summarise(
    months = n_distinct(date),
    
    total_tests = sum(`Exec.`, na.rm = TRUE),
    
    total_B_points = sum(B, na.rm = TRUE),
    
    total_revenue_eur = round(
      sum(CA, na.rm = TRUE), 2
    ),
    
    average_monthly_tests = round(
      total_tests / months, 1
    ),
    
    average_monthly_revenue_eur = round(
      total_revenue_eur / months, 2
    ),
    
    .groups = "drop"
  )

cat("\nECONOMIC SUMMARY BY STUDY PERIOD\n")
print(period_economic_summary, width = Inf)


# 17. ECONOMIC QUALITY CHECKS --------------------------------

stopifnot(
  all(laboratory_data$`Exec.` >= 0),
  all(laboratory_data$CA >= 0),
  all(laboratory_data$B >= 0),
  all(laboratory_data$theoretical_revenue_eur >= 0),
  all(is.finite(revenue_quality$observed_eur_per_B)),
  sum(period_economic_summary$months) == 31
)

cat("\nLaboratory economic analysis completed successfully\n")


# 18. ANALYSIS BY DIAGNOSTIC TEST TYPE -----------------------

cat("\n========================================\n")
cat("LABORATORY ANALYSIS BY TEST TYPE\n")
cat("========================================\n")

# Summarize testing activity and revenue
test_period_summary <- laboratory_data %>%
  group_by(period, test_type) %>%
  summarise(
    months = n_distinct(date),
    
    total_tests = sum(
      `Exec.`,
      na.rm = TRUE
    ),
    
    total_B_points = sum(
      B,
      na.rm = TRUE
    ),
    
    total_revenue_eur = round(
      sum(CA, na.rm = TRUE),
      2
    ),
    
    average_monthly_tests = round(
      total_tests / months,
      2
    ),
    
    average_monthly_revenue_eur = round(
      total_revenue_eur / months,
      2
    ),
    
    .groups = "drop"
  ) %>%
  arrange(period, test_type)

cat("\nRESULTS BY PERIOD AND TEST TYPE\n")

print(test_period_summary, width = Inf)


# 19. COMPARE WITH THE FIRST BASELINE PERIOD -----------------

# Use 2022-2023 as the illustrative reference period
baseline_reference <- test_period_summary %>%
  filter(period == "Baseline 2022-2023") %>%
  select(
    test_type,
    baseline_monthly_tests = average_monthly_tests,
    baseline_monthly_revenue = average_monthly_revenue_eur
  )

# Compare monthly averages to avoid unequal-duration bias
test_comparison <- test_period_summary %>%
  left_join(
    baseline_reference,
    by = "test_type"
  ) %>%
  mutate(
    test_volume_change_pct = round(
      100 * (
        average_monthly_tests /
          baseline_monthly_tests - 1
      ),
      2
    ),
    
    revenue_change_pct = round(
      100 * (
        average_monthly_revenue_eur /
          baseline_monthly_revenue - 1
      ),
      2
    )
  ) %>%
  filter(period != "Baseline 2022-2023") %>%
  select(
    period,
    test_type,
    average_monthly_tests,
    test_volume_change_pct,
    average_monthly_revenue_eur,
    revenue_change_pct
  )

cat("\nCOMPARISON WITH BASELINE 2022-2023\n")

print(test_comparison, width = Inf)


# 20. QUALITY CHECKS ----------------------------------------

stopifnot(
  nrow(test_period_summary) == 9,
  
  sum(test_period_summary$total_tests) ==
    sum(period_economic_summary$total_tests),
  
  abs(
    sum(test_period_summary$total_revenue_eur) -
      sum(period_economic_summary$total_revenue_eur)
  ) < 0.05,
  
  all(is.finite(test_comparison$test_volume_change_pct)),
  
  all(is.finite(test_comparison$revenue_change_pct))
)

cat("\nTest-specific economic analysis completed successfully\n")


# 21. MONTHLY LABORATORY TESTING ACTIVITY --------------------

cat("\n========================================\n")
cat("MONTHLY LABORATORY TESTING ACTIVITY\n")
cat("========================================\n")

# Aggregate monthly testing volumes
monthly_test_activity <- laboratory_data %>%
  group_by(period, date, test_type) %>%
  summarise(
    total_tests = sum(`Exec.`, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    period = factor(
      period,
      levels = study_periods$period
    ),
    test_type = factor(
      test_type,
      levels = test_types
    )
  ) %>%
  arrange(period, date, test_type)

# Verify monthly aggregation
stopifnot(
  nrow(monthly_test_activity) == 93,
  sum(monthly_test_activity$total_tests) ==
    sum(laboratory_data$`Exec.`)
)

# Define colors for diagnostic categories
test_colors <- c(
  "PCR (RNA)" = "#D94848",
  "NS1 antigen" = "#E69F00",
  "Serology (IgG/IgM)" = "#377EB8"
)

# Create monthly testing activity chart
g_laboratory_volumes <- ggplot(
  monthly_test_activity,
  aes(
    x = date,
    y = total_tests,
    color = test_type,
    group = test_type
  )
) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2) +
  facet_wrap(
    ~ period,
    scales = "free_x",
    nrow = 1
  ) +
  scale_color_manual(
    values = test_colors
  ) +
  scale_x_date(
    date_breaks = "3 months",
    date_labels = "%b %Y"
  ) +
  scale_y_continuous(
    labels = scales::label_comma()
  ) +
  labs(
    title = "Dengue Laboratory Testing Activity",
    subtitle = "Monthly diagnostic test volumes - Synthetic data",
    x = NULL,
    y = "Number of tests",
    color = "Diagnostic category",
    caption = paste(
      "Entirely synthetic laboratory activity.",
      "Not actual dengue surveillance data from Martinique."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    ),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

# Display the chart
print(g_laboratory_volumes)

# Export the chart
volume_figure_path <- file.path(
  figures_dir,
  "laboratory_monthly_volumes_synthetic.png"
)

ggsave(
  filename = volume_figure_path,
  plot = g_laboratory_volumes,
  width = 14,
  height = 7,
  dpi = 300
)

# Verify export
stopifnot(file.exists(volume_figure_path))

cat("\nMonthly laboratory volumes figure exported successfully\n")
cat("Figure saved to:", volume_figure_path, "\n")


# 22. MONTHLY LABORATORY REVENUE ANALYSIS --------------------

cat("\n========================================\n")
cat("MONTHLY LABORATORY REVENUE ANALYSIS\n")
cat("========================================\n")

# Aggregate monthly revenue by diagnostic category
monthly_laboratory_revenue <- laboratory_data %>%
  group_by(period, date, test_type) %>%
  summarise(
    revenue_eur = sum(CA, na.rm = TRUE),
    total_tests = sum(`Exec.`, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    period = factor(
      period,
      levels = study_periods$period
    ),
    test_type = factor(
      test_type,
      levels = test_types
    )
  ) %>%
  arrange(period, date, test_type)


# 23. REVENUE AGGREGATION CHECKS ------------------------------

stopifnot(
  nrow(monthly_laboratory_revenue) == 93,
  
  abs(
    sum(monthly_laboratory_revenue$revenue_eur) -
      sum(laboratory_data$CA)
  ) < 0.01,
  
  sum(monthly_laboratory_revenue$total_tests) ==
    sum(laboratory_data$`Exec.`)
)


# 24. MONTHLY REVENUE VISUALIZATION ---------------------------

g_laboratory_revenue <- ggplot(
  monthly_laboratory_revenue,
  aes(
    x = date,
    y = revenue_eur,
    fill = test_type
  )
) +
  geom_col(
    width = 23,
    position = "stack"
  ) +
  facet_wrap(
    ~ period,
    scales = "free_x",
    nrow = 1
  ) +
  scale_fill_manual(
    values = test_colors
  ) +
  scale_x_date(
    date_breaks = "3 months",
    date_labels = "%b %Y"
  ) +
  scale_y_continuous(
    labels = scales::label_number(
      big.mark = " ",
      suffix = " EUR",
      accuracy = 1
    )
  ) +
  labs(
    title = "Dengue Laboratory Testing - Monthly Revenue",
    subtitle = paste(
      "Monthly laboratory revenue by diagnostic category",
      "- Synthetic data"
    ),
    x = NULL,
    y = "Synthetic laboratory revenue (EUR)",
    fill = "Diagnostic category",
    caption = paste(
      "Entirely synthetic laboratory revenue.",
      "Not observed expenditures or insurance reimbursements."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(
      face = "bold"
    ),
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    ),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )


# Display figure
print(g_laboratory_revenue)


# 25. EXPORT MONTHLY REVENUE FIGURE ---------------------------

revenue_figure_path <- file.path(
  figures_dir,
  "laboratory_monthly_revenue_synthetic.png"
)

ggsave(
  filename = revenue_figure_path,
  plot = g_laboratory_revenue,
  width = 14,
  height = 7,
  dpi = 300
)

# Verify export
stopifnot(
  file.exists(revenue_figure_path)
)

cat("\nMonthly laboratory revenue figure exported successfully\n")

cat(
  "Figure saved to:",
  revenue_figure_path,
  "\n"
)

# 26. EXPORT LABORATORY ANALYSIS RESULTS ---------------------

cat("\n========================================\n")
cat("EXPORTING LABORATORY ANALYSIS RESULTS\n")
cat("========================================\n")

# Ensure the output directory exists
dir.create(
  tables_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# Define tables to export
laboratory_exports <- list(
  "laboratory_revenue_quality_synthetic.csv" =
    revenue_quality,
  
  "laboratory_period_summary_synthetic.csv" =
    period_economic_summary,
  
  "laboratory_test_period_summary_synthetic.csv" =
    test_period_summary,
  
  "laboratory_baseline_comparison_synthetic.csv" =
    test_comparison,
  
  "laboratory_monthly_volumes_synthetic.csv" =
    monthly_test_activity,
  
  "laboratory_monthly_revenue_synthetic.csv" =
    monthly_laboratory_revenue
)

# Export all tables as CSV files
for (filename in names(laboratory_exports)) {
  
  output_path <- file.path(
    tables_dir,
    filename
  )
  
  readr::write_csv(
    laboratory_exports[[filename]],
    output_path
  )
}

# 27. VERIFY EXPORTED FILES ----------------------------------

exported_paths <- file.path(
  tables_dir,
  names(laboratory_exports)
)

stopifnot(
  all(file.exists(exported_paths)),
  length(exported_paths) == 6
)

cat("\n========================================\n")
cat("LABORATORY RESULTS EXPORTED\n")
cat("========================================\n")

cat(
  "\nNumber of exported tables:",
  length(exported_paths),
  "\n"
)

cat("\nExported files:\n")
print(basename(exported_paths))

cat("\nOutput directory:", tables_dir, "\n")

cat("\nLaboratory data export completed successfully\n")
