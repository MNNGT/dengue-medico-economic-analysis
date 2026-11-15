# Dengue Epidemiological Surveillance Dashboard
# Synthetic-data portfolio project | R Shiny
# This application does not contain real surveillance or patient data.

library(shiny)
library(ggplot2)

# ------------------------------------------------------------
# 1. Import and validate synthetic surveillance data
# ------------------------------------------------------------

# Shiny runs the application with its application folder as the
# working directory. Keep a copy of the CSV in shiny/data/.
data_path <- file.path(
  "data", "epidemiology_relative_weeks_synthetic.csv"
)

if (!file.exists(data_path)) {
  stop(
    "Synthetic dataset not found: ", data_path,
    ". Copy the CSV from outputs/tables/ to shiny/data/."
  )
}

surveillance <- read.csv(data_path, stringsAsFactors = FALSE)

required_columns <- c(
  "date", "period", "relative_week", "rms_brut", "rms_estim",
  "dengue_cas_bio", "pasaj_deng", "hospi_deng"
)

missing_columns <- setdiff(required_columns, names(surveillance))
if (length(missing_columns) > 0) {
  stop("Required columns missing: ", paste(missing_columns, collapse = ", "))
}

if (nrow(surveillance) == 0) stop("The surveillance dataset is empty.")

surveillance$date <- as.Date(surveillance$date, format = "%Y-%m-%d")
surveillance$relative_week <- suppressWarnings(
  as.numeric(surveillance$relative_week)
)

count_columns <- c(
  "rms_brut", "rms_estim", "dengue_cas_bio",
  "pasaj_deng", "hospi_deng"
)

if (!all(vapply(surveillance[count_columns], is.numeric, logical(1)))) {
  stop("All surveillance indicators must have numeric values.")
}

count_matrix <- as.matrix(surveillance[count_columns])
expected_weeks <- c(P1 = 47L, P2 = 47L, P3 = 31L)
period_codes <- sub("^(P[123]).*", "\\1", surveillance$period)
observed_weeks <- table(factor(period_codes, levels = names(expected_weeks)))

quality_checks <- data.frame(
  Check = c(
    "Required columns", "Missing values in required fields", "Valid dates",
    "Valid relative weeks", "Non-negative counts", "Whole-number counts",
    "Unique period/week combinations", "Expected P1/P2/P3 coverage"
  ),
  Finding = c(
    paste(length(required_columns), "required columns present"),
    paste(sum(is.na(surveillance[required_columns])), "missing cells"),
    paste(sum(is.na(surveillance$date)), "invalid dates"),
    paste(sum(!is.finite(surveillance$relative_week) |
                surveillance$relative_week < 1 |
                surveillance$relative_week %% 1 != 0, na.rm = TRUE),
          "invalid week values"),
    paste(sum(count_matrix < 0, na.rm = TRUE), "negative cells"),
    paste(sum(count_matrix %% 1 != 0, na.rm = TRUE), "non-integer cells"),
    paste(sum(duplicated(surveillance[c("period", "relative_week")])),
          "duplicate rows"),
    paste(paste(names(expected_weeks), as.integer(observed_weeks), sep = "="),
          collapse = "; ")
  ),
  Passed = c(
    TRUE,
    !anyNA(surveillance[required_columns]) &&
      all(nzchar(trimws(surveillance$period))),
    !anyNA(surveillance$date),
    all(is.finite(surveillance$relative_week) &
          surveillance$relative_week >= 1 &
          surveillance$relative_week %% 1 == 0),
    all(count_matrix >= 0, na.rm = TRUE),
    all(count_matrix %% 1 == 0, na.rm = TRUE),
    !anyDuplicated(surveillance[c("period", "relative_week")]),
    identical(as.integer(observed_weeks), as.integer(expected_weeks)) &&
      all(period_codes %in% names(expected_weeks))
  ),
  stringsAsFactors = FALSE
)

quality_checks$Status <- ifelse(quality_checks$Passed, "PASS", "FAIL")

