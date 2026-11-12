
# ============================================================
# DENGUE MEDICO-ECONOMIC ANALYSIS
# OPENDAMIR — SYNTHETIC DATA WORKFLOW
# ============================================================

# Author: Marie-Noelle Nogeant
# Year: 2026
#
# Adapted from methodological work conducted during
# a public health internship.
#
# All observations and amounts are synthetic.
# Results are not official estimates for Martinique.
# ============================================================


# 1. CONFIGURATION -------------------------------------------

library(data.table)
library(ggplot2)

# Reproducibility
SEED_GLOBAL <- 20260421
set.seed(SEED_GLOBAL)

# Number of synthetic monthly files
N_FILES <- 25

# Illustrative number of rows per file
N_ROWS_PER_FILE <- 1500

# Treatment of negative reimbursement amounts
EXCLUDE_NEGATIVE <- TRUE


# 2. HEALTHCARE SERVICE CLASSIFICATION -----------------------

# PRS_NAT codes adapted from the original analytical workflow

codes_consultations <- c(
  1110, 1111, 1112, 1105,
  1191, 1192, 1210, 1211
)

codes_biology <- c(
  3211, 3221, 3222, 3223
)

codes_pharmacy <- c(
  3311, 3312, 3313
)

codes_sick_leave <- c(
  6111, 6113, 6115, 6117
)

# Complete analytical basket
codes_all <- c(
  codes_consultations,
  codes_biology,
  codes_pharmacy,
  codes_sick_leave
)


# 3. INITIAL VERIFICATION ------------------------------------

cat("\nOpenDamir synthetic workflow initialized\n")

cat("Number of planned files:", N_FILES, "\n")

cat("Number of service codes:", length(codes_all), "\n")

cat(
  "Negative reimbursements excluded:",
  EXCLUDE_NEGATIVE,
  "\n"
)


# 4. GENERATE SYNTHETIC OPENDAMIR FILES ----------------------

# Project directory
project_dir <- path.expand(
  "~/Documents/dengue-medico-economic-analysis"
)

# Directory for synthetic monthly datasets
data_dir <- file.path(
  project_dir,
  "data",
  "simulated",
  "opendamir"
)

