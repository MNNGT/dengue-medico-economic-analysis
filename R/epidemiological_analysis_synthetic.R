# ============================================================================
# DENGUE MEDICO-ECONOMIC ANALYSIS IN MARTINIQUE
# MODULE 01 - EPIDEMIOLOGICAL ANALYSIS (100% SYNTHETIC)
# Author: Marie-Noelle Nogeant | Public portfolio adaptation, 2026
# ============================================================================
#
# Purpose
#   Reproduce selected methods from an original epidemiological surveillance
#   workflow without disclosing partner surveillance datasets or results.
#
# Analyses
#   1) Weekly dengue CCE estimated from fictional sentinel observations
#   2) P1/P2/P3 comparison, calendar timeline and epidemic peak
#   3) Matched-week P1/P2 illustrative excess CCE calculation
#   4) Weekly influenza, bronchiolitis and COVID-19 comparison
#   5) Three-week smoothing, min-max normalization and activity heatmap
#   6) Exploratory active-week counts (>= 25% of each series' own peak)
#   7) Synthetic emergency-department and hospital-activity indicators
#   8) Quality checks, tables and publication-ready figures
#
# STRICT DISCLAIMER
#   All observations, parameters, patterns, epidemic flags and results are
#   fabricated for methodological demonstration. Calendar labels indicate
#   study windows only: the artificial time series do not describe historical
#   outbreaks or actual disease dynamics in Martinique.
#
#   "Excess" is a synthetic matched-reference difference, not a causal or
#   validated estimate. The 25%-of-peak activity rule is descriptive and is
#   NOT an official public-health epidemic threshold.
# ============================================================================

# 01. PACKAGES ----------------------------------------------------------------
required <- c("dplyr", "tidyr", "ggplot2", "readr", "ISOweek",
              "zoo", "patchwork", "scales")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Missing R packages: ", paste(missing, collapse = ", "),
       ". Install with install.packages(c(",
       paste(sprintf('"%s"', missing), collapse = ", "), ")).")
}
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(readr)
  library(patchwork)
})

# 02. PORTABLE PROJECT PATHS --------------------------------------------------
# Run Source from the root of the GitHub repository in RStudio. If the working
# directory differs, try the established local project folder as a fallback.
project_dir <- getwd()
if (!dir.exists(file.path(project_dir, "R"))) {
  project_dir <- path.expand("~/Documents/dengue-medico-economic-analysis")
}
if (!dir.exists(file.path(project_dir, "R"))) {
  stop("Project root not found. Open the repository in RStudio or setwd() ",
       "to the folder containing R/ and outputs/.")
}

input_dir <- file.path(project_dir, "data", "simulated", "epidemiology")
tables_dir <- file.path(project_dir, "outputs", "tables")
figures_dir <- file.path(project_dir, "outputs", "figures")
for (p in c(input_dir, tables_dir, figures_dir)) {
  dir.create(p, recursive = TRUE, showWarnings = FALSE)
}

set.seed(20260518)

# 03. ISO WEEKLY CALENDAR AND PERIODS -----------------------------------------
# Exact ISO-week windows from the original analysis; P1/P2 have 47 weeks,
# whereas P3 has only 31 weeks, so P3 totals cannot be compared without
# accounting for observation duration.
iso_monday <- function(week_string) ISOweek::ISOweek2date(paste0(week_string, "-1"))

periods <- tibble::tibble(
  period = c("P1 - Baseline 2022-2023", "P2 - Epidemic 2023-2024",
             "P3 - Baseline 2025"),
  start = as.Date(c(iso_monday("2022-W30"), iso_monday("2023-W30"),
                    iso_monday("2025-W18"))),
  end = as.Date(c(iso_monday("2023-W24"), iso_monday("2024-W24"),
                  iso_monday("2025-W48")))
)
period_levels <- periods$period

assign_period <- function(d) {
  dplyr::case_when(
    d >= periods$start[1] & d <= periods$end[1] ~ period_levels[1],
    d >= periods$start[2] & d <= periods$end[2] ~ period_levels[2],
    d >= periods$start[3] & d <= periods$end[3] ~ period_levels[3],
    TRUE ~ "Outside study periods"
  )
}

