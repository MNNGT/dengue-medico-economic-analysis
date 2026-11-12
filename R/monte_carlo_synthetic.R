# ============================================================
# DENGUE MEDICO-ECONOMIC ANALYSIS
# MONTE CARLO SIMULATION — SYNTHETIC DATA
# ============================================================

# Author: Marie-Noelle Nogeant
# Year: 2026
#
# Adapted from methodological work conducted during
# a public health internship.
#
# All input data and cost parameters are synthetic.
# Results do not represent actual estimates for Martinique.
# ============================================================


# 1. SIMULATION CONFIGURATION -------------------------------

# Random seed for reproducibility
SEED_GLOBAL <- 42

set.seed(SEED_GLOBAL)

# Number of Monte Carlo iterations
n_iter <- 10000

# Verification
cat("Monte Carlo simulation initialized\n")
cat("Number of iterations:", n_iter, "\n")

# 2. SYNTHETIC EPIDEMIOLOGICAL DATA -------------------------

# All values below are fictional.
# They are used only to demonstrate the methodology.

# Epidemic period
cases_estimated_epidemic <- 14000
cases_reported_epidemic  <- 2200

# Reference period
cases_estimated_reference <- 2100
cases_reported_reference  <- 400

# Calculate excess cases
excess_cases_estimated <- (
  cases_estimated_epidemic -
    cases_estimated_reference
)

excess_cases_reported <- (
  cases_reported_epidemic -
    cases_reported_reference
)

# Verification
cat("\nSynthetic epidemiological indicators\n")
cat("Estimated excess cases:", excess_cases_estimated, "\n")
cat("Reported excess cases:", excess_cases_reported, "\n")

# 3. SYNTHETIC ECONOMIC PARAMETERS --------------------------

# All amounts and probabilities are illustrative.
# These are not observed costs or validated estimates.

# Direct healthcare costs (EUR)
ambulatory_cost_mean <- 4200000
ambulatory_cost_sd   <- 420000

laboratory_cost_mean <- 520000
laboratory_cost_sd   <- 52000

emergency_cost_mean <- 65000
emergency_cost_sd   <- 3250

# Hospitalizations
excess_hospitalizations <- 300
hospitalization_daily_cost <- 1200

# Length of hospital stay (days)
los_min  <- 3
los_mode <- 4.5
los_max  <- 7

# Medication costs
medication_cost_epidemic  <- 52000
medication_cost_reference <- 41000

# Indirect costs: productivity losses
activity_rate <- 0.65
sick_leave_probability <- 0.30
daily_wage <- 60

# Sick leave duration (days)
sick_leave_min  <- 4
sick_leave_mode <- 7
sick_leave_max  <- 14

# Verification
cat("\nSynthetic economic parameters initialized\n")
cat("Ambulatory mean cost:", ambulatory_cost_mean, "EUR\n")
cat("Hospitalizations:", excess_hospitalizations, "\n")
cat("Daily wage:", daily_wage, "EUR\n")

# 4. TRIANGULAR PROBABILITY DISTRIBUTION ---------------------

# Custom triangular random number generator
rtriangular <- function(n, min, mode, max) {
  
  if (min >= max || mode < min || mode > max) {
    stop("Invalid triangular distribution parameters")
  }
  
  u <- runif(n)
  
  threshold <- (mode - min) / (max - min)
  
  values <- ifelse(
    u <= threshold,
    min + sqrt(u * (max - min) * (mode - min)),
    max - sqrt((1 - u) * (max - min) * (max - mode))
  )
  
  return(values)
}

# Simulate hospital length of stay
los_sim <- rtriangular(
  n = n_iter,
  min = los_min,
  mode = los_mode,
  max = los_max
)

# Verification
cat("\nTriangular distribution initialized\n")
cat("Number of simulated stays:", length(los_sim), "\n")
cat(
  "All values within bounds:",
  all(los_sim >= los_min & los_sim <= los_max),
  "\n"
)