dir.create(
  data_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# Monthly flow periods adapted from the original workflow
flow_months <- c(
  seq(
    as.Date("2022-07-01"),
    as.Date("2023-03-01"),
    by = "month"
  ),
  seq(
    as.Date("2023-07-01"),
    as.Date("2024-03-01"),
    by = "month"
  ),
  seq(
    as.Date("2025-05-01"),
    as.Date("2025-11-01"),
    by = "month"
  )
)

# Verify number of monthly periods
stopifnot(length(flow_months) == N_FILES)


# 4.1 FUNCTION TO GENERATE SYNTHETIC DATA --------------------

generate_monthly_file <- function(flow_date, n) {
  
  flow_year <- as.integer(
    format(flow_date, "%Y")
  )
  
  flow_month <- as.integer(
    format(flow_date, "%m")
  )
  
  
  # Simulate delays between care and reimbursement
  #
  # Synthetic stress-test scenario:
  # 90% of observations: 0-3 months
  #  6% of observations: 4-8 months
  #  4% of observations: 14-18 months
  #
  # Long delays are deliberately introduced to test
  # cumulative analysis. These probabilities are
  # illustrative, not estimates from real OpenDamir data.
  
  delay_months <- sample(
    x = c(0:3, 4:8, 14:18),
    size = n,
    replace = TRUE,
    prob = c(
      0.55, 0.20, 0.10, 0.05,
      rep(0.012, 5),
      rep(0.008, 5)
    )
  )
  
  
  # Calculate actual care year and month
  flow_index <- flow_year * 12 + flow_month - 1
  
  care_index <- flow_index - delay_months
  
  care_year <- care_index %/% 12
  
  care_month <- care_index %% 12 + 1
  
  # Synthetic reimbursement amounts
  reimbursements <- round(
    runif(
      n,
      min = 10,
      max = 200
    ),
    2
  )
  
  # Introduce negative amounts for quality checks
  negative_rows <- sample.int(
    n,
    size = round(n * 0.03)
  )
  
  reimbursements[negative_rows] <- -abs(
    reimbursements[negative_rows]
  )
  
  # Generate synthetic OpenDamir-style dataset
  dt <- data.table(
    
    FLX_ANN_MOI = as.integer(
      format(flow_date, "%Y%m")
    ),
    
    AGE_BEN_SNDS = sample(
      0:100,
      n,
      replace = TRUE
    ),
    
    BEN_RES_REG = sample(
      c(5, 1, 2, 3),
      n,
      replace = TRUE,
      prob = c(0.70, 0.10, 0.10, 0.10)
    ),
    
    BEN_SEX_COD = sample(
      c(1, 2),
      n,
      replace = TRUE
    ),
    
    FLT_ACT_NBR = sample(
      1:5,
      n,
      replace = TRUE
    ),
    
    FLT_REM_MNT = reimbursements,
    
    SOI_ANN = care_year,
    
    SOI_MOI = care_month,
    
    CPT_ENV_TYP = sample(
      c(1, 2),
      n,
      replace = TRUE,
      prob = c(0.85, 0.15)
    ),
    
    PRS_NAT = sample(
      c(codes_all, 8888, 9999),
      n,
      replace = TRUE
    ),
    
    PSP_SPE_SNDS = sample(
      c(1, 2, 3, 99),
      n,
      replace = TRUE
    )
  )
  
  return(dt)
}


# 4.2 GENERATE AND EXPORT 25 CSV FILES -----------------------

generated_files <- lapply(
  seq_along(flow_months),
  
  function(i) {
    
    flow_date <- flow_months[i]
    
    dt <- generate_monthly_file(
      flow_date,
      N_ROWS_PER_FILE
    )
    
    filename <- paste0(
      "A",
      format(flow_date, "%Y%m"),
      ".csv"
    )
    
    file_path <- file.path(
      data_dir,
      filename
    )
    
    fwrite(
      dt,
      file_path,
      sep = ";"
    )
    
    return(file_path)
  }
)


# 4.3 GENERATION VERIFICATION --------------------------------

cat("\nSynthetic OpenDamir datasets generated\n")

cat(
  "Number of files:",
  length(generated_files),
  "\n"
)

cat(
  "Rows per file:",
  N_ROWS_PER_FILE,
  "\n"
)

cat(
  "Total synthetic rows:",
  length(generated_files) * N_ROWS_PER_FILE,
  "\n"
)

cat(
  "Output directory:",
  data_dir,
  "\n"
)


# 5. OPENDAMIR DATA PROCESSING PIPELINE ----------------------

# Function to process one monthly reimbursement file
process_opendamir_file <- function(file_path) {
  
  # Check that the file exists
  if (!file.exists(file_path)) {
    stop(
      "File not found: ",
      file_path
    )
  }
  
  # Step 1 — Selective data import
  dt <- fread(
    file_path,
    sep = ";",
    select = c(
      "FLX_ANN_MOI",
      "AGE_BEN_SNDS",
      "BEN_RES_REG",
      "BEN_SEX_COD",
      "FLT_ACT_NBR",
      "FLT_REM_MNT",
      "SOI_ANN",
      "SOI_MOI",
      "CPT_ENV_TYP",
      "PRS_NAT",
      "PSP_SPE_SNDS"
    )
  )
  
  n_initial <- nrow(dt)
  
  # Step 2 — Geographic filtering
  dt <- dt[
    BEN_RES_REG == 5
  ]
  
  n_geographic <- nrow(dt)
  
  # Step 3 — Ambulatory care filtering
  dt <- dt[
    CPT_ENV_TYP == 1
  ]
  
  n_ambulatory <- nrow(dt)
  
  # Step 4 — Healthcare service basket
  dt <- dt[
    PRS_NAT %in% codes_all
  ]
  
  n_basket <- nrow(dt)
  
  # Step 5 — Identify negative reimbursements
  n_negative <- nrow(
    dt[!is.na(FLT_REM_MNT) & FLT_REM_MNT < 0]
  )
  
  if (EXCLUDE_NEGATIVE) {
    
    dt <- dt[
      !is.na(FLT_REM_MNT) &
        FLT_REM_MNT >= 0
    ]
  }
  
  # Step 6 — Classify healthcare services
  dt[, category := fcase(
    
    PRS_NAT %in% codes_consultations,
    "Consultations",
    
    PRS_NAT %in% codes_biology,
    "Laboratory",
    
    PRS_NAT %in% codes_pharmacy,
    "Pharmacy",
    
    PRS_NAT %in% codes_sick_leave,
    "Sick leave",
    
    default = "Other"
  )]
  
  # Step 7 — Track each processing step
  tracking <- data.table(
    
    file = basename(file_path),
    
    initial_rows = n_initial,
    
    geographic_rows = n_geographic,
    
    ambulatory_rows = n_ambulatory,
    
    basket_rows = n_basket,
    
    negative_rows = n_negative,
    
    final_rows = nrow(dt)
  )
  
  return(
    list(
      data = dt,
      tracking = tracking
    )
  )
}


# 6. TEST THE PIPELINE ON ONE SYNTHETIC FILE -----------------

# IMPORTANT:
# generated_files is a list created by lapply().
# [[1]] extracts the character file path.
# [1] would return a list and cause fread() to fail.

first_file <- generated_files[[1]]

cat("\nTesting file:", first_file, "\n")

# Run processing pipeline
test_result <- process_opendamir_file(
  first_file
)


# 7. PROCESSING VERIFICATION ---------------------------------

cat("\n========================================\n")
cat("OPENDAMIR PROCESSING TEST\n")
cat("========================================\n")

# Display filtering statistics
print(test_result$tracking)

# Display categories
cat("\nHealthcare categories:\n")

print(
  table(test_result$data$category)
)

# Verify that all remaining reimbursements are non-negative
if (EXCLUDE_NEGATIVE) {
  
  stopifnot(
    all(test_result$data$FLT_REM_MNT >= 0)
  )
}

# Verify that all remaining records belong to the basket
stopifnot(
  all(test_result$data$PRS_NAT %in% codes_all)
)

cat("\nProcessing completed successfully\n")


# 8. PROCESS ALL 25 SYNTHETIC FILES --------------------------

cat("\n========================================\n")
cat("PROCESSING ALL OPENDAMIR FILES\n")
cat("========================================\n")

# Apply the processing function to every monthly file
results_all <- lapply(
  generated_files,
  process_opendamir_file
)

# Combine all filtered datasets
combined_data <- rbindlist(
  lapply(results_all, function(x) x$data),
  use.names = TRUE,
  fill = TRUE
)

# Combine all processing tracking tables
tracking_all <- rbindlist(
  lapply(results_all, function(x) x$tracking),
  use.names = TRUE,
  fill = TRUE
)


# 9. GLOBAL PROCESSING SUMMARY -------------------------------

cat("\nNumber of processed files:",
    length(results_all), "\n")

cat("\nGlobal filtering summary:\n")

global_tracking <- tracking_all[, .(
  initial_rows = sum(initial_rows),
  geographic_rows = sum(geographic_rows),
  ambulatory_rows = sum(ambulatory_rows),
  basket_rows = sum(basket_rows),
  negative_rows = sum(negative_rows),
  final_rows = sum(final_rows)
)]

print(global_tracking)


# 10. HEALTHCARE CATEGORY SUMMARY ----------------------------

cat("\nHealthcare categories - all files:\n")

category_summary <- combined_data[
  ,
  .(
    observations = .N,
    total_acts = sum(FLT_ACT_NBR, na.rm = TRUE),
    reimbursement_eur = round(
      sum(FLT_REM_MNT, na.rm = TRUE),
      2
    )
  ),
  by = category
]

setorder(category_summary, category)

print(category_summary)


# 11. GLOBAL QUALITY CHECKS ----------------------------------

stopifnot(
  length(results_all) == N_FILES,
  uniqueN(tracking_all$file) == N_FILES,
  nrow(combined_data) == sum(tracking_all$final_rows),
  all(combined_data$PRS_NAT %in% codes_all)
)

if (EXCLUDE_NEGATIVE) {
  stopifnot(
    all(!is.na(combined_data$FLT_REM_MNT)),
    all(combined_data$FLT_REM_MNT >= 0)
  )
}

cat("\nAll 25 synthetic files processed successfully\n")

# 12. FLOW DATE AND CARE DATE CLASSIFICATION -----------------

# Reconstruct monthly flow date from FLX_ANN_MOI
combined_data[, flow_year := FLX_ANN_MOI %/% 100]

combined_data[, flow_month := FLX_ANN_MOI %% 100]

combined_data[, flow_date := as.Date(
  sprintf("%04d-%02d-01", flow_year, flow_month)
)]

# Reconstruct actual care date
combined_data[, care_date := as.Date(
  sprintf("%04d-%02d-01", SOI_ANN, SOI_MOI)
)]


# 13. DEFINE STUDY PERIODS -----------------------------------

classify_study_period <- function(dates) {
  
  fcase(
    
    dates >= as.Date("2022-07-01") &
      dates <= as.Date("2023-03-31"),
    "Baseline 2022-2023",
    
    dates >= as.Date("2023-07-01") &
      dates <= as.Date("2024-03-31"),
    "Epidemic 2023-2024",
    
    dates >= as.Date("2025-05-01") &
      dates <= as.Date("2025-11-30"),
    "Baseline 2025",
    
    default = "Outside study windows"
  )
}

# Assign each observation to its flow period
combined_data[, period_flow :=
                classify_study_period(flow_date)]

# Assign each observation to its actual care period
combined_data[, period_care :=
                classify_study_period(care_date)]


# 14. COMPARE FLOW AND CARE PERIODS ---------------------------

period_comparison <- combined_data[
  ,
  .(
    observations = .N,
    reimbursement_eur = round(
      sum(FLT_REM_MNT, na.rm = TRUE),
      2
    )
  ),
  by = .(period_flow, period_care)
]

setorder(
  period_comparison,
  period_flow,
  period_care
)

cat("\n========================================\n")
cat("FLOW PERIOD VS CARE PERIOD\n")
cat("========================================\n")

print(period_comparison)


# 15. PERIOD CLASSIFICATION QUALITY CHECKS -------------------

stopifnot(
  !anyNA(combined_data$flow_date),
  !anyNA(combined_data$care_date),
  all(combined_data$period_flow != "Outside study windows")
)

cat("\nPeriod classification completed successfully\n")


# 16. THREE ANALYTICAL APPROACHES ----------------------------

cat("\n========================================\n")
cat("COMPARISON OF THREE ANALYTICAL METHODS\n")
cat("========================================\n")

# Chronological order of the study periods
period_order <- c(
  "Baseline 2022-2023",
  "Epidemic 2023-2024",
  "Baseline 2025"
)

# Assign chronological ranks
combined_data[, flow_rank := match(
  period_flow, period_order
)]

combined_data[, care_rank := match(
  period_care, period_order
)]


# METHOD 1 — FULL FLOW ANALYSIS ------------------------------

# Include all observations from selected flow files,
# regardless of the actual care period.

data_full_flow <- copy(combined_data)


# METHOD 2 — STRICT CARE-PERIOD ANALYSIS --------------------

# Retain only observations where the care period
# matches the flow period.

data_strict <- combined_data[
  period_flow == period_care
]


# METHOD 3 — CUMULATIVE ANALYSIS -----------------------------

# Retain observations from the current study period
# and any earlier authorized study period.

# Observations outside all study windows are excluded.

data_cumulative <- combined_data[
  !is.na(care_rank) &
    !is.na(flow_rank) &
    care_rank <= flow_rank
]


# 17. SUMMARY FUNCTION --------------------------------------

summarize_method <- function(dt, method_name) {
  
  summary <- dt[
    ,
    .(
      observations = .N,
      
      total_acts = sum(
        FLT_ACT_NBR,
        na.rm = TRUE
      ),
      
      reimbursement_eur = sum(
        FLT_REM_MNT,
        na.rm = TRUE
      )
    ),
    by = .(period_flow, category)
  ]
  
  summary[, method := method_name]
  
  return(summary)
}


# 18. COMPARE ALL THREE METHODS ------------------------------

method_results <- rbindlist(
  list(
    
    summarize_method(
      data_full_flow,
      "1 - Full flow"
    ),
    
    summarize_method(
      data_strict,
      "2 - Strict care"
    ),
    
    summarize_method(
      data_cumulative,
      "3 - Cumulative"
    )
  ),
  use.names = TRUE
)


# Aggregate totals by study period and method
method_totals <- method_results[
  ,
  .(
    observations = sum(observations),
    
    reimbursement_eur = round(
      sum(reimbursement_eur),
      2
    )
  ),
  by = .(period_flow, method)
]

# Chronological ordering
method_totals[
  , period_flow := factor(
    period_flow,
    levels = period_order
  )
]

setorder(
  method_totals,
  period_flow,
  method
)

cat("\nRESULTS BY PERIOD AND METHOD\n")

print(method_totals)


# 19. METHOD COMPARISON TABLE --------------------------------

method_comparison <- dcast(
  method_totals,
  period_flow ~ method,
  value.var = "reimbursement_eur",
  fill = 0
)

# Calculate differences between methods
method_comparison[
  , full_minus_strict :=
    `1 - Full flow` - `2 - Strict care`
]

method_comparison[
  , cumulative_minus_strict :=
    `3 - Cumulative` - `2 - Strict care`
]

cat("\nFINANCIAL COMPARISON OF METHODS\n")

print(method_comparison)


# 20. QUALITY CHECKS ----------------------------------------

stopifnot(
  nrow(data_full_flow) == nrow(combined_data),
  nrow(data_strict) <= nrow(data_cumulative),
  nrow(data_cumulative) <= nrow(data_full_flow)
)

cat("\nThree-method comparison completed successfully\n")


# 21. VISUAL COMPARISON OF ANALYTICAL METHODS ----------------

# Create the output directory
figures_dir <- file.path(
  project_dir,
  "outputs",
  "figures"
)

dir.create(
  figures_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# Define colors for the analytical methods
method_colors <- c(
  "1 - Full flow" = "#2E86AB",
  "2 - Strict care" = "#E69F00",
  "3 - Cumulative" = "#009E73"
)

# Create comparative bar chart
g_method_comparison <- ggplot(
  method_totals,
  aes(
    x = period_flow,
    y = reimbursement_eur / 1e6,
    fill = method
  )
) +
  geom_col(
    position = position_dodge(width = 0.8),
    width = 0.7
  ) +
  scale_fill_manual(
    values = method_colors
  ) +
  scale_y_continuous(
    labels = function(x) {
      paste0(
        format(
          round(x, 2),
          nsmall = 2
        ),
        " M€"
      )
    }
  ) +
  labs(
    title = "OpenDamir - Comparison of Analytical Methods",
    subtitle = paste(
      "Full flow, strict care-period and cumulative analyses",
      "Synthetic reimbursement data"
    ),
    x = "Study period",
    y = "Synthetic reimbursements (million EUR)",
    fill = "Analytical method",
    caption = paste(
      "Synthetic demonstration only.",
      "Not an estimate of dengue-related costs in Martinique."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    axis.text.x = element_text(
      angle = 15,
      hjust = 1
    ),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

# Display the figure
print(g_method_comparison)

# Export the figure
figure_path <- file.path(
  figures_dir,
  "opendamir_method_comparison_synthetic.png"
)

ggsave(
  filename = figure_path,
  plot = g_method_comparison,
  width = 12,
  height = 7,
  dpi = 300
)

cat("\nMethod comparison figure exported successfully\n")
cat("Figure saved to:", figure_path, "\n")


# 22. EXPORT ANALYTICAL RESULTS -------------------------------

# Create directory for result tables
tables_dir <- file.path(
  project_dir,
  "outputs",
  "tables"
)

dir.create(
  tables_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# Export processing quality tracking
fwrite(
  tracking_all,
  file.path(
    tables_dir,
    "opendamir_processing_tracking_synthetic.csv"
  )
)

# Export healthcare category summary
fwrite(
  category_summary,
  file.path(
    tables_dir,
    "opendamir_category_summary_synthetic.csv"
  )
)

# Export results by period and method
fwrite(
  method_totals,
  file.path(
    tables_dir,
    "opendamir_method_totals_synthetic.csv"
  )
)

# Export financial comparison
fwrite(
  method_comparison,
  file.path(
    tables_dir,
    "opendamir_method_comparison_synthetic.csv"
  )
)

# Verify exported files
exported_tables <- c(
  "opendamir_processing_tracking_synthetic.csv",
  "opendamir_category_summary_synthetic.csv",
  "opendamir_method_totals_synthetic.csv",
  "opendamir_method_comparison_synthetic.csv"
)

stopifnot(
  all(file.exists(file.path(tables_dir, exported_tables)))
)

cat("\n========================================\n")
cat("OPENDAMIR RESULTS EXPORTED\n")
cat("========================================\n")

cat("Number of exported tables:",
    length(exported_tables), "\n")

cat("Output directory:", tables_dir, "\n")

cat("\nExport completed successfully\n")


# 23. ILLUSTRATIVE TERRITORIAL WEIGHTING ----------------------

# IMPORTANT:
# These weights are entirely illustrative.
# They do not represent official Martinique/DROM ratios.
# They are used to demonstrate the original methodology.

territorial_weights <- data.table(
  SOI_ANN = 2021:2025,
  wMQ_demo = c(
    0.155,
    0.160,
    0.165,
    0.170,
    0.175
  )
)

# Create a separate dataset for weighted analysis
weighted_data <- copy(combined_data)

# Match each observation with its care-year coefficient
weighted_data[
  territorial_weights,
  wMQ_demo := i.wMQ_demo,
  on = "SOI_ANN"
]

# Ensure every observation received a coefficient
stopifnot(
  !anyNA(weighted_data$wMQ_demo)
)

# Apply illustrative territorial weighting
weighted_data[
  , reimbursement_weighted_eur :=
    FLT_REM_MNT * wMQ_demo
]

# Summary by year of care
weighting_summary <- weighted_data[
  ,
  .(
    observations = .N,
    reimbursement_total_eur = round(
      sum(FLT_REM_MNT),
      2
    ),
    reimbursement_weighted_eur = round(
      sum(reimbursement_weighted_eur),
      2
    )
  ),
  by = SOI_ANN
]

# Add weighting coefficients
weighting_summary[
  territorial_weights,
  wMQ_demo := i.wMQ_demo,
  on = "SOI_ANN"
]

setorder(weighting_summary, SOI_ANN)

cat("\n========================================\n")
cat("ILLUSTRATIVE TERRITORIAL WEIGHTING\n")
cat("========================================\n")

print(weighting_summary)

cat("\nTerritorial weighting completed successfully\n")


# 24. WEIGHTED ANALYSIS OF THREE METHODS ---------------------

cat("\n========================================\n")
cat("WEIGHTED ANALYTICAL METHODS\n")
cat("========================================\n")


# METHOD 1 — FULL FLOW --------------------------------------

weighted_full_flow <- copy(weighted_data)


# METHOD 2 — STRICT CARE PERIOD ------------------------------

weighted_strict <- weighted_data[
  period_flow == period_care
]


# METHOD 3 — CUMULATIVE ANALYSIS -----------------------------

weighted_cumulative <- weighted_data[
  !is.na(care_rank) &
    !is.na(flow_rank) &
    care_rank <= flow_rank
]


# 25. WEIGHTED SUMMARY FUNCTION ------------------------------

summarize_weighted <- function(dt, method_name) {
  
  result <- dt[
    ,
    .(
      observations = .N,
      
      reimbursement_total_eur = sum(
        FLT_REM_MNT,
        na.rm = TRUE
      ),
      
      reimbursement_weighted_eur = sum(
        reimbursement_weighted_eur,
        na.rm = TRUE
      )
    ),
    by = .(period_flow, category)
  ]
  
  result[, method := method_name]
  
  return(result)
}


# 26. COMBINE WEIGHTED RESULTS -------------------------------

weighted_method_results <- rbindlist(
  list(
    
    summarize_weighted(
      weighted_full_flow,
      "1 - Full flow"
    ),
    
    summarize_weighted(
      weighted_strict,
      "2 - Strict care"
    ),
    
    summarize_weighted(
      weighted_cumulative,
      "3 - Cumulative"
    )
  ),
  use.names = TRUE
)


# Aggregate by period and method
weighted_method_totals <- weighted_method_results[
  ,
  .(
    observations = sum(observations),
    
    reimbursement_weighted_eur = round(
      sum(reimbursement_weighted_eur),
      2
    )
  ),
  by = .(period_flow, method)
]

weighted_method_totals[
  , period_flow := factor(
    period_flow,
    levels = period_order
  )
]

setorder(
  weighted_method_totals,
  period_flow,
  method
)

cat("\nWEIGHTED RESULTS BY PERIOD AND METHOD\n")

print(weighted_method_totals)


# 27. FINANCIAL COMPARISON -----------------------------------

weighted_comparison <- dcast(
  weighted_method_totals,
  period_flow ~ method,
  value.var = "reimbursement_weighted_eur",
  fill = 0
)

weighted_comparison[
  , full_minus_strict :=
    `1 - Full flow` - `2 - Strict care`
]

weighted_comparison[
  , cumulative_minus_strict :=
    `3 - Cumulative` - `2 - Strict care`
]

# Round monetary differences
weighted_comparison[
  , c(
    "full_minus_strict",
    "cumulative_minus_strict"
  ) := lapply(
    .SD,
    round,
    digits = 2
  ),
  .SDcols = c(
    "full_minus_strict",
    "cumulative_minus_strict"
  )
]

cat("\nWEIGHTED FINANCIAL COMPARISON\n")

print(weighted_comparison)


# 28. QUALITY CHECKS ----------------------------------------

stopifnot(
  nrow(weighted_full_flow) == nrow(weighted_data),
  
  nrow(weighted_strict) <=
    nrow(weighted_cumulative),
  
  nrow(weighted_cumulative) <=
    nrow(weighted_full_flow),
  
  all(
    weighted_data$reimbursement_weighted_eur >= 0
  ),
  
  isTRUE(
    all.equal(
      sum(weighted_data$reimbursement_weighted_eur),
      sum(weighting_summary$reimbursement_weighted_eur),
      tolerance = 0.05
    )
  )
)

cat("\nWeighted comparison completed successfully\n")


# 29. WEIGHTED METHOD COMPARISON FIGURE ----------------------

cat("\n========================================\n")
cat("WEIGHTED METHOD COMPARISON FIGURE\n")
cat("========================================\n")

# Create comparative chart
g_weighted_comparison <- ggplot(
  weighted_method_totals,
  aes(
    x = period_flow,
    y = reimbursement_weighted_eur,
    fill = method
  )
) +
  geom_col(
    position = position_dodge(width = 0.8),
    width = 0.7
  ) +
  scale_fill_manual(
    values = method_colors
  ) +
  scale_y_continuous(
    labels = scales::label_number(
      big.mark = " ",
      suffix = " EUR",
      accuracy = 1
    )
  ) +
  labs(
    title = "OpenDamir - Weighted Method Comparison",
    subtitle = paste(
      "Full flow, strict care and cumulative analyses",
      "- Synthetic data"
    ),
    x = "Study period",
    y = "Illustratively weighted reimbursements",
    fill = "Analytical method",
    caption = paste(
      "Synthetic data and illustrative territorial weights.",
      "Not an estimate of dengue-related costs in Martinique."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(
      face = "bold",
      size = 14
    ),
    axis.text.x = element_text(
      angle = 15,
      hjust = 1
    ),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

# Display chart
print(g_weighted_comparison)

# Export chart
weighted_figure_path <- file.path(
  figures_dir,
  "opendamir_weighted_comparison_synthetic.png"
)

ggsave(
  filename = weighted_figure_path,
  plot = g_weighted_comparison,
  width = 12,
  height = 7,
  dpi = 300
)

# Verify export
stopifnot(
  file.exists(weighted_figure_path)
)

cat("\nWeighted comparison figure exported successfully\n")
cat("Figure saved to:", weighted_figure_path, "\n")


# 30. EXPORT WEIGHTED ANALYSIS RESULTS -----------------------

cat("\n========================================\n")
cat("EXPORTING WEIGHTED OPENDAMIR RESULTS\n")
cat("========================================\n")

# Ensure output directory exists
dir.create(
  tables_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# Export yearly territorial weighting summary
fwrite(
  weighting_summary,
  file.path(
    tables_dir,
    "opendamir_territorial_weighting_synthetic.csv"
  )
)

# Export weighted results by period and method
fwrite(
  weighted_method_totals,
  file.path(
    tables_dir,
    "opendamir_weighted_method_totals_synthetic.csv"
  )
)

# Export weighted financial comparison
fwrite(
  weighted_comparison,
  file.path(
    tables_dir,
    "opendamir_weighted_comparison_synthetic.csv"
  )
)

# Verify that all three CSV files exist
weighted_exports <- c(
  "opendamir_territorial_weighting_synthetic.csv",
  "opendamir_weighted_method_totals_synthetic.csv",
  "opendamir_weighted_comparison_synthetic.csv"
)

stopifnot(
  all(
    file.exists(
      file.path(tables_dir, weighted_exports)
    )
  )
)

cat("\nWeighted OpenDamir results exported successfully\n")

cat(
  "Number of exported tables:",
  length(weighted_exports),
  "\n"
)

cat(
  "Total OpenDamir result tables:",
  length(exported_tables) + length(weighted_exports),
  "\n"
)

cat("Output directory:", tables_dir, "\n")