if (!all(quality_checks$Passed)) {
  failed <- paste(quality_checks$Check[!quality_checks$Passed],
                  collapse = "; ")
  stop("Data quality validation failed: ", failed)
}

message("Data quality checks passed (", nrow(surveillance), " rows).")

periods <- unique(surveillance$period)
surveillance$period <- factor(surveillance$period, levels = periods)
surveillance <- surveillance[order(surveillance$period,
                                   surveillance$relative_week), ]

# Stable indicator codes; labels change with the selected language.
indicators <- c(
  "Estimated dengue cases (CCE)" = "rms_estim",
  "Sentinel consultations" = "rms_brut",
  "Biological dengue cases" = "dengue_cas_bio",
  "Emergency department visits" = "pasaj_deng",
  "Hospital admissions" = "hospi_deng"
)

indicator_labels_fr <- c(
  "Cas de dengue estimés (CCE)" = "rms_estim",
  "Consultations sentinelles" = "rms_brut",
  "Cas de dengue biologiquement confirmés" = "dengue_cas_bio",
  "Passages aux urgences" = "pasaj_deng",
  "Hospitalisations" = "hospi_deng"
)

indicator_choices <- function(lang = "en") {
  if (identical(lang, "fr")) indicator_labels_fr else indicators
}

indicator_label <- function(indicator, lang = "en") {
  labels <- indicator_choices(lang)
  idx <- match(indicator, unname(labels))
  if (is.na(idx)) return(indicator)
  names(labels)[idx]
}

