# =============================================================================
# DENGUE MEDICO-ECONOMIC ANALYSIS IN MARTINIQUE
# SUPPLEMENT - CASE COUNTS, AGE DISTRIBUTION AND HOSPITALIZATION PROXIES
# Author: Marie-Noelle Nogeant | Synthetic portfolio adaptation, 2026
# =============================================================================
# Inspired by the methodological structure of "NOMBRES DE CAS" (2026-06-01).
# Entirely synthetic: no original Santé publique France or partner data.
#
# P1: 2022 W30 to 2023 W24 (47 ISO weeks)
# P2: 2023 W30 to 2024 W24 (47 ISO weeks)
# P3: 2025 W18 to W48       (31 ISO weeks)
#
# Hospitalizations divided by CCE, confirmed cases or ED visits are descriptive
# ratios of aggregated events, NOT patient-level hospitalization risks.
# =============================================================================

# 01 - PACKAGES AND PROJECT DIRECTORY ----------------------------------------
packages <- c("dplyr", "tidyr", "ggplot2", "readr", "ISOweek", "scales")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Missing packages: ", paste(missing, collapse = ", "),
       ". Install them with install.packages().")
}
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

project_dir <- getwd()
if (!dir.exists(file.path(project_dir, "R"))) {
  project_dir <- path.expand("~/Documents/dengue-medico-economic-analysis")
}
if (!dir.exists(file.path(project_dir, "R"))) {
  stop("Set the working directory to the repository root containing R/.")
}

input_file <- file.path(project_dir, "data", "simulated", "epidemiology",
                        "weekly_surveillance_synthetic.csv")
if (!file.exists(input_file)) {
  stop("Synthetic weekly input missing. Run ",
       "R/epidemiological_analysis_synthetic.R first.")
}
tables_dir <- file.path(project_dir, "outputs", "tables")
figures_dir <- file.path(project_dir, "outputs", "figures")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

# 02 - READ AND VALIDATE EXISTING SYNTHETIC OBSERVATIONS ----------------------
weekly <- readr::read_csv(input_file, show_col_types = FALSE) %>%
  mutate(date = as.Date(date)) %>%
  arrange(date)

required <- c("date", "an_sem", "rms_brut", "rms_estim", "cas_conf",
              "cas_prob", "pasaj_deng", "hospi_deng")
absent <- setdiff(required, names(weekly))
if (length(absent)) stop("Missing synthetic variables: ", paste(absent, collapse = ", "))
if (nrow(weekly) == 0L || anyNA(weekly[, required]) ||
    anyDuplicated(weekly$date) || !all(diff(weekly$date) == 7) ||
    any(as.matrix(weekly[, required[-c(1, 2)]]) < 0) ||
    any(!is.finite(as.matrix(weekly[, required[-c(1, 2)]])))) {
  stop("Synthetic weekly data failed basic quality checks.")
}
if (!all(weekly$an_sem == gsub("-W", "_", ISOweek::ISOweek(weekly$date)))) {
  stop("ISO-week labels and dates do not agree.")
}

iso_monday <- function(x) as.Date(ISOweek::ISOweek2date(paste0(x, "-1")))
windows <- tibble::tibble(
  period = c("P1", "P2", "P3"),
  label = c("P1 - Baseline 2022-2023", "P2 - Epidemic scenario 2023-2024",
            "P3 - Baseline 2025"),
  start = iso_monday(c("2022-W30", "2023-W30", "2025-W18")),
  end = iso_monday(c("2023-W24", "2024-W24", "2025-W48")),
  expected_weeks = c(47L, 47L, 31L)
)

period_of <- function(dates) {
  dplyr::case_when(
    dates >= windows$start[1] & dates <= windows$end[1] ~ "P1",
    dates >= windows$start[2] & dates <= windows$end[2] ~ "P2",
    dates >= windows$start[3] & dates <= windows$end[3] ~ "P3",
    TRUE ~ NA_character_
  )
}

study <- weekly %>%
  mutate(period = period_of(date)) %>%
  filter(!is.na(period)) %>%
  mutate(period = factor(period, levels = windows$period))

week_counts <- study %>% count(period, name = "weeks")
stopifnot(identical(week_counts$weeks, windows$expected_weeks))