# 5. MONTE CARLO SIMULATION — DIRECT COSTS -------------------

# Generate 10,000 simulated ambulatory costs
ambulatory_cost_sim <- pmax(
  rnorm(
    n_iter,
    mean = ambulatory_cost_mean,
    sd = ambulatory_cost_sd
  ),
  0
)

# Generate simulated laboratory costs
laboratory_cost_sim <- pmax(
  rnorm(
    n_iter,
    mean = laboratory_cost_mean,
    sd = laboratory_cost_sd
  ),
  0
)

# Generate simulated emergency department costs
emergency_cost_sim <- pmax(
  rnorm(
    n_iter,
    mean = emergency_cost_mean,
    sd = emergency_cost_sd
  ),
  0
)

# Simulate the number of excess hospitalizations
# Illustrative uncertainty: 5% of the central estimate
hospitalizations_sim <- pmax(
  round(
    rnorm(
      n_iter,
      mean = excess_hospitalizations,
      sd = excess_hospitalizations * 0.05
    )
  ),
  0
)

# Calculate hospitalization costs
hospitalization_cost_sim <- (
  hospitalizations_sim *
    hospitalization_daily_cost *
    los_sim
)

# Verification
cat("\nDirect healthcare cost simulation\n")
cat("Number of iterations:", length(ambulatory_cost_sim), "\n")

cat(
  "Mean ambulatory cost:",
  round(mean(ambulatory_cost_sim), 2),
  "EUR\n"
)

cat(
  "Mean hospitalization cost:",
  round(mean(hospitalization_cost_sim), 2),
  "EUR\n"
)

cat(
  "All simulated costs non-negative:",
  all(
    ambulatory_cost_sim >= 0 &
      laboratory_cost_sim >= 0 &
      emergency_cost_sim >= 0 &
      hospitalization_cost_sim >= 0
  ),
  "\n"
)

# 6. MONTE CARLO SIMULATION — MEDICATION COSTS ----------------

# Illustrative allocation by medication category
paracetamol_share <- 0.75
antiemetic_share  <- 0.25

# Calculate excess reimbursement by category
paracetamol_excess <- (
  medication_cost_epidemic -
  medication_cost_reference
) * paracetamol_share

antiemetic_excess <- (
  medication_cost_epidemic -
  medication_cost_reference
) * antiemetic_share

# Simulate the proportion of non-reimbursed OTC purchases
# Uniform distribution between 20% and 50%
otc_share_sim <- runif(
  n_iter,
  min = 0.20,
  max = 0.50
)

# Correction factor for OTC purchases
otc_correction_sim <- 1 / (1 - otc_share_sim)

# Apply the correction to paracetamol only
medication_cost_sim <- pmax(
  paracetamol_excess * otc_correction_sim +
    antiemetic_excess,
  0
)

# Verification
cat("\nMedication cost simulation\n")
cat("Number of iterations:", length(medication_cost_sim), "\n")

cat(
  "Mean medication cost:",
  round(mean(medication_cost_sim), 2),
  "EUR\n"
)

cat(
  "All medication costs non-negative:",
  all(medication_cost_sim >= 0),
  "\n"
)


# 7. MONTE CARLO SIMULATION — INDIRECT COSTS ------------------

# Simulate uncertainty in the number of excess cases
# Illustrative standard deviation: 10% of the central estimate

excess_cases_sim <- pmax(
  round(
    rnorm(
      n_iter,
      mean = excess_cases_estimated,
      sd = excess_cases_estimated * 0.10
    )
  ),
  0
)

# Simulate sick leave duration using a triangular distribution
sick_leave_sim <- rtriangular(
  n = n_iter,
  min = sick_leave_min,
  mode = sick_leave_mode,
  max = sick_leave_max
)

# Calculate productivity losses using the human capital approach
indirect_cost_sim <- (
  excess_cases_sim *
    activity_rate *
    sick_leave_probability *
    sick_leave_sim *
    daily_wage
)

