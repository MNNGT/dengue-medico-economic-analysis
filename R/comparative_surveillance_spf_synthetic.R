# =============================================================================
# DENGUE MEDICO-ECONOMIC ANALYSIS IN MARTINIQUE
# SUPPLEMENT - COMPARATIVE SURVEILLANCE (SYNTHETIC DATA ONLY)
# Author: Marie-Noelle Nogeant | Public portfolio adaptation, 2026
# =============================================================================
#
# PURPOSE
#   Reproduce the methodological structure of a comparative surveillance
#   visualization requested again by a public-health research partner.
#
#   Two dengue indicators are displayed separately:
#   A) Estimated dengue sentinel consultations (CCE; rms_estim)
#   B) Biological dengue cases (confirmed + probable; dengue_cas_bio)
#
#   Each is compared with synthetic influenza, COVID-19 and bronchiolitis
#   sentinel CCE series after centered three-week smoothing and independent
#   min-max normalization. Two alternative study-period display windows are
#   supported: long (Jul-Jun ISO weeks) and strict (Jul-Mar).
#
# SAFETY AND INTERPRETATION
#   All observations and flagged study windows are illustrative. This script
#   reads ONLY the synthetic data created by epidemiological_analysis_synthetic.R.
#   It does NOT read or reproduce any original partner Excel files or results.
#   Independently normalized curves reveal relative timing/patterns, NOT
#   comparable disease burdens. Biological cases are not the same indicator
#   as extrapolated sentinel consultations. Study windows are not estimates
#   of actual outbreak onset/ending. Neither window should be confused with
#   financial OpenDamir eligibility dates without separate validation.
# =============================================================================

# 01. DEPENDENCIES ------------------------------------------------------------
required_packages <- c("readr", "dplyr", "tidyr", "ggplot2", "zoo",
                       "patchwork", "ISOweek", "scales", "tibble")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop("Missing R packages: ", paste(missing_packages, collapse = ", "),
       ". Install with install.packages(c(",
       paste(sprintf('"%s"', missing_packages), collapse = ", "), ")).")
}
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(patchwork)
})

# 02. PROJECT LOCATION --------------------------------------------------------
project_dir <- getwd()
if (!dir.exists(file.path(project_dir, "R"))) {
  project_dir <- path.expand("~/Documents/dengue-medico-economic-analysis")
}
if (!dir.exists(file.path(project_dir, "R"))) {
  stop("Repository root not found. Open the project in RStudio or setwd() ",
       "to the folder containing R/ and outputs/.")
}

input_path <- file.path(project_dir, "data", "simulated", "epidemiology",
                        "weekly_surveillance_synthetic.csv")
figures_dir <- file.path(project_dir, "outputs", "figures")
tables_dir <- file.path(project_dir, "outputs", "tables")

if (!file.exists(input_path)) {
  stop("Synthetic weekly input not found: ", input_path, "\n",
       "Run R/epidemiological_analysis_synthetic.R first.")
}
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

# 03. READ AND VALIDATE ONLY SYNTHETIC DATA ----------------------------------
weekly <- readr::read_csv(input_path, show_col_types = FALSE) %>%
  mutate(date = as.Date(date)) %>%
  arrange(date)

needed <- c("date", "an_sem", "rms_estim", "cas_conf", "cas_prob",
            "dengue_cas_bio", "grippe_cce", "covid_cce", "bronchio_cce")
missing_columns <- setdiff(needed, names(weekly))
if (length(missing_columns)) {
  stop("Missing input columns: ", paste(missing_columns, collapse = ", "))
}

measure_vars <- c("rms_estim", "cas_conf", "cas_prob", "dengue_cas_bio",
                  "grippe_cce", "covid_cce", "bronchio_cce")
if (anyNA(weekly[, needed]) || anyDuplicated(weekly$date) ||
    any(!is.finite(as.matrix(weekly[, measure_vars]))) ||
    any(as.matrix(weekly[, measure_vars]) < 0) ||
    !all(weekly$cas_conf + weekly$cas_prob == weekly$dengue_cas_bio)) {
  stop("Synthetic input failed data quality checks.")
}
if (!all(diff(weekly$date) == 7)) {
  stop("The synthetic surveillance timeline must contain consecutive ISO weeks.")
}

# The source script creates a complete 2018-2025 weekly series. Restrict the
# comparison to calendar years 2022-2025, as in the reference visualizations.
plot_data <- weekly %>%
  filter(date >= as.Date("2022-01-01"),
         date <= as.Date("2025-12-31")) %>%
  arrange(date)
if (nrow(plot_data) < 150L) {
  stop("Insufficient synthetic weeks for the 2022-2025 comparison.")
}