all_dates <- seq(as.Date("2018-01-01"), as.Date("2025-12-22"), by = "week")
week_iso <- ISOweek::ISOweek(all_dates)
weekly <- tibble::tibble(
  date = all_dates,
  an_sem = gsub("-W", "_", week_iso),
  year = as.integer(substr(week_iso, 1, 4)),
  week = as.integer(substr(week_iso, 7, 8))
) %>%
  mutate(period = assign_period(date))

period_count <- weekly %>%
  filter(period %in% period_levels) %>%
  count(period, name = "n_weeks")
stopifnot(identical(sort(period_count$n_weeks), c(31L, 47L, 47L)))

# 04. GENERATE COMPLETELY FICTIONAL DENGUE SURVEILLANCE -----------------------
# Gaussian pulses are deliberately illustrative, not reconstructed curves.
# No original Santé publique France values, proportions or fitted parameters
# are used.
pulse <- function(dates, center, peak, spread_weeks) {
  distance <- as.numeric(dates - as.Date(center)) / 7
  peak * exp(-0.5 * (distance / spread_weeks)^2)
}

seasonality <- 1 + 0.15 * cos(2 * pi * weekly$week / 52)

expected_cce <- pmax(1,
                     52 * seasonality +
                       pulse(weekly$date, "2019-09-16", peak = 155, spread_weeks = 9) +
                       pulse(weekly$date, "2021-02-15", peak = 110, spread_weeks = 7) +
                       pulse(weekly$date, "2023-11-13", peak = 800, spread_weeks = 8)
)

# Simulated activity rate for fictional sentinel practices, not a real rate.
weekly <- weekly %>%
  mutate(
    part_act = round(runif(n(), min = 0.13, max = 0.28), 4),
    rms_brut = rpois(n(), lambda = expected_cce * part_act),
    rms_estim = as.integer(round(rms_brut / part_act)),
    # Synthetic flag: arbitrarily chosen within the P2 illustrative wave.
    epi01 = as.integer(date >= iso_monday("2023-W34") &
                         date <= iso_monday("2024-W13")),
    nb_prel = rpois(n(), lambda = 22 + 0.35 * rms_estim),
    pcr = as.integer(round(nb_prel * 0.65)),
    ns1 = nb_prel - pcr,
    cas_conf = rbinom(n(), size = nb_prel,
                      prob = pmin(0.75, 0.04 + 0.45 * rms_estim / (rms_estim + 100))),
    cas_prob = rbinom(n(), size = pmax(0L, nb_prel - cas_conf), prob = 0.055),
    dengue_cas_bio = cas_conf + cas_prob,
    pasaj_deng = rpois(n(), lambda = 1 + 0.12 * rms_estim),
    pasaj_total = pasaj_deng + rpois(n(), lambda = 300),
    hospi_deng = rpois(n(), lambda = 0.5 + 0.025 * rms_estim),
    hospi_total = hospi_deng + rpois(n(), lambda = 65)
  )

# 05. GENERATE FICTIONAL RESPIRATORY DISEASE SERIES --------------------------
# Pulse locations are arbitrary. These data must never be used to infer the
# occurrence, timing or severity of real influenza/COVID/bronchiolitis waves.
influenza_mu <- pmax(1, 35 + 125 * (0.5 + 0.5 * cos(2 * pi * (weekly$week - 5) / 52))^5 +
                       pulse(weekly$date, "2022-12-19", 95, 5))
bronchio_mu <- pmax(1, 20 + 95 * (0.5 + 0.5 * cos(2 * pi * (weekly$week - 49) / 52))^6)
covid_mu <- pmax(1, 18 +
                   pulse(weekly$date, "2020-09-14", 230, 9) +
                   pulse(weekly$date, "2022-01-10", 265, 7) +
                   pulse(weekly$date, "2024-09-02", 120, 7))

weekly <- weekly %>%
  mutate(
    grippe_cce = rpois(n(), lambda = influenza_mu),
    bronchio_cce = rpois(n(), lambda = bronchio_mu),
    covid_cce = rpois(n(), lambda = covid_mu)
  )

