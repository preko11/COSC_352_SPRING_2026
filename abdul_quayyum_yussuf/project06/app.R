#!/usr/bin/env Rscript

# app.R - Baltimore City Police Department Homicide Analysis Dashboard
# Part 2: Interactive Shiny Dashboard

# Load required libraries
library(shiny)
library(shinydashboard)
library(plotly)
library(leaflet)
library(DT)
library(dplyr)
library(tidyr)
library(ggplot2)
library(lubridate)
library(httr)
library(rvest)
library(tidygeocoder)
library(stringr)

# Data loading and processing function
load_homicide_data <- function() {
  cache_file <- "homicide_data_cache.csv"

  if (file.exists(cache_file)) {
    cat("Loading cached data...\n")
    data <- read.csv(cache_file, stringsAsFactors = FALSE)
    data$Date <- as.Date(data$Date)
    data$AgeNum <- as.numeric(data$AgeNum)
    return(data)
  }

  # Scrape data if no cache
  cat("Scraping data from chamspage...\n")

  urls <- list(
    "2025" = "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html",
    "2026" = "https://chamspage.blogspot.com/2026/01/2026-baltimore-city-homicide-list.html"
  )

  extract_homicide_data <- function(url) {
    page <- read_html(url)
    tbl <- html_node(page, "#homicidelist")
    raw <- html_table(tbl, fill = TRUE)

    if (nrow(raw) == 0) return(NULL)

    colnames(raw) <- as.character(raw[1, ])
    data <- raw[-1, ]
    data <- data %>% select(1:9)
    colnames(data) <- c(
      "No", "Date", "Name", "Age", "Address", "Notes",
      "NoCriminalHistory", "Camera", "CaseClosed"
    )
    data <- data %>% filter(str_trim(Date) != "" & !is.na(Date))
    data$Date <- mdy(data$Date)  # Assuming MM/DD/YYYY format
    data
  }

  all_data <- NULL
  for (year in names(urls)) {
    data <- extract_homicide_data(urls[[year]])
    if (!is.null(data)) {
      data$Year <- as.numeric(year)
      all_data <- bind_rows(all_data, data)
    }
  }

  if (is.null(all_data) || nrow(all_data) == 0) {
    stop("No homicide data found")
  }

  # Clean age
  all_data <- all_data %>% mutate(AgeNum = as.numeric(str_extract(Age, "\\d+")))

  # Extract method from Notes (simple keyword search)
  all_data <- all_data %>% mutate(
    Method = case_when(
      str_detect(tolower(Notes), "shoot|gun|firearm") ~ "Shooting",
      str_detect(tolower(Notes), "stab|knife") ~ "Stabbing",
      str_detect(tolower(Notes), "beat|blunt") ~ "Beating",
      TRUE ~ "Other"
    )
  )

  # Extract district from Address (simple parsing, assuming format like "123 Main St, Baltimore, MD")
  all_data <- all_data %>% mutate(
    District = str_extract(Address, "(?<=, )[^,]+(?=, MD)") %>% str_trim()
  )
  all_data$District[is.na(all_data$District)] <- "Unknown"

  # Geocode addresses for map (using tidygeocoder)
  cat("Geocoding addresses...\n")
  geocoded <- all_data %>%
    mutate(full_address = paste(Address, "Baltimore, MD", sep = ", ")) %>%
    geocode(address = full_address, method = 'osm')

  all_data <- bind_cols(all_data, select(geocoded, lat, long))

  # Cache the data
  write.csv(all_data, cache_file, row.names = FALSE)

  all_data
}

# Load data at app startup
homicide_data <- load_homicide_data()

# UI
ui <- dashboardPage(
  dashboardHeader(title = "Baltimore Homicide Dashboard"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview", tabName = "overview", icon = icon("dashboard")),
      menuItem("Trends", tabName = "trends", icon = icon("line-chart")),
      menuItem("Demographics", tabName = "demographics", icon = icon("users")),
      menuItem("Map", tabName = "map", icon = icon("map")),
      menuItem("Data Table", tabName = "table", icon = icon("table"))
    ),
    # Filters
    selectInput("year_range", "Year Range:",
                choices = sort(unique(homicide_data$Year)),
                selected = sort(unique(homicide_data$Year)),
                multiple = TRUE),
    sliderInput("age_range", "Victim Age Range:",
                min = min(homicide_data$AgeNum, na.rm = TRUE),
                max = max(homicide_data$AgeNum, na.rm = TRUE),
                value = c(min(homicide_data$AgeNum, na.rm = TRUE), max(homicide_data$AgeNum, na.rm = TRUE))),
    selectInput("method", "Homicide Method:",
                choices = unique(homicide_data$Method),
                selected = unique(homicide_data$Method),
                multiple = TRUE),
    selectInput("status", "Case Status:",
                choices = unique(homicide_data$CaseClosed),
                selected = unique(homicide_data$CaseClosed),
                multiple = TRUE),
    selectInput("district", "District:",
                choices = unique(homicide_data$District),
                selected = unique(homicide_data$District),
                multiple = TRUE)
  ),
  dashboardBody(
    tabItems(
      tabItem(tabName = "overview",
              fluidRow(
                valueBoxOutput("total_homicides"),
                valueBoxOutput("clearance_rate"),
                valueBoxOutput("avg_age"),
                valueBoxOutput("common_method")
              ),
              fluidRow(
                box(title = "Summary Statistics", width = 12,
                    textOutput("summary_text"))
              )
      ),
      tabItem(tabName = "trends",
              fluidRow(
                box(title = "Homicides Over Time", width = 12,
                    plotlyOutput("time_trend"))
              )
      ),
      tabItem(tabName = "demographics",
              fluidRow(
                box(title = "Homicides by Method", width = 6,
                    plotlyOutput("method_bar")),
                box(title = "Homicides by District", width = 6,
                    plotlyOutput("district_bar"))
              )
      ),
      tabItem(tabName = "map",
              fluidRow(
                box(title = "Incident Map", width = 12,
                    leafletOutput("incident_map"))
              )
      ),
      tabItem(tabName = "table",
              fluidRow(
                box(title = "Filtered Data", width = 12,
                    DTOutput("data_table"))
              )
      )
    )
  )
)