# Labels are separated from data and analytical calculations.
translations <- list(
  en = c(
    app_title = "Dengue Epidemiological Surveillance Dashboard",
    app_subtitle = "Interactive surveillance analysis in R Shiny | Synthetic data only",
    indicator = "Epidemiological indicator",
    periods = "Study periods",
    week_range = "Relative epidemiological week range",
    overview = "Overview",
    comparisons = "Comparisons",
    data_quality = "Data Quality",
    note_counts = "Counts represent simulated observations or healthcare encounters, not necessarily distinct patients.",
    period_comparison = "Period comparisons",
    unequal_periods = "Study periods have different lengths. Weekly averages should be considered alongside cumulative counts.",
    descriptive_stats = "Descriptive statistics for the selected indicator",
    download_summary = "Download summary CSV",
    download_data = "Download filtered CSV",
    download_plot = "Download curve PNG",
    validation_title = "Automated data validation",
    validation_note = "These checks are performed on the complete imported dataset before the interactive filters are applied.",
    period_coverage = "Period coverage",
    disclaimer_label = "Methodological disclaimer. ",
    disclaimer_text = "All records are synthetic. P1 and P2 cover 47 weeks each; P3 covers 31 weeks. Descriptive differences are not causal estimates. Sentinel consultations, estimated CCE, biological cases, emergency visits, and hospital admissions are distinct indicators and should not be interpreted as counts of unique individuals.",
    source = "Source: epidemiology_relative_weeks_synthetic.csv, generated by the repository's R workflows.",
    footer = "Independent methodological portfolio demonstration — not an official Santé publique France publication or a dataset of actual dengue cases.",
    select_period = "Select at least one study period.",
    no_observations = "No observations match these filters.",
    estimated_cce = "Estimated CCE",
    emergencies = "Emergency visits",
    admissions = "Hospital admissions",
    peak_cce = "Peak weekly CCE",
    records = "weekly records selected across",
    study_periods = "study period(s).",
    relative_title = "Epidemiological curves by relative week",
    relative_subtitle = "Synthetic surveillance observations; aligned study periods",
    relative_axis = "Relative epidemiological week",
    study_period = "Study period",
    calendar_title = "Calendar-time surveillance curves",
    calendar_subtitle = "Each study period is shown on its actual dates",
    observation_date = "Observation date",
    comparison_title = "Average weekly activity by period",
    comparison_subtitle = "Weekly averages allow comparison of unequal period lengths",
    per_week = "per week"
  ),
  fr = c(
    app_title = "Tableau de bord de surveillance épidémiologique de la dengue",
    app_subtitle = "Analyse interactive avec R Shiny | Données exclusivement synthétiques",
    indicator = "Indicateur épidémiologique",
    periods = "Périodes d'étude",
    week_range = "Plage des semaines épidémiologiques relatives",
    overview = "Vue d'ensemble",
    comparisons = "Comparaisons",
    data_quality = "Qualité des données",
    note_counts = "Les effectifs correspondent à des observations simulées ou à des recours aux soins, et pas nécessairement à des patients distincts.",
    period_comparison = "Comparaison des périodes",
    unequal_periods = "Les périodes d'étude n'ont pas la même durée. Les moyennes hebdomadaires doivent être examinées en complément des effectifs cumulés.",
    descriptive_stats = "Statistiques descriptives pour l'indicateur sélectionné",
    download_summary = "Télécharger le résumé CSV",
    download_data = "Télécharger les données filtrées CSV",
    download_plot = "Télécharger la courbe PNG",
    validation_title = "Validation automatisée des données",
    validation_note = "Ces contrôles portent sur l'ensemble des données importées, avant application des filtres interactifs.",
    period_coverage = "Couverture des périodes",
    disclaimer_label = "Avertissement méthodologique. ",
    disclaimer_text = "Toutes les observations sont synthétiques. P1 et P2 couvrent chacune 47 semaines ; P3 couvre 31 semaines. Les différences descriptives ne constituent pas des estimations causales. Les consultations sentinelles, les cas estimés (CCE), les cas biologiques, les passages aux urgences et les hospitalisations sont des indicateurs distincts, et non des nombres de personnes uniques.",
    source = "Source : epidemiology_relative_weeks_synthetic.csv, généré par les scripts R du dépôt.",
    footer = "Démonstration méthodologique indépendante — ni publication officielle de Santé publique France ni données réelles de cas de dengue.",
    select_period = "Sélectionnez au moins une période d'étude.",
    no_observations = "Aucune observation ne correspond à ces filtres.",
    estimated_cce = "Cas estimés (CCE)",
    emergencies = "Passages aux urgences",
    admissions = "Hospitalisations",
    peak_cce = "Maximum hebdomadaire (CCE)",
    records = "observations hebdomadaires sélectionnées sur",
    study_periods = "période(s) d'étude.",
    relative_title = "Courbes épidémiologiques par semaine relative",
    relative_subtitle = "Observations de surveillance synthétiques ; périodes alignées",
    relative_axis = "Semaine épidémiologique relative",
    study_period = "Période d'étude",
    calendar_title = "Courbes de surveillance en temps calendaire",
    calendar_subtitle = "Chaque période est représentée selon ses dates réelles",
    observation_date = "Date d'observation",
    comparison_title = "Activité hebdomadaire moyenne par période",
    comparison_subtitle = "Les moyennes hebdomadaires permettent de comparer des périodes de durées différentes",
    per_week = "par semaine"
  )
)

tr <- function(key, lang = "en") {
  if (!identical(lang, "fr")) lang <- "en"
  value <- translations[[lang]][[key]]
  if (is.null(value)) stop("Missing translation: ", lang, "/", key)
  unname(value)
}

period_coverage <- do.call(rbind, lapply(periods, function(p) {
  d <- surveillance[surveillance$period == p, ]
  code <- sub("^(P[123]).*", "\\1", p)
  data.frame(
    Period = p,
    First_Date = format(min(d$date), "%Y-%m-%d"),
    Last_Date = format(max(d$date), "%Y-%m-%d"),
    Observed_Weeks = nrow(d),
    Expected_Weeks = as.integer(expected_weeks[code]),
    stringsAsFactors = FALSE
  )
}))

# ------------------------------------------------------------
# 2. Reusable summary and plot functions (calculations unchanged)
# ------------------------------------------------------------

summarize_periods <- function(df, indicator) {
  groups <- split(df, droplevels(df$period))
  do.call(rbind, lapply(groups, function(d) {
    values <- d[[indicator]]
    data.frame(
      Period = as.character(d$period[1]),
      Weeks = nrow(d),
      Total = sum(values),
      Weekly_Mean = round(mean(values), 1),
      Weekly_Peak = max(values),
      Peak_Relative_Week = d$relative_week[which.max(values)],
      stringsAsFactors = FALSE
    )
  }))
}