# 04. CENTERED MOVING AVERAGE AND INDEPENDENT MIN-MAX NORMALIZATION ----------
# Keep NA at the start/end of the three-week window; never impute them as zero.
roll3 <- function(x) {
  zoo::rollmean(x, k = 3, fill = NA_real_, align = "center")
}
normalize_01 <- function(x) {
  available <- x[is.finite(x)]
  if (!length(available)) return(rep(NA_real_, length(x)))
  lo <- min(available)
  hi <- max(available)
  if (hi == lo) return(ifelse(is.na(x), NA_real_, 0))
  (x - lo) / (hi - lo)
}

plot_data <- plot_data %>%
  mutate(
    dengue_rms_3w = roll3(rms_estim),
    dengue_bio_3w = roll3(dengue_cas_bio),
    influenza_3w = roll3(grippe_cce),
    covid_3w = roll3(covid_cce),
    bronchiolitis_3w = roll3(bronchio_cce),
    dengue_rms_norm = normalize_01(dengue_rms_3w),
    dengue_bio_norm = normalize_01(dengue_bio_3w),
    influenza_norm = normalize_01(influenza_3w),
    covid_norm = normalize_01(covid_3w),
    bronchiolitis_norm = normalize_01(bronchiolitis_3w)
  )

norm_vars <- c("dengue_rms_norm", "dengue_bio_norm", "influenza_norm",
               "covid_norm", "bronchiolitis_norm")
valid_norm <- unlist(plot_data[norm_vars], use.names = FALSE)
valid_norm <- valid_norm[is.finite(valid_norm)]
stopifnot(length(valid_norm) > 0L,
          all(valid_norm >= -1e-10), all(valid_norm <= 1 + 1e-10))

# 05. TWO ACTUAL PERIOD DEFINITIONS -----------------------------------------
# Long: exact 47-week P1/P2 ISO windows from the epidemiological analysis.
# Strict: weeks with Mondays between the same July starts and March 31.
# P3 is unchanged. These are GRAPHICAL ANALYSIS WINDOWS, not exact
# reimbursement eligibility definitions.
iso_monday <- function(year_week) {
  as.Date(ISOweek::ISOweek2date(paste0(year_week, "-1")))
}

period_definitions <- tibble::tibble(
  mode = rep(c("long", "strict"), each = 3),
  period = rep(c("P1 - Reference", "P2 - Epidemic scenario", "P3 - Reference"), 2),
  start_date = as.Date(c(
    iso_monday("2022-W30"), iso_monday("2023-W30"), iso_monday("2025-W18"),
    iso_monday("2022-W30"), iso_monday("2023-W30"), iso_monday("2025-W18")
  )),
  end_date = as.Date(c(
    iso_monday("2023-W24"), iso_monday("2024-W24"), iso_monday("2025-W48"),
    as.Date("2023-03-31"), as.Date("2024-03-31"), iso_monday("2025-W48")
  ))
) %>%
  mutate(
    # Actual included observations are weekly Mondays; shading finishes
    # after the last included Monday, up to the relevant end boundary.
    display_end = if_else(
      mode == "long" | period == "P3 - Reference",
      end_date + 6,
      end_date
    ),
    period = factor(period,
                    levels = c("P1 - Reference", "P2 - Epidemic scenario", "P3 - Reference"))
  )

# 06. TALLY PERIOD COUNTS AND SUMMARY FOR BOTH MODES --------------------------
period_summary_list <- list()
for (mode_name in c("long", "strict")) {
  defs <- period_definitions %>% filter(mode == mode_name)
  selected <- dplyr::bind_rows(lapply(seq_len(nrow(defs)), function(i) {
    plot_data %>%
      filter(date >= defs$start_date[i], date <= defs$end_date[i]) %>%
      mutate(mode = mode_name, period = as.character(defs$period[i]))
  }))
  period_summary_list[[mode_name]] <- selected %>%
    group_by(mode, period) %>%
    summarise(
      observed_weeks = n(),
      dengue_sentinel_cce = sum(rms_estim),
      dengue_biological_cases = sum(dengue_cas_bio),
      influenza_sentinel_cce = sum(grippe_cce),
      covid_sentinel_cce = sum(covid_cce),
      bronchiolitis_sentinel_cce = sum(bronchio_cce),
      dengue_sentinel_weekly_mean = mean(rms_estim),
      dengue_biological_weekly_mean = mean(dengue_cas_bio),
      .groups = "drop"
    )
}
period_summary <- bind_rows(period_summary_list) %>%
  arrange(mode, period)

