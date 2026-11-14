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

indicators <- c(
  "Estimated dengue cases (CCE)" = "rms_estim",
  "Sentinel consultations" = "rms_brut",
  "Biological dengue cases" = "dengue_cas_bio",
  "Emergency department visits" = "pasaj_deng",
  "Hospital admissions" = "hospi_deng"
)

indicator_label <- function(indicator) {
  names(indicators)[match(indicator, unname(indicators))]
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
# 2. Reusable summary and plot functions
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

relative_week_plot <- function(df, indicator) {
  ggplot(df, aes(
    x = relative_week, y = .data[[indicator]],
    colour = period, group = period
  )) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 1, alpha = 0.7) +
    labs(
      title = "Epidemiological curves by relative week",
      subtitle = "Synthetic surveillance observations; aligned study periods",
      x = "Relative epidemiological week",
      y = indicator_label(indicator), colour = "Study period"
    ) +
    theme_minimal(base_size = 13) +
    theme(legend.position = "bottom", plot.title = element_text(face = "bold"))
}

calendar_plot <- function(df, indicator) {
  ggplot(df, aes(x = date, y = .data[[indicator]], colour = period)) +
    geom_line(linewidth = 0.9) +
    facet_wrap(~ period, ncol = 1, scales = "free_x") +
    scale_x_date(date_labels = "%b %Y") +
    labs(
      title = "Calendar-time surveillance curves",
      subtitle = "Each study period is shown on its actual dates",
      x = "Observation date", y = indicator_label(indicator)
    ) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "none", plot.title = element_text(face = "bold"))
}

comparison_plot <- function(summary_df, indicator) {
  ggplot(summary_df,
         aes(x = Period, y = Weekly_Mean, fill = Period)) +
    geom_col(width = 0.65) +
    geom_text(aes(label = Weekly_Mean), vjust = -0.4, size = 4) +
    labs(
      title = "Average weekly activity by period",
      subtitle = "Weekly averages allow comparison of unequal period lengths",
      x = "Study period", y = paste(indicator_label(indicator), "per week")
    ) +
    expand_limits(y = max(summary_df$Weekly_Mean) * 1.15 + 0.1) +
    theme_minimal(base_size = 13) +
    theme(legend.position = "none", plot.title = element_text(face = "bold"))
}

kpi_card <- function(title, value) {
  div(class = "kpi-card", div(class = "kpi-number", value),
      div(class = "kpi-label", title))
}

format_count <- function(x) {
  format(round(x), big.mark = ",", trim = TRUE, scientific = FALSE)
}

# ------------------------------------------------------------
# 3. Shiny interface: three tabs and shared filters
# ------------------------------------------------------------