# Verification
cat("\nIndirect cost simulation\n")
cat("Number of iterations:", length(indirect_cost_sim), "\n")

cat(
  "Mean indirect cost:",
  round(mean(indirect_cost_sim), 2),
  "EUR\n"
)

cat(
  "All indirect costs non-negative:",
  all(indirect_cost_sim >= 0),
  "\n"
)


# 8. TOTAL MEDICO-ECONOMIC COST ESTIMATION -------------------

# Total direct healthcare costs
direct_cost_sim <- (
  ambulatory_cost_sim +
    laboratory_cost_sim +
    emergency_cost_sim +
    hospitalization_cost_sim +
    medication_cost_sim
)

# Total economic burden
total_cost_sim <- direct_cost_sim + indirect_cost_sim

# Monte Carlo summary statistics
total_mean <- mean(total_cost_sim)
total_median <- median(total_cost_sim)

total_interval <- quantile(
  total_cost_sim,
  probs = c(0.025, 0.975)
)

# Contribution of direct and indirect costs
direct_share <- mean(direct_cost_sim) / total_mean * 100
indirect_share <- mean(indirect_cost_sim) / total_mean * 100

# Display results
cat("\n========================================\n")
cat("MONTE CARLO — SYNTHETIC COST ESTIMATION\n")
cat("========================================\n")

cat("Iterations:", n_iter, "\n")

cat(
  "Mean total cost:",
  round(total_mean / 1e6, 3),
  "million EUR\n"
)

cat(
  "Median total cost:",
  round(total_median / 1e6, 3),
  "million EUR\n"
)

cat(
  "95% simulation interval: [",
  round(total_interval[1] / 1e6, 3),
  ";",
  round(total_interval[2] / 1e6, 3),
  "] million EUR\n"
)

cat(
  "Direct cost share:",
  round(direct_share, 1),
  "%\n"
)

cat(
  "Indirect cost share:",
  round(indirect_share, 1),
  "%\n"
)

cat(
  "All total costs non-negative:",
  all(total_cost_sim >= 0),
  "\n"
)


# 9. SENSITIVITY ANALYSIS — CASE INDICATOR -------------------

# Scenario A: estimated excess cases (already simulated)
scenario_A_total <- total_cost_sim

# Scenario B: reported excess cases
# Reuse the same standardized uncertainty across scenarios
standardized_case_draws <- (
  excess_cases_sim - excess_cases_estimated
) / (excess_cases_estimated * 0.10)

reported_cases_sim <- pmax(
  round(
    excess_cases_reported +
      standardized_case_draws * (excess_cases_reported * 0.10)
  ),
  0
)

# Recalculate productivity losses for Scenario B
scenario_B_indirect <- (
  reported_cases_sim *
    activity_rate *
    sick_leave_probability *
    sick_leave_sim *
    daily_wage
)

# Keep direct costs unchanged
scenario_B_total <- direct_cost_sim + scenario_B_indirect

# Compare scenarios
scenario_comparison <- data.frame(
  Scenario = c("Estimated cases", "Reported cases"),
  Mean_MEUR = c(
    mean(scenario_A_total),
    mean(scenario_B_total)
  ) / 1e6,
  Median_MEUR = c(
    median(scenario_A_total),
    median(scenario_B_total)
  ) / 1e6,
  Lower_95 = c(
    quantile(scenario_A_total, 0.025),
    quantile(scenario_B_total, 0.025)
  ) / 1e6,
  Upper_95 = c(
    quantile(scenario_A_total, 0.975),
    quantile(scenario_B_total, 0.975)
  ) / 1e6
)

# Display results
cat("\nSENSITIVITY ANALYSIS — CASE INDICATOR\n")
print(round(
  scenario_comparison[, -1],
  3
))

cat("\nScenario names:\n")
print(scenario_comparison$Scenario)

