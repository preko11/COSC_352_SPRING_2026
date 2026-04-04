# Baltimore City Homicide Dashboard (Shiny)

This project is a **Shiny dashboard** that analyzes Baltimore City homicide data. It scrapes live data from the Baltimore homicide list pages, processes it, and presents interactive visualizations and summary statistics.

## What’s Included
- A **Shiny app** (`app.R`) that presents:
  - Interactive charts (monthly trend and method breakdown)
  - Filter controls (year selector + victim age range)
  - Live summary statistics (total homicides, average age, most common method)
  - A data table view of the filtered records
- A **data scraper** (`scrape.R`) that pulls data directly from the source site when the app starts
- A **Dockerfile** that builds a containerized Shiny app environment
- A **run script** (`run_dashboard.sh`) that builds and runs the Docker container

---

##  Dependencies
The Shiny app uses the following CRAN packages (installed automatically inside the Docker container):

- `shiny` (app framework)
- `plotly` (interactive charts)
- `DT` (interactive data tables)
- `rvest` (web scraping)
- `dplyr` (data manipulation)
- `lubridate` (date parsing and handling)

Docker is required to run the dashboard in the provided container.

---

##  Running the App (Recommended: Docker)
From within `najae_potts/project06`, run:

```bash
./run_dashboard.sh
```

This script will:
1. Build a Docker image for the app
2. Run a container exposing port **3838**
3. Print a message telling you where to open the dashboard

Then open:

```
http://localhost:3838
```

### Notes
- The first run may take a minute while Docker installs R packages.
- The app scrapes live homicide data on startup, so it may take a few seconds before the charts fully populate.

---

## 🛠 Running Without Docker (Optional)
If you have R installed locally, you can run the app directly:

1. Open R in this directory (`najae_potts/project06`).
2. Install required packages:

```r
install.packages(c('shiny','plotly','DT','rvest','dplyr','lubridate'))
```

3. Run the app:

```r
shiny::runApp('app.R', port = 3838, host = '0.0.0.0')
```

Then open:

```
http://localhost:3838
```

---

##  How It Works
- `scrape.R` downloads homicide tables from public Baltimore homicide list pages.
- `app.R` loads the scraped data, filters based on user input, and renders:
  - a monthly homicide trend chart
  - a method breakdown bar chart
  - summary statistics and table output

---



---