long_counts <- period_summary %>% filter(mode == "long")
strict_counts <- period_summary %>% filter(mode == "strict")
stopifnot(
  identical(as.integer(long_counts$observed_weeks), c(47L, 47L, 31L)),
  identical(as.integer(strict_counts$observed_weeks), c(36L, 36L, 31L)),
  all(strict_counts$observed_weeks <= long_counts$observed_weeks)
)

# 07. VISUAL PRESENTATION ------------------------------------------------------
palette_disease <- c(
  "Dengue" = "#E63946",
  "Influenza" = "#457B9D",
  "COVID-19" = "#6A994E",
  "Bronchiolitis" = "#9B72CF"
)
palette_period <- c(
  "P1 - Reference" = "#DCEAF7",
  "P2 - Epidemic scenario" = "#FADADD",
  "P3 - Reference" = "#DDEEDC"
)
line_widths <- c(
  "Dengue" = 1.2,
  "Influenza" = 0.8,
  "COVID-19" = 0.8,
  "Bronchiolitis" = 0.8
)

# One tick per ISO week, but display only the first Monday in each month.
weekly_breaks <- seq(as.Date("2022-01-03"), as.Date("2025-12-22"), by = "week")
weekly_labels <- ifelse(
  as.integer(format(weekly_breaks, "%d")) <= 7,
  format(weekly_breaks, "%b %Y"),
  ""
)

plot_theme <- theme_minimal(base_size = 11) +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA),
    legend.position = "bottom",
    legend.key.width = grid::unit(1.2, "cm"),
    axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5, size = 7),
    axis.ticks.x = element_line(color = "grey60"),
    axis.ticks.length = grid::unit(0.12, "cm"),
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(size = 9, color = "grey40"),
    plot.caption = element_text(size = 8, color = "grey50"),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(color = "grey93"),
    panel.grid.major.y = element_line(color = "grey90")
  )

# 08. PLOT GENERATOR ----------------------------------------------------------
make_comparison_plot <- function(mode_name, dengue_variant = c("rms", "bio")) {
  dengue_variant <- match.arg(dengue_variant)
  defs <- period_definitions %>%
    filter(mode == mode_name) %>%
    mutate(
      midpoint = start_date + as.numeric(display_end - start_date) / 2,
      band_label = c(
        "P1 - Reference",
        "P2 - Illustrative epidemic",
        "P3 - Reference"
      )
    )
  
  dengue_col <- if (dengue_variant == "rms") "dengue_rms_norm" else "dengue_bio_norm"
  dengue_subtitle <- if (dengue_variant == "rms") {
    "Dengue: extrapolated sentinel consultations (CCE)"
  } else {
    "Dengue: biologically confirmed + probable cases (different indicator)"
  }
  
  long_data <- plot_data %>%
    transmute(
      date,
      Dengue = .data[[dengue_col]],
      Influenza = influenza_norm,
      `COVID-19` = covid_norm,
      Bronchiolitis = bronchiolitis_norm
    ) %>%
    pivot_longer(-date, names_to = "disease", values_to = "relative_intensity") %>%
    mutate(disease = factor(disease, levels = names(palette_disease)))
  
  ggplot() +
    geom_rect(
      data = defs,
      aes(xmin = start_date, xmax = display_end,
          ymin = -Inf, ymax = Inf, fill = period),
      inherit.aes = FALSE,
      alpha = 0.35
    ) +
    geom_line(
      data = long_data,
      aes(x = date, y = relative_intensity,
          color = disease, linewidth = disease),
      na.rm = TRUE
    ) +
    geom_text(
      data = defs,
      aes(x = midpoint, y = 1.12, label = band_label),
      inherit.aes = FALSE,
      size = 2.5,
      color = "#374151",
      fontface = "bold"
    ) +
    scale_color_manual(values = palette_disease, name = NULL) +
    scale_linewidth_manual(values = line_widths, guide = "none") +
    scale_fill_manual(values = palette_period, guide = "none") +
    scale_x_date(
      breaks = weekly_breaks,
      labels = weekly_labels,
      limits = as.Date(c("2022-01-01", "2025-12-31")),
      expand = expansion(mult = c(0, 0))
    ) +
    scale_y_continuous(
      breaks = seq(0, 1, 0.25),
      labels = c("0", "25%", "50%", "75%", "100% (peak)"),
      limits = c(0, 1.18),
      expand = expansion(mult = c(0, 0))
    ) +
    labs(
      title = if (dengue_variant == "rms") {
        "A - Comparative sentinel surveillance"
      } else {
        "B - Comparative surveillance with biological dengue cases"
      },
      subtitle = paste(dengue_subtitle, "|", toupper(mode_name), "study-period windows"),
      x = "ISO epidemiological week",
      y = "Relative intensity (independently normalized)",
      caption = paste(
        "Synthetic data only. Centered 3-week averages and independent min-max normalization.",
        "Shading represents illustrative analysis windows; not official outbreak boundaries."
      )
    ) +
    plot_theme +
    guides(color = guide_legend(nrow = 1, override.aes = list(linewidth = 1)))
}