stopifnot(
  !anyDuplicated(weekly$date),
  all(weekly$rms_estim >= 0),
  all(weekly$cas_conf + weekly$cas_prob <= weekly$nb_prel),
  all(weekly$pasaj_deng <= weekly$pasaj_total),
  all(weekly$hospi_deng <= weekly$hospi_total),
  !anyNA(weekly)
)

# Keep the source-level synthetic observations in a separate data folder.
# Add data/simulated/epidemiology/ to .gitignore before committing.
readr::write_csv(weekly, file.path(input_dir, "weekly_surveillance_synthetic.csv"))

# 06. STUDY-WINDOW SUMMARY AND EPIDEMIC PEAK ---------------------------------
study <- weekly %>%
  filter(period %in% period_levels) %>%
  mutate(period = factor(period, levels = period_levels)) %>%
  group_by(period) %>%
  arrange(date, .by_group = TRUE) %>%
  mutate(relative_week = row_number()) %>%
  ungroup()

period_summary <- study %>%
  group_by(period) %>%
  summarise(
    observed_weeks = n(),
    sentinel_consultations = sum(rms_brut),
    total_estimated_cce = sum(rms_estim),
    mean_weekly_cce = mean(rms_estim),
    peak_weekly_cce = max(rms_estim),
    peak_iso_week = an_sem[which.max(rms_estim)],
    biological_cases = sum(dengue_cas_bio),
    dengue_emergency_visits = sum(pasaj_deng),
    dengue_hospital_admissions = sum(hospi_deng),
    .groups = "drop"
  )

peak_p2 <- study %>%
  filter(as.character(period) == period_levels[2]) %>%
  slice_max(rms_estim, n = 1, with_ties = FALSE)

# 07. EXCESS CCE: WEEK-MATCHED P1 BASELINE VS P2 ------------------------------
# This is an illustrative net arithmetic difference. It is not an official
# epidemiological excess-case estimate and does not prove outbreak causation.
# P3 has 31 weeks and is excluded from this 47-week matched comparison.
p1 <- study %>%
  filter(as.character(period) == period_levels[1]) %>%
  select(relative_week, baseline_iso_week = an_sem, baseline_cce = rms_estim)
p2 <- study %>%
  filter(as.character(period) == period_levels[2]) %>%
  select(relative_week, epidemic_iso_week = an_sem, epidemic_cce = rms_estim)

weekly_excess <- inner_join(p1, p2, by = "relative_week") %>%
  mutate(
    signed_weekly_excess = epidemic_cce - baseline_cce,
    positive_weekly_excess = pmax(0L, signed_weekly_excess),
    cumulative_net_excess = cumsum(signed_weekly_excess)
  )
stopifnot(nrow(weekly_excess) == 47L)

excess_summary <- weekly_excess %>%
  summarise(
    reference_weeks = n(),
    reference_total = sum(baseline_cce),
    epidemic_total = sum(epidemic_cce),
    net_excess_cce = sum(signed_weekly_excess),
    sum_positive_weekly_differences = sum(positive_weekly_excess),
    relative_difference_pct = 100 * net_excess_cce / reference_total
  )

# 08. WEEKLY SMOOTHING AND NORMALIZATION --------------------------------------
# Each disease is normalized on ITS OWN 2018-2025 range. Normalized intensity
# expresses the relative position in that series, never comparable case counts.
normalize_minmax <- function(x) {
  finite <- is.finite(x)
  if (!any(finite)) return(rep(NA_real_, length(x)))
  lo <- min(x[finite]); hi <- max(x[finite])
  if (hi <= lo) return(ifelse(finite, 0, NA_real_))
  (x - lo) / (hi - lo)
}

respiratory_vars <- c("grippe_cce", "bronchio_cce", "covid_cce")
disease_vars <- c("rms_estim", "dengue_cas_bio", respiratory_vars)