# Server
server <- function(input, output, session) {

  # Reactive filtered data
  filtered_data <- reactive({
    data <- homicide_data
    data <- data %>% filter(Year %in% input$year_range)
    data <- data %>% filter(AgeNum >= input$age_range[1] & AgeNum <= input$age_range[2])
    data <- data %>% filter(Method %in% input$method)
    data <- data %>% filter(CaseClosed %in% input$status)
    data <- data %>% filter(District %in% input$district)
    data
  })

  # Value boxes
  output$total_homicides <- renderValueBox({
    valueBox(
      nrow(filtered_data()),
      "Total Homicides",
      icon = icon("skull-crossbones"),
      color = "red"
    )
  })

  output$clearance_rate <- renderValueBox({
    cleared <- sum(filtered_data()$CaseClosed == "Yes", na.rm = TRUE)
    total <- nrow(filtered_data())
    rate <- if(total > 0) round((cleared / total) * 100, 1) else 0
    valueBox(
      paste0(rate, "%"),
      "Clearance Rate",
      icon = icon("check-circle"),
      color = "green"
    )
  })

  output$avg_age <- renderValueBox({
    avg <- round(mean(filtered_data()$AgeNum, na.rm = TRUE), 1)
    valueBox(
      avg,
      "Average Victim Age",
      icon = icon("user"),
      color = "blue"
    )
  })

  output$common_method <- renderValueBox({
    method <- filtered_data() %>%
      count(Method) %>%
      arrange(desc(n)) %>%
      slice(1) %>%
      pull(Method)
    valueBox(
      method,
      "Most Common Method",
      icon = icon("gun"),
      color = "orange"
    )
  })

  # Summary text
  output$summary_text <- renderText({
    data <- filtered_data()
    if(nrow(data) == 0) {
      "No data matches the current filters."
    } else {
      cctv_pct <- round(mean(data$Camera == "Yes", na.rm = TRUE) * 100, 1)
      paste(
        "Total homicides in filtered period:", nrow(data), "\n",
        "Case clearance rate:", round((sum(data$CaseClosed == "Yes", na.rm = TRUE) / nrow(data)) * 100, 1), "%\n",
        "Average victim age:", round(mean(data$AgeNum, na.rm = TRUE), 1), "\n",
        "Most common method:", (data %>% count(Method) %>% arrange(desc(n)) %>% slice(1) %>% pull(Method)), "\n",
        "Percentage near CCTV:", cctv_pct, "%"
      )
    }
  })

  # Time trend plot
  output$time_trend <- renderPlotly({
    data <- filtered_data()
    if(nrow(data) == 0) {
      plotly_empty() %>% layout(title = "No data to display")
    } else {
      monthly_counts <- data %>%
        mutate(Month = floor_date(Date, "month")) %>%
        count(Month)
      plot_ly(monthly_counts, x = ~Month, y = ~n, type = 'scatter', mode = 'lines+markers') %>%
        layout(title = "Homicides Over Time", xaxis = list(title = "Month"), yaxis = list(title = "Count"))
    }
  })

  # Method bar chart
  output$method_bar <- renderPlotly({
    data <- filtered_data()
    if(nrow(data) == 0) {
      plotly_empty() %>% layout(title = "No data to display")
    } else {
      method_counts <- data %>% count(Method)
      plot_ly(method_counts, x = ~Method, y = ~n, type = 'bar') %>%
        layout(title = "Homicides by Method", xaxis = list(title = "Method"), yaxis = list(title = "Count"))
    }
  })

  # District bar chart
  output$district_bar <- renderPlotly({
    data <- filtered_data()
    if(nrow(data) == 0) {
      plotly_empty() %>% layout(title = "No data to display")
    } else {
      district_counts <- data %>% count(District)
      plot_ly(district_counts, x = ~District, y = ~n, type = 'bar') %>%
        layout(title = "Homicides by District", xaxis = list(title = "District"), yaxis = list(title = "Count"))
    }
  })

  # Leaflet map
  output$incident_map <- renderLeaflet({
    data <- filtered_data()
    if(nrow(data) == 0) {
      leaflet() %>% addTiles() %>% setView(lng = -76.6122, lat = 39.2904, zoom = 10) %>%
        addPopups(-76.6122, 39.2904, "No incidents to display")
    } else {
      data <- data %>% filter(!is.na(lat) & !is.na(long))
      if(nrow(data) == 0) {
        leaflet() %>% addTiles() %>% setView(lng = -76.6122, lat = 39.2904, zoom = 10) %>%
          addPopups(-76.6122, 39.2904, "No geocoded locations available")
      } else {
        leaflet(data) %>%
          addTiles() %>%
          addCircleMarkers(
            lng = ~long, lat = ~lat,
            color = ~ifelse(CaseClosed == "Yes", "green", "red"),
            popup = ~paste(Name, "<br>", Date, "<br>", Method)
          ) %>%
          setView(lng = -76.6122, lat = 39.2904, zoom = 10)
      }
    }
  })

  # Data table
  output$data_table <- renderDT({
    datatable(filtered_data() %>% select(-full_address, -lat, -long))
  })
}

# Run the app
shinyApp(ui = ui, server = server)