# 09. EXPORT SIX FIGURES (THREE FOR EACH PERIOD MODE) --------------------------
figure_paths <- character()
for (mode_name in c("long", "strict")) {
  plot_a <- make_comparison_plot(mode_name, "rms")
  plot_b <- make_comparison_plot(mode_name, "bio")
  plot_combined <- (plot_a / plot_b) +
    plot_annotation(
      title = paste("Synthetic comparative disease dynamics (2022-2025) -", toupper(mode_name), "windows"),
      caption = paste(
        "Methodological demonstration using fabricated weekly observations.",
        "Dengue sentinel CCE and biological counts are different surveillance measures."
      ),
      theme = theme(plot.title = element_text(face = "bold", size = 14),
                    plot.background = element_rect(fill = "white", color = NA))
    )
  
  files <- c(
    rms = paste0("comparative_surveillance_spf_", mode_name, "_rms_synthetic.png"),
    bio = paste0("comparative_surveillance_spf_", mode_name, "_bio_synthetic.png"),
    comparison = paste0("comparative_surveillance_spf_", mode_name, "_comparison_synthetic.png")
  )
  plots <- list(rms = plot_a, bio = plot_b, comparison = plot_combined)
  for (key in names(files)) {
    file_path <- file.path(figures_dir, files[[key]])
    ggplot2::ggsave(
      filename = file_path,
      plot = plots[[key]],
      width = 18,
      height = if (key == "comparison") 12 else 7,
      dpi = 300,
      bg = "white"
    )
    figure_paths <- c(figure_paths, file_path)
  }
}

# 10. EXPORTED SUMMARY AND QUALITY TABLES ------------------------------------
period_definitions_table <- period_definitions %>%
  select(mode, period, start_date, end_date, display_end) %>%
  left_join(
    period_summary %>% select(mode, period, observed_weeks),
    by = c("mode", "period")
  )

quality_summary <- tibble::tibble(
  check = c(
    "Input is synthetic weekly data from project",
    "Weekly records in source",
    "Weeks displayed (2022-2025)",
    "Missing values in displayed raw measures",
    "Duplicate ISO dates",
    "Bio dengue components reconcile",
    "Long P1 weeks", "Long P2 weeks", "Long P3 weeks",
    "Strict P1 weeks", "Strict P2 weeks", "Strict P3 weeks",
    "Period modes", "Figures exported", "Summary tables exported"
  ),
  value = as.character(c(
    TRUE, nrow(weekly), nrow(plot_data),
    sum(is.na(plot_data[, measure_vars])),
    anyDuplicated(plot_data$date),
    all(plot_data$cas_conf + plot_data$cas_prob == plot_data$dengue_cas_bio),
    long_counts$observed_weeks,
    strict_counts$observed_weeks,
    2L, length(figure_paths), 3L
  ))
)

out_tables <- list(
  comparative_surveillance_spf_period_definitions_synthetic.csv = period_definitions_table,
  comparative_surveillance_spf_period_summary_synthetic.csv = period_summary,
  comparative_surveillance_spf_quality_synthetic.csv = quality_summary
)
table_paths <- file.path(tables_dir, names(out_tables))
for (name in names(out_tables)) {
  readr::write_csv(out_tables[[name]], file.path(tables_dir, name))
}

# 11. FINAL VERIFICATION -------------------------------------------------------
stopifnot(
  length(figure_paths) == 6L,
  all(file.exists(figure_paths)),
  length(table_paths) == 3L,
  all(file.exists(table_paths)),
  all(file.info(c(figure_paths, table_paths))$size > 0)
)

cat("\n==============================================================\n")
cat("COMPARATIVE SURVEILLANCE - SYNTHETIC SPF WORKFLOW COMPLETE\n")
cat("==============================================================\n")
cat("Synthetic weekly observations displayed:", nrow(plot_data), "\n")
cat("Period definitions: long (47/47/31) and strict (36/36/31) weeks\n")
cat("Dengue indicators: sentinel CCE and confirmed + probable cases\n")
cat("Other diseases: influenza, COVID-19, bronchiolitis\n")
cat("Figures exported:", length(figure_paths), "\n")
cat("Tables exported:", length(table_paths), "\n")
cat("All source observations and graphic interpretations are synthetic.\n")
cat("No original Santé publique France or partner files were accessed.\n")
cat("==============================================================\n")