ui <- fluidPage(
  tags$head(tags$style(HTML("\n    body { background: #f7f9fc; }\n    .app-subtitle { color: #526173; margin-bottom: 16px; }\n    .kpi-card { background: white; border: 1px solid #e3e9f0;\n                border-radius: 12px; padding: 18px; margin-bottom: 12px; }\n    .kpi-number { font-size: 27px; font-weight: 700; color: #1c3d60; }\n    .kpi-label { color: #526173; font-size: 13px; }\n    .info-note { background: #fff; border-left: 3px solid #4378a7;\n                 padding: 12px; margin: 16px 0; }\n    .tab-content { padding-top: 18px; }\n  "))),
  titlePanel("Dengue Epidemiological Surveillance Dashboard"),
  p(class = "app-subtitle",
    "Interactive surveillance analysis in R Shiny | Synthetic data only"),
  
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
  
  tabsetPanel(
    id = "active_tab",
    
    tabPanel("Overview",
             uiOutput("kpis"),
             p(textOutput("filter_description")),
             plotOutput("relative_curve", height = "410px"),
             hr(),
             plotOutput("calendar_curve", height = "610px"),
             div(class = "info-note",
                 "Counts represent simulated observations or healthcare encounters,",
                 "not necessarily distinct patients.")
    ),
    
    tabPanel("Comparisons",
             h3("Period comparisons"),
             p("Study periods have different lengths. Weekly averages should be",
               "considered alongside cumulative counts."),
             plotOutput("weekly_bar", height = "370px"),
             h4("Descriptive statistics for the selected indicator"),
             tableOutput("summary_table"),
             fluidRow(
               column(4, downloadButton("download_summary", "Download summary CSV")),
               column(4, downloadButton("download_data", "Download filtered CSV")),
               column(4, downloadButton("download_plot", "Download curve PNG"))
             )
    ),
    
    tabPanel("Data Quality",
             h3("Automated data validation"),
             p("These checks are performed on the complete imported dataset",
               "before the interactive filters are applied."),
             tableOutput("quality_table"),
             h4("Period coverage"),
             tableOutput("coverage_table"),
             div(class = "info-note",
                 strong("Methodological disclaimer. "),
                 "All records are synthetic. P1 and P2 cover 47 weeks each;",
                 "P3 covers 31 weeks. Descriptive differences are not",
                 "causal estimates. Sentinel consultations, estimated CCE,",
                 "biological cases, emergency visits, and hospital admissions",
                 "are distinct indicators and should not be interpreted",
                 "as counts of unique individuals."),
             p("Source: epidemiology_relative_weeks_synthetic.csv,",
               "generated by the repository's R workflows.")
    )
  ),
  
  hr(),
  p(style = "color:#68788a;font-size:12px;",
    "Independent methodological portfolio demonstration — not an official",
    "Santé publique France publication or a dataset of actual dengue cases.")
)

# ------------------------------------------------------------
# 4. Reactive analysis and outputs
# ------------------------------------------------------------

server <- function(input, output, session) {
  
  filtered_data <- reactive({
    validate(need(length(input$periods) > 0,
                  "Select at least one study period."))
    req(input$week_range)
    d <- surveillance[
      surveillance$period %in% input$periods &
        surveillance$relative_week >= input$week_range[1] &
        surveillance$relative_week <= input$week_range[2],
    ]
    validate(need(nrow(d) > 0, "No observations match these filters."))
    droplevels(d)
  })
  
  period_summary <- reactive({
    summarize_periods(filtered_data(), input$indicator)
  })
  
  output$kpis <- renderUI({
    d <- filtered_data()
    fluidRow(
      column(3, kpi_card("Estimated CCE", format_count(sum(d$rms_estim)))),
      column(3, kpi_card("Emergency visits", format_count(sum(d$pasaj_deng)))),
      column(3, kpi_card("Hospital admissions", format_count(sum(d$hospi_deng)))),
      column(3, kpi_card("Peak weekly CCE", format_count(max(d$rms_estim))))
    )
  })
  
  output$filter_description <- renderText({
    d <- filtered_data()
    paste(nrow(d), "weekly records selected across",
          length(unique(d$period)), "study period(s).")
  })
  
  output$relative_curve <- renderPlot({
    relative_week_plot(filtered_data(), input$indicator)
  })
  
  output$calendar_curve <- renderPlot({
    calendar_plot(filtered_data(), input$indicator)
  })
  
  output$weekly_bar <- renderPlot({
    comparison_plot(period_summary(), input$indicator)
  })
  
  output$summary_table <- renderTable({
    period_summary()
  }, rownames = FALSE, striped = TRUE)
  
  output$quality_table <- renderTable({
    quality_checks[c("Check", "Finding", "Status")]
  }, rownames = FALSE, striped = TRUE)
  
  output$coverage_table <- renderTable({
    period_coverage
  }, rownames = FALSE, striped = TRUE)
  
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
        plot = relative_week_plot(filtered_data(), input$indicator),
        device = "png", width = 11, height = 6, units = "in", dpi = 300,
        bg = "white"
      )
    }
  )
}

shinyApp(ui = ui, server = server)