# 03 - PERIOD AGGREGATES -------------------------------------------------------
period_summary <- study %>%
  group_by(period) %>%
  summarise(
    weeks = n(),
    first_iso_week = first(an_sem),
    last_iso_week = last(an_sem),
    sentinel_raw = sum(rms_brut),
    estimated_cce = sum(rms_estim),
    confirmed_cases = sum(cas_conf),
    probable_cases = sum(cas_prob),
    biological_cases = sum(cas_conf + cas_prob),
    emergency_visits = sum(pasaj_deng),
    hospital_admissions = sum(hospi_deng),
    .groups = "drop"
  ) %>%
  mutate(
    mean_weekly_cce = estimated_cce / weeks,
    mean_weekly_emergency_visits = emergency_visits / weeks,
    mean_weekly_hospital_admissions = hospital_admissions / weeks
  )

# 04 - ABSOLUTE DIFFERENCES AND DURATION-STANDARDIZED COMPARISONS -------------
# Raw P3-P1 totals compare 31 versus 47 weeks. They are descriptive only.
# The duration-standardized P3 difference compares P3 to 31 times the P1
# weekly average; it is still not a causal or seasonal-adjusted estimate.
indicator_cols <- c(
  "Sentinel consultations" = "sentinel_raw",
  "Estimated dengue CCE" = "estimated_cce",
  "Confirmed dengue cases" = "confirmed_cases",
  "Probable dengue cases" = "probable_cases",
  "Emergency department visits" = "emergency_visits",
  "Hospital admissions" = "hospital_admissions"
)
n_weeks <- period_summary$weeks

difference_summary <- dplyr::bind_rows(lapply(seq_along(indicator_cols), function(i) {
  x <- period_summary[[unname(indicator_cols[i])]]
  weekly_mean <- x / n_weeks
  tibble::tibble(
    indicator = names(indicator_cols)[i],
    p1_total = x[1], p2_total = x[2], p3_total = x[3],
    p2_minus_p1_total = x[2] - x[1],
    p3_minus_p1_raw_total = x[3] - x[1],
    p1_weekly_mean = weekly_mean[1],
    p2_weekly_mean = weekly_mean[2],
    p3_weekly_mean = weekly_mean[3],
    p2_minus_p1_weekly_mean = weekly_mean[2] - weekly_mean[1],
    p3_minus_p1_weekly_mean = weekly_mean[3] - weekly_mean[1],
    p3_minus_duration_adjusted_p1 = x[3] - weekly_mean[1] * n_weeks[3]
  )
}))

# 05 - SYNTHETIC AGE STRATIFICATION FOR ALL THREE STUDY PERIODS ---------------
# Use precisely the same arbitrary probabilities, seed and call order as the
# previously published care/cost supplement, enabling P2 reconciliation.
# No observed age distributions are used. Categories mean <5, 5-14, etc.
set.seed(20261113)
age_labels <- c("< 5", "5-14", "15-44", "45-64", "65+")
age_keys <- c("lt5", "5to14", "15to44", "45to64", "65plus")
ed_prob <- c(0.12, 0.10, 0.44, 0.24, 0.10)
hosp_prob <- c(0.07, 0.08, 0.31, 0.27, 0.27)
stopifnot(isTRUE(all.equal(sum(ed_prob), 1)),
          isTRUE(all.equal(sum(hosp_prob), 1)))

allocate_by_age <- function(counts, probabilities, prefix) {
  draws <- t(vapply(counts, function(value) {
    if (is.na(value) || value < 0 || value != as.integer(value)) {
      stop("Age allocation expects nonnegative integer event counts.")
    }
    as.integer(rmultinom(n = 1L, size = as.integer(value),
                        prob = probabilities)[, 1])
  }, integer(length(probabilities))))
  colnames(draws) <- paste0(prefix, "_", age_keys)
  tibble::as_tibble(draws)
}

ed_by_age <- allocate_by_age(weekly$pasaj_deng, ed_prob, "ed")
hosp_by_age <- allocate_by_age(weekly$hospi_deng, hosp_prob, "hosp")
ed_columns <- paste0("ed_", age_keys)
hosp_columns <- paste0("hosp_", age_keys)

age_weekly <- dplyr::bind_cols(
  weekly %>% select(date, pasaj_deng, hospi_deng),
  ed_by_age, hosp_by_age
) %>%
  mutate(period = period_of(date))

stopifnot(
  all(rowSums(as.matrix(age_weekly[, ed_columns])) == age_weekly$pasaj_deng),
  all(rowSums(as.matrix(age_weekly[, hosp_columns])) == age_weekly$hospi_deng)
)