relative_week_plot <- function(df, indicator, lang = "en") {
  ggplot(df, aes(
    x = relative_week, y = .data[[indicator]],
    colour = period, group = period
  )) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 1, alpha = 0.7) +
    labs(
      title = tr("relative_title", lang),
      subtitle = tr("relative_subtitle", lang),
      x = tr("relative_axis", lang),
      y = indicator_label(indicator, lang),
      colour = tr("study_period", lang)
    ) +
    theme_minimal(base_size = 13) +
    theme(legend.position = "bottom", plot.title = element_text(face = "bold"))
}

calendar_plot <- function(df, indicator, lang = "en") {
  french_months <- c("janv.", "févr.", "mars", "avr.", "mai", "juin",
                     "juil.", "août", "sept.", "oct.", "nov.", "déc.")
  date_labels <- function(dates) {
    if (identical(lang, "fr")) {
      month_num <- as.integer(format(dates, "%m"))
      paste(french_months[month_num], format(dates, "%Y"))
    } else {
      format(dates, "%b %Y")
    }
  }
  ggplot(df, aes(x = date, y = .data[[indicator]], colour = period)) +
    geom_line(linewidth = 0.9) +
    facet_wrap(~ period, ncol = 1, scales = "free_x") +
    scale_x_date(labels = date_labels) +
    labs(
      title = tr("calendar_title", lang),
      subtitle = tr("calendar_subtitle", lang),
      x = tr("observation_date", lang),
      y = indicator_label(indicator, lang)
    ) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "none", plot.title = element_text(face = "bold"))
}

comparison_plot <- function(summary_df, indicator, lang = "en") {
  ggplot(summary_df,
         aes(x = Period, y = Weekly_Mean, fill = Period)) +
    geom_col(width = 0.65) +
    geom_text(aes(label = Weekly_Mean), vjust = -0.4, size = 4) +
    labs(
      title = tr("comparison_title", lang),
      subtitle = tr("comparison_subtitle", lang),
      x = tr("study_period", lang),
      y = paste(indicator_label(indicator, lang), tr("per_week", lang))
    ) +
    expand_limits(y = max(summary_df$Weekly_Mean) * 1.15 + 0.1) +
    theme_minimal(base_size = 13) +
    theme(legend.position = "none", plot.title = element_text(face = "bold"))
}

kpi_card <- function(title, value) {
  div(class = "kpi-card", div(class = "kpi-number", value),
      div(class = "kpi-label", title))
}

format_count <- function(x, lang = "en") {
  format(round(x), big.mark = if (identical(lang, "fr")) " " else ",",
         trim = TRUE, scientific = FALSE)
}

quality_checks_fr <- c(
  "Colonnes obligatoires",
  "Valeurs manquantes dans les champs obligatoires",
  "Validité des dates",
  "Validité des semaines relatives",
  "Effectifs non négatifs",
  "Effectifs entiers",
  "Unicité des combinaisons période/semaine",
  "Couverture attendue P1/P2/P3"
)

quality_findings_fr <- c(
  paste(length(required_columns), "colonnes obligatoires présentes"),
  paste(sum(is.na(surveillance[required_columns])), "cellules manquantes"),
  paste(sum(is.na(surveillance$date)), "dates invalides"),
  paste(sum(!is.finite(surveillance$relative_week) |
              surveillance$relative_week < 1 |
              surveillance$relative_week %% 1 != 0, na.rm = TRUE),
        "semaines invalides"),
  paste(sum(count_matrix < 0, na.rm = TRUE), "cellules négatives"),
  paste(sum(count_matrix %% 1 != 0, na.rm = TRUE), "cellules non entières"),
  paste(sum(duplicated(surveillance[c("period", "relative_week")])),
        "lignes en double"),
  paste(paste(names(expected_weeks), as.integer(observed_weeks), sep = "="),
        collapse = "; ")
)