cat(
  "\nDifference in mean total cost:",
  round(
    (mean(scenario_A_total) - mean(scenario_B_total)) / 1e6,
    3
  ),
  "million EUR\n"
)


# 10. VISUALIZATION — MONTE CARLO DISTRIBUTIONS ------------

library(ggplot2)

# Prepare simulation results for visualization
plot_data <- data.frame(
  total_cost_million = c(
    scenario_A_total,
    scenario_B_total
  ) / 1e6,
  
  scenario = factor(
    rep(
      c("Estimated cases", "Reported cases"),
      each = n_iter
    ),
    levels = c("Estimated cases", "Reported cases")
  )
)

# Plot probability density distributions
mc_density_plot <- ggplot(
  plot_data,
  aes(
    x = total_cost_million,
    fill = scenario,
    color = scenario
  )
) +
  geom_density(
    alpha = 0.30,
    linewidth = 1
  ) +
  geom_vline(
    xintercept = mean(scenario_A_total) / 1e6,
    color = "#2563EB",
    linetype = "dashed",
    linewidth = 0.8
  ) +
  geom_vline(
    xintercept = mean(scenario_B_total) / 1e6,
    color = "#DC2626",
    linetype = "dashed",
    linewidth = 0.8
  ) +
  scale_fill_manual(
    values = c(
      "Estimated cases" = "#2563EB",
      "Reported cases" = "#DC2626"
    )
  ) +
  scale_color_manual(
    values = c(
      "Estimated cases" = "#2563EB",
      "Reported cases" = "#DC2626"
    )
  ) +
  labs(
    title = "Monte Carlo Simulation — Economic Burden",
    subtitle = "Comparison of synthetic epidemiological scenarios",
    x = "Total economic cost (million EUR)",
    y = "Probability density",
    fill = "Scenario",
    color = "Scenario",
    caption = "10,000 iterations per scenario | Synthetic data only"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold"),
    legend.position = "bottom"
  )

# Display figure
print(mc_density_plot)

# Export to the GitHub project
project_dir <- path.expand(
  "~/Documents/dengue-medico-economic-analysis"
)

output_dir <- file.path(
  project_dir,
  "outputs",
  "figures"
)

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

ggsave(
  filename = file.path(
    output_dir,
    "monte_carlo_synthetic_distributions.png"
  ),
  plot = mc_density_plot,
  width = 10,
  height = 6,
  dpi = 300
)

cat("\nMonte Carlo density plot exported successfully\n")


# 11. COST BREAKDOWN — MAIN SCENARIO -------------------------

# Calculate mean cost for each component
cost_breakdown <- data.frame(
  component = c(
    "Ambulatory care",
    "Laboratory testing",
    "Emergency care",
    "Hospitalizations",
    "Medications",
    "Productivity losses"
  ),
  
  mean_cost = c(
    mean(ambulatory_cost_sim),
    mean(laboratory_cost_sim),
    mean(emergency_cost_sim),
    mean(hospitalization_cost_sim),
    mean(medication_cost_sim),
    mean(indirect_cost_sim)
  ),
  
  cost_type = c(
    rep("Direct costs", 5),
    "Indirect costs"
  )
)

# Convert amounts to millions of euros
cost_breakdown$mean_cost_million <- (
  cost_breakdown$mean_cost / 1e6
)

# Check that components sum to the total cost
stopifnot(
  isTRUE(all.equal(
    sum(cost_breakdown$mean_cost),
    mean(scenario_A_total)
  ))
)