age_by_period <- age_weekly %>%
  filter(!is.na(period)) %>%
  group_by(period) %>%
  summarise(across(all_of(c(ed_columns, hosp_columns)), sum),
            .groups = "drop") %>%
  pivot_longer(
    cols = -period,
    names_to = c("event", "age_key"),
    names_pattern = "^(ed|hosp)_(lt5|5to14|15to44|45to64|65plus)$",
    values_to = "count"
  ) %>%
  mutate(
    age_group = factor(age_labels[match(age_key, age_keys)], levels = age_labels),
    encounter = dplyr::recode(event, ed = "Emergency visits",
                              hosp = "Hospital admissions"),
    period = factor(period, levels = windows$period)
  ) %>%
  group_by(period, encounter) %>%
  mutate(share_pct = if (sum(count) > 0) {
    100 * count / sum(count)
  } else {
    NA_real_
  }) %>%
  ungroup() %>%
  select(period, encounter, age_group, count, share_pct) %>%
  arrange(period, encounter, age_group)

age_checks <- age_by_period %>%
  group_by(period, encounter) %>%
  summarise(age_total = sum(count), .groups = "drop") %>%
  mutate(
    source_total = if_else(
      encounter == "Emergency visits",
      period_summary$emergency_visits[match(as.character(period), as.character(period_summary$period))],
      period_summary$hospital_admissions[match(as.character(period), as.character(period_summary$period))]
    ),
    difference = age_total - source_total
  )
stopifnot(nrow(age_checks) == 6L, all(age_checks$difference == 0))

# 06 - HOSPITALIZATION PROXIES -------------------------------------------------
safe_per_100 <- function(numerator, denominator) {
  ifelse(denominator > 0, 100 * numerator / denominator, NA_real_)
}
hospitalization_proxies <- period_summary %>%
  transmute(
    period,
    hospital_admissions,
    estimated_cce,
    confirmed_cases,
    emergency_visits,
    admissions_per_100_estimated_cce = safe_per_100(hospital_admissions, estimated_cce),
    admissions_per_100_confirmed_cases = safe_per_100(hospital_admissions, confirmed_cases),
    admissions_per_100_emergency_visits = safe_per_100(hospital_admissions, emergency_visits)
  )

# 07 - FIGURES ----------------------------------------------------------------
colors_period <- c(P1 = "#5B9BD5", P2 = "#C0392B", P3 = "#F0A500")
theme_report <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        legend.position = "bottom",
        plot.title = element_text(face = "bold", size = 12))

p_counts <- period_summary %>%
  mutate(annotation = paste0(round(mean_weekly_cce, 1), " per week\n",
                              scales::comma(estimated_cce), " total (",
                              weeks, " weeks)")) %>%
  ggplot(aes(x = period, y = mean_weekly_cce, fill = period)) +
  geom_col(width = 0.62) +
  geom_text(aes(label = annotation), vjust = -0.25, size = 3.1) +
  scale_fill_manual(values = colors_period, guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.24))) +
  labs(title = "Synthetic dengue CCE by study period",
       subtitle = "Weekly averages account for the shorter P3 observation window",
       x = NULL, y = "Mean estimated CCE per ISO week",
       caption = "All observations are fabricated; study dates indicate comparison windows only.") +
  theme_report

p_age <- ggplot(age_by_period,
                aes(x = age_group, y = share_pct, fill = period)) +
  geom_col(position = position_dodge(width = 0.77), width = 0.70) +
  facet_wrap(~ encounter, nrow = 1) +
  scale_fill_manual(values = colors_period) +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  labs(title = "Fictional age distribution of dengue-related care encounters",
       subtitle = "Multinomial age allocation; percentages calculated within each period and care type",
       x = "Age group", y = "Share of care encounters", fill = "Period",
       caption = "Emergency visits and admissions may overlap; these are not unique patients.") +
  theme_report +
  theme(axis.text.x = element_text(angle = 25, hjust = 1))

diff_plot <- difference_summary %>%
  select(indicator, p2_minus_p1_weekly_mean, p3_minus_p1_weekly_mean) %>%
  pivot_longer(-indicator, names_to = "comparison", values_to = "weekly_difference") %>%
  mutate(comparison = recode(comparison,
    p2_minus_p1_weekly_mean = "P2 - P1",
    p3_minus_p1_weekly_mean = "P3 - P1"))