# ------------------------------------------------------------
# 3. Shiny interface: bilingual labels and original shared filters
# ------------------------------------------------------------

ui <- fluidPage(
  tags$head(tags$style(HTML("\n    body { background: #f7f9fc; }\n    .app-subtitle { color: #526173; margin-bottom: 16px; }\n    .kpi-card { background: white; border: 1px solid #e3e9f0;\n                border-radius: 12px; padding: 18px; margin-bottom: 12px; }\n    .kpi-number { font-size: 27px; font-weight: 700; color: #1c3d60; }\n    .kpi-label { color: #526173; font-size: 13px; }\n    .info-note { background: #fff; border-left: 3px solid #4378a7;\n                 padding: 12px; margin: 16px 0; }\n    .tab-content { padding-top: 18px; }\n  "))),
  fluidRow(
    column(9, titlePanel(textOutput("app_title", inline = TRUE))),
    column(3, selectInput(
      "language", "Langue / Language",
      choices = c("Français" = "fr", "English" = "en"),
      selected = "en", width = "100%"
    ))
  ),
  p(class = "app-subtitle", textOutput("app_subtitle", inline = TRUE)),
  wellPanel(
    fluidRow(
      column(5, selectInput(
        "indicator", "Epidemiological indicator",
        choices = indicators, selected = "rms_estim"
      )),
      column(7, checkboxGroupInput(
        "periods", "Study periods",
        choices = periods, selected = periods, inline = TRUE
      ))
    ),
    sliderInput(
      "week_range", "Relative epidemiological week range",
      min = 1, max = max(surveillance$relative_week),
      value = c(1, max(surveillance$relative_week)), step = 1
    )
  ),
  uiOutput("translated_tabs"),
  hr(),
  p(style = "color:#68788a;font-size:12px;",
    textOutput("footer_note", inline = TRUE))
)

# ------------------------------------------------------------
# 4. Reactive analysis and translated presentation
# ------------------------------------------------------------