dynamics <- weekly %>%
  select(date, period, all_of(disease_vars)) %>%
  pivot_longer(all_of(disease_vars), names_to = "indicator", values_to = "count") %>%
  group_by(indicator) %>%
  arrange(date, .by_group = TRUE) %>%
  mutate(
    smoothed_3wk = zoo::rollmean(count, k = 3, fill = NA_real_, align = "center"),
    normalized_intensity = normalize_minmax(smoothed_3wk)
  ) %>%
  ungroup() %>%
  mutate(
    disease = recode(indicator,
                     rms_estim = "Dengue (sentinel CCE)",
                     dengue_cas_bio = "Dengue (biological cases)",
                     grippe_cce = "Influenza",
                     bronchio_cce = "Bronchiolitis",
                     covid_cce = "COVID-19"
    )
  )

# 09. EXPLORATORY ACTIVE WEEKS ------------------------------------------------
# The 25% threshold is calculated per-indicator, over the full 2018-2025
# synthetic series. It is NOT an official epidemiological threshold.
activity_threshold <- 0.25

active_weeks <- dynamics %>%
  filter(
    indicator != "dengue_cas_bio",
    period %in% period_levels
  ) %>%
  group_by(period, disease) %>%
  summarise(
    weeks_available = sum(!is.na(normalized_intensity)),
    active_weeks = sum(normalized_intensity >= activity_threshold, na.rm = TRUE),
    active_share_pct = 100 * active_weeks / weeks_available,
    mean_relative_intensity = mean(normalized_intensity, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(period = factor(period, levels = period_levels))

# 10. ANNUAL DISEASE SUMMARY --------------------------------------------------
annual_disease_summary <- dynamics %>%
  mutate(year = as.integer(format(date, "%Y"))) %>%
  group_by(year, disease, indicator) %>%
  summarise(
    weeks_observed = sum(!is.na(count)),
    yearly_total = sum(count, na.rm = TRUE),
    weekly_mean = mean(count, na.rm = TRUE),
    weekly_peak = max(count, na.rm = TRUE),
    .groups = "drop"
  )

# 11. SYNTHETIC HEALTHCARE UTILIZATION ----------------------------------------
# Descriptive comparison, not a causal attribution of encounters to dengue.
healthcare_utilization <- study %>%
  group_by(period) %>%
  summarise(
    weeks_observed = n(),
    total_emergency_visits_dengue = sum(pasaj_deng),
    mean_weekly_emergency_visits = mean(pasaj_deng),
    total_dengue_hospital_admissions = sum(hospi_deng),
    mean_weekly_hospital_admissions = mean(hospi_deng),
    .groups = "drop"
  )

# 12. DATA QUALITY SUMMARY ----------------------------------------------------
data_quality <- tibble::tibble(
  metric = c(
    "Weekly records (2018-2025)",
    "Distinct ISO week identifiers",
    "Missing core dengue CCE observations",
    "P1 weeks",
    "P2 weeks",
    "P3 weeks",
    "P1/P2 matched weeks",
    "Smoothed endpoints with NA (per series)",
    "Exploratory active-week threshold (%)"
  ),
  value = c(
    nrow(weekly),
    dplyr::n_distinct(weekly$an_sem),
    sum(is.na(weekly$rms_estim)),
    sum(study$period == period_levels[1]),
    sum(study$period == period_levels[2]),
    sum(study$period == period_levels[3]),
    nrow(weekly_excess),
    sum(is.na(dynamics$smoothed_3wk) & dynamics$indicator == "rms_estim"),
    activity_threshold * 100
  )
)

# 13. VISUAL CONFIGURATION ----------------------------------------------------
period_colors <- c(
  "P1 - Baseline 2022-2023" = "#5B9BD5",
  "P2 - Epidemic 2023-2024" = "#C0392B",
  "P3 - Baseline 2025" = "#F0A500"
)
disease_colors <- c(
  "Dengue" = "#C0392B",
  "Influenza" = "#8E44AD",
  "COVID-19" = "#27AE60",
  "Bronchiolitis" = "#2980B9"
)

plot_theme <- theme_minimal(base_size = 11) + theme(
  plot.title = element_text(face = "bold", size = 12),
  plot.subtitle = element_text(color = "grey40", size = 9),
  axis.text.x = element_text(size = 8),
  legend.position = "bottom",
  panel.grid.minor = element_blank(),
  panel.grid.major.x = element_blank(),
  plot.caption = element_text(color = "grey45", size = 8, hjust = 0)
)

synthetic_caption <- paste(
  "Entirely synthetic teaching example; no historical surveillance data.",
  "P1/P2/P3 are methodological windows, not observed activity."
)

save_plot <- function(name, plot, width = 14, height = 7) {
  path <- file.path(figures_dir, name)
  ggsave(path, plot = plot, width = width, height = height, dpi = 300, bg = "white")
  stopifnot(file.exists(path))
  message("Figure exported: ", path)
  invisible(path)
}

# 14. FIGURE A - FULL WEEKLY DENGUE TIMELINE ---------------------------------
p_timeline <- ggplot() +
  geom_rect(data = periods,
            aes(xmin = start - 3, xmax = end + 3,
                ymin = -Inf, ymax = Inf, fill = period),
            inherit.aes = FALSE, alpha = 0.10) +
  geom_col(data = weekly, aes(x = date, y = rms_estim),
           fill = "grey75", width = 6) +
  geom_col(data = study, aes(x = date, y = rms_estim, fill = period),
           width = 6) +
  geom_vline(xintercept = peak_p2$date, color = "#7B0000",
             linewidth = 0.6, linetype = "dashed") +
  geom_label(data = peak_p2,
             aes(x = date, y = rms_estim,
                 label = paste0("Simulated peak: ", rms_estim,
                                " CCE\n", an_sem)),
             inherit.aes = FALSE, size = 3, hjust = 0, vjust = -0.5,
             color = "#7B0000") +
  scale_fill_manual(values = period_colors, name = "Study period") +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %Y") +
  scale_y_continuous(labels = scales::label_comma(),
                     expand = expansion(mult = c(0, 0.20))) +
  coord_cartesian(clip = "off") +
  labs(
    title = "Synthetic weekly dengue CCE - full timeline (2018-2025)",
    subtitle = "Illustrative extrapolation of fictional sentinel consultations",
    x = NULL, y = "Estimated clinically suspected dengue cases (CCE)",
    caption = synthetic_caption
  ) + plot_theme + theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_plot("epidemiology_dengue_timeline_synthetic.png", p_timeline, 16, 8)

# 15. FIGURE B - RELATIVE WEEK COMPARISON ------------------------------------
p_relative <- ggplot(study, aes(x = relative_week, y = rms_estim,
                                color = period, group = period)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 1.2, alpha = 0.65) +
  geom_point(data = peak_p2, size = 4, shape = 18, color = "#7B0000") +
  geom_label(data = peak_p2,
             aes(label = paste0("Simulated peak: ", rms_estim,
                                " CCE\n", an_sem)),
             size = 3, hjust = -0.15, vjust = -0.7,
             show.legend = FALSE) +
  scale_color_manual(values = period_colors, name = "Study period") +
  scale_x_continuous(breaks = seq(1, 47, by = 4)) +
  scale_y_continuous(labels = scales::label_comma(),
                     expand = expansion(mult = c(0, 0.18))) +
  labs(
    title = "Synthetic dengue CCE - comparison of study windows",
    subtitle = "Relative weeks: P1/P2 = 47 weeks; P3 = 31 weeks",
    x = "Relative study week", y = "Estimated CCE",
    caption = synthetic_caption
  ) + plot_theme
save_plot("epidemiology_relative_weeks_synthetic.png", p_relative, 14, 7)

# 16. FIGURE C - COMPARATIVE DISEASE DYNAMICS --------------------------------
# Two versions: sentinel CCE versus biological cases for dengue. Normalizing
# each disease to 0-1 compares shapes, NEVER absolute burden or case counts.
make_dynamics_plot <- function(dengue_indicator, subtitle) {
  plot_data <- dynamics %>%
    filter(indicator %in% c(dengue_indicator, respiratory_vars)) %>%
    mutate(disease_label = recode(indicator,
                                  rms_estim = "Dengue",
                                  dengue_cas_bio = "Dengue",
                                  grippe_cce = "Influenza",
                                  bronchio_cce = "Bronchiolitis",
                                  covid_cce = "COVID-19"
    ))
  ggplot(plot_data, aes(x = date, y = normalized_intensity,
                        color = disease_label, group = disease_label)) +
    geom_rect(data = tibble::tibble(
      xmin = iso_monday("2023-W34"),
      xmax = iso_monday("2024-W13") + 6),
      aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
      inherit.aes = FALSE, fill = "#C0392B", alpha = 0.07) +
    geom_line(linewidth = 0.75, na.rm = TRUE) +
    scale_color_manual(values = disease_colors, name = NULL) +
    scale_x_date(date_breaks = "9 months", date_labels = "%b %Y") +
    scale_y_continuous(limits = c(0, 1.02), labels = scales::label_percent()) +
    labs(title = subtitle,
         x = NULL, y = "Relative intensity (% of own series range)") +
    plot_theme + theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

p_dynamics_a <- make_dynamics_plot(
  "rms_estim", "A - Dengue: extrapolated sentinel CCE"
)
p_dynamics_b <- make_dynamics_plot(
  "dengue_cas_bio", "B - Dengue: simulated biological cases"
)
p_dynamics <- (p_dynamics_a / p_dynamics_b) +
  plot_annotation(
    title = "Synthetic comparative epidemic dynamics (2018-2025)",
    subtitle = "Dengue, influenza, bronchiolitis and COVID-19 - centered 3-week moving average",
    caption = paste(
      "Each series normalized independently (min-max).",
      "Shaded dengue interval is fictional. Not a comparison of absolute disease burden."
    )
  )
save_plot("epidemiology_disease_dynamics_synthetic.png", p_dynamics, 16, 11)

# 17. FIGURE D - HEATMAP ------------------------------------------------------
heatmap_data <- dynamics %>%
  filter(indicator %in% c("rms_estim", respiratory_vars)) %>%
  mutate(disease = factor(disease,
                          levels = c("Dengue (sentinel CCE)", "Influenza", "COVID-19", "Bronchiolitis")))

p_heatmap <- ggplot(heatmap_data,
                    aes(x = date, y = disease, fill = normalized_intensity)) +
  geom_tile(height = 0.86, width = 7) +
  geom_vline(data = periods, aes(xintercept = start),
             inherit.aes = FALSE, linetype = "dashed", linewidth = 0.45,
             color = "grey25") +
  geom_vline(data = periods, aes(xintercept = end + 7),
             inherit.aes = FALSE, linetype = "dashed", linewidth = 0.45,
             color = "grey25") +
  scale_fill_gradient(low = "white", high = "#B2182B",
                      limits = c(0, 1), na.value = "grey90",
                      labels = scales::label_percent(), name = "Relative intensity") +
  scale_x_date(date_breaks = "6 months", date_labels = "%b %Y") +
  labs(
    title = "Synthetic epidemic-intensity heatmap (2018-2025)",
    subtitle = "Three-week smoothed series; min-max normalized separately",
    x = "ISO week", y = NULL,
    caption = paste(synthetic_caption,
                    "Dashed lines mark study-period boundaries.")
  ) + plot_theme +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid = element_blank())
save_plot("epidemiology_intensity_heatmap_synthetic.png", p_heatmap, 16, 6)

# 18. FIGURE E - EXPLORATORY ACTIVE WEEKS ------------------------------------
p_active <- ggplot(active_weeks,
                   aes(x = period, y = active_weeks, fill = disease)) +
  geom_col(position = position_dodge(width = 0.85), width = 0.75) +
  scale_fill_manual(values = c(
    "Dengue (sentinel CCE)" = "#C0392B",
    "Influenza" = "#8E44AD",
    "COVID-19" = "#27AE60",
    "Bronchiolitis" = "#2980B9"
  ), name = "Disease") +
  scale_y_continuous(breaks = seq(0, 50, by = 5),
                     expand = expansion(mult = c(0, 0.1))) +
  labs(
    title = "Exploratory active weeks by period and disease",
    subtitle = "Active = normalized 3-week mean >= 25% of that series' own peak",
    x = NULL, y = "Number of active weeks",
    caption = paste(
      "Synthetic values; P3 has only 31 weeks versus 47 in P1 and P2.",
      "The 25% threshold is descriptive, not an official epidemic alert level."
    )
  ) + plot_theme +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5))