p_diff <- ggplot(diff_plot,
                 aes(x = comparison, y = weekly_difference, fill = comparison)) +
  geom_hline(yintercept = 0, color = "grey40", linewidth = 0.35) +
  geom_col(width = 0.62) +
  facet_wrap(~indicator, scales = "free_y", ncol = 2) +
  scale_fill_manual(values = c("P2 - P1" = "#C0392B", "P3 - P1" = "#F0A500"),
                    guide = "none") +
  labs(title = "Synthetic differences relative to the P1 reference",
       subtitle = "Differences in average counts per week, not a causal excess estimate",
       x = NULL, y = "Difference in mean events per week",
       caption = "P3 covers 31 weeks versus 47 in P1/P2; timing and seasonality are not adjusted.") +
  theme_report +
  theme(axis.text.x = element_text(size = 8))

proxy_plot <- hospitalization_proxies %>%
  select(period, starts_with("admissions_per_100_")) %>%
  pivot_longer(-period, names_to = "denominator", values_to = "per_100") %>%
  mutate(denominator = recode(denominator,
    admissions_per_100_estimated_cce = "Per 100 estimated CCE",
    admissions_per_100_confirmed_cases = "Per 100 confirmed cases",
    admissions_per_100_emergency_visits = "Per 100 emergency visits"))

p_proxy <- ggplot(proxy_plot, aes(x = period, y = per_100, fill = period)) +
  geom_col(width = 0.62) +
  facet_wrap(~denominator, scales = "free_y", nrow = 1) +
  scale_fill_manual(values = colors_period, guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Descriptive ratios of aggregated synthetic events",
       subtitle = "These measures are NOT person-level hospitalization rates or ED admission probabilities",
       x = NULL, y = "Admissions per 100 denominator events") +
  theme_report

figures <- list(
  "epidemiology_case_period_counts_synthetic.png" = p_counts,
  "epidemiology_case_age_distribution_synthetic.png" = p_age,
  "epidemiology_case_weekly_differences_synthetic.png" = p_diff,
  "epidemiology_case_hospitalization_proxies_synthetic.png" = p_proxy
)
for (filename in names(figures)) {
  ggsave(file.path(figures_dir, filename), figures[[filename]],
         width = if (grepl("age_distribution|hospitalization_proxies", filename)) 13 else 12,
         height = if (grepl("weekly_differences", filename)) 9 else 7,
         dpi = 300, bg = "white")
}

# 08 - TABLE EXPORTS AND FINAL QUALITY CHECKS ---------------------------------
quality_summary <- dplyr::bind_rows(
  tibble::tibble(check = "Input observation weeks", value = nrow(weekly)),
  tibble::tibble(check = paste0(windows$period, " weeks"), value = week_counts$weeks),
  tibble::tibble(check = "ED age-allocation discrepancy", value =
                   sum(age_checks$difference[age_checks$encounter == "Emergency visits"])),
  tibble::tibble(check = "Admission age-allocation discrepancy", value =
                   sum(age_checks$difference[age_checks$encounter == "Hospital admissions"]))
)

tables <- list(
  "epidemiology_case_period_summary_synthetic.csv" = period_summary,
  "epidemiology_case_period_differences_synthetic.csv" = difference_summary,
  "epidemiology_case_age_by_period_synthetic.csv" = age_by_period,
  "epidemiology_case_hospitalization_proxies_synthetic.csv" = hospitalization_proxies,
  "epidemiology_case_quality_synthetic.csv" = quality_summary
)
for (filename in names(tables)) {
  readr::write_csv(tables[[filename]], file.path(tables_dir, filename))
}
stopifnot(
  all(file.exists(file.path(figures_dir, names(figures)))),
  all(file.exists(file.path(tables_dir, names(tables)))),
  all(age_checks$difference == 0),
  period_summary$estimated_cce[2] - period_summary$estimated_cce[1] ==
    difference_summary$p2_minus_p1_total[
      difference_summary$indicator == "Estimated dengue CCE"]
)

cat("\n============================================================\n")
cat("CASE COUNTS AND HOSPITALIZATION - SYNTHETIC SUPPLEMENT COMPLETE\n")
cat("============================================================\n")
cat("P1/P2/P3 ISO weeks:", paste(period_summary$weeks, collapse = "/"), "\n")
cat("Synthetic P2 estimated CCE:", period_summary$estimated_cce[2], "\n")
cat("Synthetic P2 ED encounters:", period_summary$emergency_visits[2], "\n")
cat("Synthetic P2 hospital admissions:", period_summary$hospital_admissions[2], "\n")
cat("Age groups:", length(age_labels), "\n")
cat("Figures exported:", length(figures), "\n")
cat("Tables exported:", length(tables), "\n")
cat("All numbers and age allocations are synthetic.\n")
cat("Aggregated ratios are NOT patient-level hospitalization risks.\n")
cat("No original Santé publique France or partner files were accessed.\n")
cat("============================================================\n")
