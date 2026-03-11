library(shiny)
library(plotly)
library(dplyr)
library(leaflet)
library(lubridate)

# -----------------------------
# Load the homicide data
# -----------------------------

data <- read.csv("baltimore_homicides.csv")

data$date <- as.Date(data$date)

data$year <- year(data$date)
data$month <- month(data$date, label = TRUE)

# -----------------------------
# User Interface
# -----------------------------

ui <- fluidPage(

  titlePanel("Baltimore Police Homicide Dashboard"),

  sidebarLayout(

    sidebarPanel(

      selectInput(
        "year",
        "Select Year",
        choices = unique(data$year),
        selected = max(data$year)
      ),

      sliderInput(
        "age",
        "Victim Age Range",
        min = min(data$victim_age, na.rm = TRUE),
        max = max(data$victim_age, na.rm = TRUE),
        value = c(18, 60)
      ),

      checkboxGroupInput(
        "method",
        "Homicide Method",
        choices = unique(data$method),
        selected = unique(data$method)
      )

    ),

    mainPanel(

      h3("Summary Statistics"),

      fluidRow(

        column(3,
               h4("Total Homicides"),
               textOutput("total_homicides")
        ),

        column(3,
               h4("Clearance Rate"),
               textOutput("clearance_rate")
        ),

        column(3,
               h4("Average Victim Age"),
               textOutput("avg_age")
        ),

        column(3,
               h4("Incidents Near CCTV"),
               textOutput("cctv_percent")
        )

      ),

      hr(),

      tabsetPanel(

        tabPanel("Monthly Trend",
                 plotlyOutput("trend_plot")
        ),

        tabPanel("Method Distribution",
                 plotlyOutput("method_plot")
        ),

        tabPanel("Map",
                 leafletOutput("map")
        )

      )

    )
  )
)

# -----------------------------
# Server
# -----------------------------

server <- function(input, output) {

  # Filter the dataset based on user inputs
  filtered_data <- reactive({

    df <- data

    df <- df[df$year == input$year, ]

    df <- df[df$victim_age >= input$age[1] &
               df$victim_age <= input$age[2], ]

    df <- df[df$method %in% input$method, ]

    df
  })

  # -----------------------------
  # Summary statistics
  # -----------------------------

  output$total_homicides <- renderText({

    nrow(filtered_data())

  })


  output$clearance_rate <- renderText({

    df <- filtered_data()

    if(nrow(df) == 0){
      return("0%")
    }

    rate <- mean(df$cleared == TRUE, na.rm = TRUE)

    paste0(round(rate * 100,2), "%")

  })


  output$avg_age <- renderText({

    df <- filtered_data()

    round(mean(df$victim_age, na.rm = TRUE),1)

  })


  output$cctv_percent <- renderText({

    df <- filtered_data()

    if(nrow(df) == 0){
      return("0%")
    }

    pct <- mean(df$cctv == TRUE, na.rm = TRUE)

    paste0(round(pct * 100,2), "%")

  })


  # -----------------------------
  # Monthly trend chart
  # -----------------------------

  output$trend_plot <- renderPlotly({

    df <- filtered_data()

    monthly <- df %>%
      group_by(month) %>%
      summarise(count = n())

    plot_ly(
      data = monthly,
      x = ~month,
      y = ~count,
      type = "scatter",
      mode = "lines+markers"
    )

  })


  # -----------------------------
  # Method bar chart
  # -----------------------------

  output$method_plot <- renderPlotly({

    df <- filtered_data()

    method_counts <- df %>%
      group_by(method) %>%
      summarise(count = n())

    plot_ly(
      data = method_counts,
      x = ~method,
      y = ~count,
      type = "bar"
    )

  })


  # -----------------------------
  # Map of homicides
  # -----------------------------

  output$map <- renderLeaflet({

    df <- filtered_data()

    leaflet(df) %>%
      addTiles() %>%
      addCircleMarkers(
        lng = ~longitude,
        lat = ~latitude,
        radius = 4,
        popup = ~paste("Method:", method)
      )

  })

}

# Run the app
shinyApp(ui = ui, server = server)