# Create the cost breakdown plot
cost_breakdown_plot <- ggplot(
  cost_breakdown,
  aes(
    x = reorder(component, mean_cost_million),
    y = mean_cost_million,
    fill = cost_type
  )
) +
  geom_col(width = 0.7) +
  geom_text(
    aes(
      label = sprintf("%.3f M EUR", mean_cost_million)
    ),
    hjust = -0.1,
    size = 3.5
  ) +
  coord_flip() +
  scale_fill_manual(
    values = c(
      "Direct costs" = "#2563EB",
      "Indirect costs" = "#E11D48"
    )
  ) +
  scale_y_continuous(
    expand = expansion(mult = c(0, 0.22))
  ) +
  labs(
    title = "Economic Burden by Cost Component",
    subtitle = "Main Monte Carlo scenario — estimated excess cases",
    x = NULL,
    y = "Mean simulated cost (million EUR)",
    fill = "Cost category",
    caption = "Synthetic data only | 10,000 iterations"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold"),
    legend.position = "bottom"
  )

# Display the figure
print(cost_breakdown_plot)

# Export figure
ggsave(
  filename = file.path(
    output_dir,
    "monte_carlo_cost_breakdown_synthetic.png"
  ),
  plot = cost_breakdown_plot,
  width = 11,
  height = 6,
  dpi = 300
)

cat("\nCost breakdown plot exported successfully\n")


# 12. SENSITIVITY ANALYSIS — DAILY WAGE ----------------------

# Illustrative daily wage scenarios (EUR/day)
wage_scenarios <- c(
  "Low wage" = 45,
  "Baseline wage" = 60,
  "High wage" = 115
)

# Function to calculate economic costs for a given wage
calculate_wage_scenario <- function(wage) {
  
  # Productivity losses
  indirect_cost <- (
    excess_cases_sim *
      activity_rate *
      sick_leave_probability *
      sick_leave_sim *
      wage
  )
  
  # Total costs: direct costs remain unchanged
  total_cost <- direct_cost_sim + indirect_cost
  
  return(data.frame(
    wage = wage,
    mean_total = mean(total_cost),
    median_total = median(total_cost),
    lower_95 = unname(quantile(total_cost, 0.025)),
    upper_95 = unname(quantile(total_cost, 0.975)),
    mean_indirect = mean(indirect_cost)
  ))
}

# Run all wage scenarios
wage_results <- do.call(
  rbind,
  lapply(wage_scenarios, calculate_wage_scenario)
)

# Add scenario names
wage_results$scenario <- names(wage_scenarios)

# Convert results to million EUR
wage_results$mean_total_MEUR <- wage_results$mean_total / 1e6
wage_results$lower_95_MEUR <- wage_results$lower_95 / 1e6
wage_results$upper_95_MEUR <- wage_results$upper_95 / 1e6

# Calculate variation relative to the baseline
baseline_mean <- wage_results$mean_total[
  wage_results$scenario == "Baseline wage"
]

wage_results$variation_pct <- (
  wage_results$mean_total / baseline_mean - 1
) * 100

# Verify that the baseline reproduces the main scenario
stopifnot(
  isTRUE(all.equal(
    baseline_mean,
    mean(scenario_A_total)
  ))
)

# Display results
cat("\nSENSITIVITY ANALYSIS — DAILY WAGE\n")

print(
  data.frame(
    Scenario = wage_results$scenario,
    Daily_Wage = wage_results$wage,
    Mean_MEUR = round(wage_results$mean_total_MEUR, 3),
    Lower_95 = round(wage_results$lower_95_MEUR, 3),
    Upper_95 = round(wage_results$upper_95_MEUR, 3),
    Variation_pct = round(wage_results$variation_pct, 2)
  ),
  row.names = FALSE
)

cat("\nWage sensitivity analysis completed successfully\n")


# 13. SENSITIVITY ANALYSIS — SICK LEAVE DURATION ------------

# Illustrative duration adjustment scenarios
duration_scenarios <- c(
  "Shorter sick leave" = 0.80,
  "Baseline duration" = 1.00,
  "Longer sick leave" = 1.20
)