server <- function(input, output, session) {
  language <- reactive({
    if (identical(input$language, "fr")) "fr" else "en"
  })

  output$app_title <- renderText(tr("app_title", language()))
  output$app_subtitle <- renderText(tr("app_subtitle", language()))
  output$footer_note <- renderText(tr("footer", language()))

  # Updating labels never replaces filters or resets user-selected periods/weeks.
  observeEvent(input$language, {
    lang <- language()
    selected_indicator <- isolate(input$indicator)
    if (is.null(selected_indicator)) selected_indicator <- "rms_estim"
    updateSelectInput(
      session, "indicator", label = tr("indicator", lang),
      choices = indicator_choices(lang), selected = selected_indicator
    )
    updateCheckboxGroupInput(session, "periods", label = tr("periods", lang))
    updateSliderInput(session, "week_range", label = tr("week_range", lang))
  })

  output$translated_tabs <- renderUI({
    lang <- language()
    current_tab <- isolate(input$active_tab)
    if (is.null(current_tab) || !current_tab %in%
        c("overview", "comparisons", "data_quality")) {
      current_tab <- "overview"
    }
    tabsetPanel(
      id = "active_tab", selected = current_tab,
      tabPanel(tr("overview", lang), value = "overview",
        uiOutput("kpis"),
        p(textOutput("filter_description")),
        plotOutput("relative_curve", height = "410px"),
        hr(),
        plotOutput("calendar_curve", height = "610px"),
        div(class = "info-note", tr("note_counts", lang))
      ),
      tabPanel(tr("comparisons", lang), value = "comparisons",
        h3(tr("period_comparison", lang)),
        p(tr("unequal_periods", lang)),
        plotOutput("weekly_bar", height = "370px"),
        h4(tr("descriptive_stats", lang)),
        tableOutput("summary_table"),
        fluidRow(
          column(4, downloadButton("download_summary", tr("download_summary", lang))),
          column(4, downloadButton("download_data", tr("download_data", lang))),
          column(4, downloadButton("download_plot", tr("download_plot", lang)))
        )
      ),
      tabPanel(tr("data_quality", lang), value = "data_quality",
        h3(tr("validation_title", lang)),
        p(tr("validation_note", lang)),
        tableOutput("quality_table"),
        h4(tr("period_coverage", lang)),
        tableOutput("coverage_table"),
        div(class = "info-note",
            strong(tr("disclaimer_label", lang)),
            tr("disclaimer_text", lang)),
        p(tr("source", lang))
      )
    )
  })

  filtered_data <- reactive({
    validate(need(length(input$periods) > 0,
                  tr("select_period", language())))
    req(input$week_range)
    d <- surveillance[
      surveillance$period %in% input$periods &
        surveillance$relative_week >= input$week_range[1] &
        surveillance$relative_week <= input$week_range[2],
    ]
    validate(need(nrow(d) > 0, tr("no_observations", language())))
    droplevels(d)
  })

  period_summary <- reactive({
    summarize_periods(filtered_data(), input$indicator)
  })

  output$kpis <- renderUI({
    d <- filtered_data()
    lang <- language()
    fluidRow(
      column(3, kpi_card(tr("estimated_cce", lang), format_count(sum(d$rms_estim), lang))),
      column(3, kpi_card(tr("emergencies", lang), format_count(sum(d$pasaj_deng), lang))),
      column(3, kpi_card(tr("admissions", lang), format_count(sum(d$hospi_deng), lang))),
      column(3, kpi_card(tr("peak_cce", lang), format_count(max(d$rms_estim), lang)))
    )
  })

  output$filter_description <- renderText({
    d <- filtered_data()
    paste(nrow(d), tr("records", language()),
          length(unique(d$period)), tr("study_periods", language()))
  })

  output$relative_curve <- renderPlot({
    relative_week_plot(filtered_data(), input$indicator, language())
  })

  output$calendar_curve <- renderPlot({
    calendar_plot(filtered_data(), input$indicator, language())
  })

  output$weekly_bar <- renderPlot({
    comparison_plot(period_summary(), input$indicator, language())
  })

  output$summary_table <- renderTable({
    res <- period_summary()
    if (identical(language(), "fr")) {
      names(res) <- c("Période", "Semaines", "Total", "Moyenne hebdomadaire",
                      "Pic hebdomadaire", "Semaine relative du pic")
    }
    res
  }, rownames = FALSE, striped = TRUE)

  output$quality_table <- renderTable({
    res <- quality_checks[c("Check", "Finding", "Status")]
    if (identical(language(), "fr")) {
      res$Check <- quality_checks_fr
      res$Finding <- quality_findings_fr
      res$Status <- ifelse(quality_checks$Passed, "VALIDÉ", "ÉCHEC")
      names(res) <- c("Contrôle", "Résultat", "Statut")
    }
    res
  }, rownames = FALSE, striped = TRUE)

  output$coverage_table <- renderTable({
    res <- period_coverage
    if (identical(language(), "fr")) {
      names(res) <- c("Période", "Première date", "Dernière date",
                      "Semaines observées", "Semaines attendues")
    }
    res
  }, rownames = FALSE, striped = TRUE)

  # Machine-readable CSV column names and download filenames stay stable.
  output$download_summary <- downloadHandler(
    filename = function() paste0("dengue_summary_", Sys.Date(), ".csv"),
    content = function(file) write.csv(period_summary(), file, row.names = FALSE)
  )

  output$download_data <- downloadHandler(
    filename = function() paste0("dengue_filtered_", Sys.Date(), ".csv"),
    content = function(file) write.csv(filtered_data(), file, row.names = FALSE)
  )

  output$download_plot <- downloadHandler(
    filename = function() paste0("dengue_epidemic_curve_", Sys.Date(), ".png"),
    content = function(file) {
      ggsave(
        filename = file,
        plot = relative_week_plot(filtered_data(), input$indicator, language()),
        device = "png", width = 11, height = 6, units = "in", dpi = 300,
        bg = "white"
      )
    }
  )
}

shinyApp(ui = ui, server = server)
