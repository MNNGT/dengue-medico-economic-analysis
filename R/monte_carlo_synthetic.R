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