# Function to calculate costs for each duration scenario
calculate_duration_scenario <- function(multiplier) {
  
  # Adjust sick leave duration
  adjusted_duration <- sick_leave_sim * multiplier
  
  # Recalculate productivity losses
  indirect_cost <- (
    excess_cases_sim *
      activity_rate *
      sick_leave_probability *
      adjusted_duration *
      daily_wage
  )
  
  # Direct costs remain unchanged
  total_cost <- direct_cost_sim + indirect_cost
  
  data.frame(
    multiplier = multiplier,
    mean_total = mean(total_cost),
    median_total = median(total_cost),
    lower_95 = unname(quantile(total_cost, 0.025)),
    upper_95 = unname(quantile(total_cost, 0.975))
  )
}

# Run the three scenarios
duration_results <- do.call(
  rbind,
  lapply(
    duration_scenarios,
    calculate_duration_scenario
  )
)

duration_results$scenario <- names(duration_scenarios)

# Reference scenario
duration_baseline <- duration_results$mean_total[
  duration_results$scenario == "Baseline duration"
]

# Verify that the baseline reproduces the main scenario
stopifnot(
  isTRUE(all.equal(
    duration_baseline,
    mean(scenario_A_total)
  ))
)

# Create the results table
duration_summary <- data.frame(
  Scenario = duration_results$scenario,
  Mean_MEUR = round(duration_results$mean_total / 1e6, 3),
  Lower_95 = round(duration_results$lower_95 / 1e6, 3),
  Upper_95 = round(duration_results$upper_95 / 1e6, 3),
  Variation_pct = round(
    (duration_results$mean_total / duration_baseline - 1) * 100,
    2
  )
)

# Display results
cat("\nSENSITIVITY ANALYSIS — SICK LEAVE DURATION\n")

print(duration_summary, row.names = FALSE)

cat("\nDuration sensitivity analysis completed successfully\n")


# 14. SENSITIVITY ANALYSIS — TORNADO PLOT --------------------

# Combine wage and sick leave sensitivity results
sensitivity_plot_data <- data.frame(
  scenario = c(
    "Low wage (45 EUR/day)",
    "High wage (115 EUR/day)",
    "Shorter sick leave (-20%)",
    "Longer sick leave (+20%)"
  ),
  
  parameter = c(
    "Daily wage",
    "Daily wage",
    "Sick leave duration",
    "Sick leave duration"
  ),
  
  variation_pct = c(
    wage_results$variation_pct[
      wage_results$scenario == "Low wage"
    ],
    wage_results$variation_pct[
      wage_results$scenario == "High wage"
    ],
    duration_results$mean_total[
      duration_results$scenario == "Shorter sick leave"
    ] / duration_baseline * 100 - 100,
    duration_results$mean_total[
      duration_results$scenario == "Longer sick leave"
    ] / duration_baseline * 100 - 100
  )
)

# Create sensitivity diagram
tornado_plot <- ggplot(
  sensitivity_plot_data,
  aes(
    x = variation_pct,
    y = reorder(scenario, variation_pct),
    fill = parameter
  )
) +
  geom_vline(
    xintercept = 0,
    linetype = "dashed",
    color = "gray40"
  ) +
  geom_col(width = 0.65) +
  geom_text(
    aes(
      label = sprintf("%+.2f%%", variation_pct)
    ),
    hjust = ifelse(
      sensitivity_plot_data$variation_pct >= 0,
      -0.15,
      1.15
    ),
    size = 4
  ) +
  scale_fill_manual(
    values = c(
      "Daily wage" = "#2563EB",
      "Sick leave duration" = "#E11D48"
    )
  ) +
  scale_x_continuous(
    limits = c(-7, 18),
    breaks = seq(-5, 15, by = 5),
    labels = function(x) paste0(x, "%")
  ) +
  labs(
    title = "One-Way Sensitivity Analysis",
    subtitle = "Impact of economic parameters on total simulated cost",
    x = "Variation from baseline total cost (%)",
    y = NULL,
    fill = "Parameter",
    caption = "Synthetic assumptions | Baseline = 7.700 million EUR"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold"),
    legend.position = "bottom"
  )