save_plot("epidemiology_active_weeks_synthetic.png", p_active, 14, 7)

# 19. FIGURE F - ILLUSTRATIVE WEEK-MATCHED EXCESS -----------------------------
excess_long <- weekly_excess %>%
  select(relative_week, baseline_cce, epidemic_cce) %>%
  pivot_longer(c(baseline_cce, epidemic_cce),
               names_to = "scenario", values_to = "estimated_cce") %>%
  mutate(scenario = recode(scenario,
                           baseline_cce = "P1 - reference",
                           epidemic_cce = "P2 - epidemic"
  ))

p_excess <- ggplot(excess_long,
                   aes(x = relative_week, y = estimated_cce, color = scenario)) +
  geom_line(linewidth = 1.0) +
  scale_color_manual(values = c("P1 - reference" = "#5B9BD5",
                                "P2 - epidemic" = "#C0392B"), name = NULL) +
  labs(
    title = "Illustrative matched-week dengue CCE comparison",
    subtitle = paste0("Synthetic net difference (P2 - P1): ",
                      format(excess_summary$net_excess_cce, big.mark = ","),
                      " CCE across 47 matched weeks"),
    x = "Relative study week", y = "Estimated CCE",
    caption = paste(
      "Arithmetic scenario comparison only; not an official or causal excess-case estimate.",
      "No historical surveillance data are included."
    )
  ) + plot_theme
save_plot("epidemiology_excess_cce_synthetic.png", p_excess, 14, 7)

# 20. EXPORT ANALYTICAL TABLES ------------------------------------------------
output_tables <- list(
  "epidemiology_period_summary_synthetic.csv" = period_summary,
  "epidemiology_weekly_excess_synthetic.csv" = weekly_excess,
  "epidemiology_excess_summary_synthetic.csv" = excess_summary,
  "epidemiology_relative_weeks_synthetic.csv" = study %>%
    select(date, an_sem, period, relative_week, rms_brut, part_act,
           rms_estim, dengue_cas_bio, pasaj_deng, hospi_deng),
  "epidemiology_annual_disease_summary_synthetic.csv" = annual_disease_summary,
  "epidemiology_active_weeks_synthetic.csv" = active_weeks,
  "epidemiology_healthcare_utilization_synthetic.csv" = healthcare_utilization,
  "epidemiology_data_quality_synthetic.csv" = data_quality
)

for (filename in names(output_tables)) {
  readr::write_csv(output_tables[[filename]], file.path(tables_dir, filename))
}

# 21. FINAL CHECKS ------------------------------------------------------------
figure_names <- c(
  "epidemiology_dengue_timeline_synthetic.png",
  "epidemiology_relative_weeks_synthetic.png",
  "epidemiology_disease_dynamics_synthetic.png",
  "epidemiology_intensity_heatmap_synthetic.png",
  "epidemiology_active_weeks_synthetic.png",
  "epidemiology_excess_cce_synthetic.png"
)
stopifnot(
  nrow(study) == 125L,
  nrow(weekly_excess) == 47L,
  all(file.exists(file.path(tables_dir, names(output_tables)))),
  all(file.exists(file.path(figures_dir, figure_names))),
  file.exists(file.path(input_dir, "weekly_surveillance_synthetic.csv")),
  all(is.finite(excess_summary$net_excess_cce))
)

cat("\n=====================================================\n")
cat("EPIDEMIOLOGICAL ANALYSIS - SYNTHETIC MODULE COMPLETE\n")
cat("=====================================================\n")
cat("Weekly observations (2018-2025):", nrow(weekly), "\n")
cat("Study periods: P1 = 47, P2 = 47, P3 = 31 weeks\n")
cat("Synthetic P2 peak:", peak_p2$rms_estim, "CCE (", peak_p2$an_sem, ")\n")
cat("Illustrative net P2-P1 excess:", excess_summary$net_excess_cce, "CCE\n")
cat("Figure files:", length(figure_names), "\n")
cat("Output tables:", length(output_tables), "\n")
cat("All observations and results are synthetic.\n")
cat("No Santé publique France or partner datasets were accessed.\n")
cat("=====================================================\n")