# Display plot
print(tornado_plot)

# Export figure
ggsave(
  filename = file.path(
    output_dir,
    "monte_carlo_tornado_synthetic.png"
  ),
  plot = tornado_plot,
  width = 11,
  height = 6,
  dpi = 300
)

cat("\nSensitivity tornado plot exported successfully\n")


# 15. INPUT VARIABLE DISTRIBUTIONS --------------------------

# Prepare all simulated input variables
input_distributions <- list(
  
  "Estimated excess cases" = excess_cases_sim,
  
  "Reported excess cases" = reported_cases_sim,
  
  "Ambulatory cost (million EUR)" =
    ambulatory_cost_sim / 1e6,
  
  "Laboratory cost (thousand EUR)" =
    laboratory_cost_sim / 1e3,
  
  "Emergency cost (thousand EUR)" =
    emergency_cost_sim / 1e3,
  
  "Number of hospitalizations" =
    hospitalizations_sim,
  
  "Hospital length of stay (days)" =
    los_sim,
  
  "OTC proportion (%)" =
    otc_share_sim * 100,
  
  "Sick leave duration (days)" =
    sick_leave_sim
)

# Transform into a long data frame
distribution_data <- do.call(
  rbind,
  lapply(
    names(input_distributions),
    function(variable_name) {
      data.frame(
        variable = variable_name,
        value = input_distributions[[variable_name]]
      )
    }
  )
)

# Preserve the order of variables
distribution_data$variable <- factor(
  distribution_data$variable,
  levels = names(input_distributions)
)

# Create histograms
input_distribution_plot <- ggplot(
  distribution_data,
  aes(x = value)
) +
  geom_histogram(
    bins = 35,
    fill = "#2563EB",
    color = "white",
    alpha = 0.85
  ) +
  facet_wrap(
    ~ variable,
    scales = "free",
    ncol = 3
  ) +
  labs(
    title = "Monte Carlo — Input Variable Distributions",
    subtitle = "10,000 iterations | Synthetic assumptions",
    x = "Simulated value",
    y = "Frequency",
    caption = "Illustrative distributions — not observed Martinique data"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    strip.text = element_text(face = "bold"),
    panel.spacing = grid::unit(1.2, "lines")
  )

# Display figure
print(input_distribution_plot)

# Export figure
ggsave(
  filename = file.path(
    output_dir,
    "monte_carlo_input_distributions.png"
  ),
  plot = input_distribution_plot,
  width = 14,
  height = 11,
  dpi = 300
)

cat("\nInput distributions exported successfully\n")


# 16. EXPORT MONTE CARLO RESULTS -----------------------------

# Create the output folder
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

# Export scenario comparison results
write.csv(
  scenario_comparison,
  file = file.path(
    tables_dir,
    "monte_carlo_scenario_comparison.csv"
  ),
  row.names = FALSE
)

# Export cost breakdown
write.csv(
  cost_breakdown,
  file = file.path(
    tables_dir,
    "monte_carlo_cost_breakdown.csv"
  ),
  row.names = FALSE
)

# Combine sensitivity analyses
sensitivity_summary <- rbind(
  data.frame(
    Parameter = "Daily wage",
    Scenario = wage_results$scenario,
    Mean_MEUR = wage_results$mean_total / 1e6,
    Variation_pct = wage_results$variation_pct
  ),
  data.frame(
    Parameter = "Sick leave duration",
    Scenario = duration_summary$Scenario,
    Mean_MEUR = duration_summary$Mean_MEUR,
    Variation_pct = duration_summary$Variation_pct
  )
)

# Export sensitivity results
write.csv(
  sensitivity_summary,
  file = file.path(
    tables_dir,
    "monte_carlo_sensitivity_analysis.csv"
  ),
  row.names = FALSE
)

cat("\nMonte Carlo tables exported successfully\n")
cat("Output directory:", tables_dir, "\n")
