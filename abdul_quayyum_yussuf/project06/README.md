# Baltimore City Police Department Homicide Analysis Dashboard

## Part 1: Data Pipeline and Histogram
(This section describes Part 1 from project05)

This repository contains a project that scrapes the 2025 and 2026 Baltimore City homicide lists from the Chamspage blog and produces a histogram of victim ages. By combining data from multiple years, the analysis strengthens the visualization of demographic patterns in homicide victimization across a broader timeframe.

### Files in Part 1 (project05)
- `histogram.R` – main R script that performs scraping from both years, cleaning, table output, and histogram generation.
- `Dockerfile` – builds an R environment with dependencies.
- `run.sh` – convenience wrapper to build and run the Docker container.
- `README.md` – documentation for Part 1.

## Part 2: Interactive Shiny Dashboard

Part 2 builds upon the data pipeline from Part 1 to create a comprehensive interactive dashboard for analyzing Baltimore City homicides. The dashboard provides dynamic filtering, multiple visualizations, and summary statistics to support police department briefings and investigative analysis.

### Features

#### Interactive Filters
- **Year Range**: Select specific years (2025, 2026) to analyze.
- **Victim Age Range**: Slider to filter by minimum and maximum victim age.
- **Homicide Method**: Multi-select dropdown for methods (Shooting, Stabbing, Beating, Other) extracted from incident notes.
- **Case Status**: Filter by case closure status (open/closed cases).
- **District**: Multi-select dropdown for geographic districts parsed from addresses.

#### Visualizations
All charts update dynamically based on applied filters:

1. **Homicides Over Time**: Line chart showing monthly homicide trends.
2. **Homicides by Method**: Bar chart displaying counts by homicide method.
3. **Homicides by District**: Bar chart showing incidents by geographic area.
4. **Incident Map**: Interactive Leaflet map with color-coded markers (green for closed cases, red for open) showing incident locations. Markers include popup details.
5. **Data Table**: Filterable table of all incident data.

#### Summary Statistics Panel
- Total homicides in filtered period
- Case clearance rate (%)
- Average victim age
- Most common homicide method
- Percentage of incidents near CCTV cameras
- Year-over-year comparison (when applicable)

### Data Pipeline
The dashboard reuses the scraping logic from Part 1, pulling data from the Chamspage blog posts for 2025 and 2026. Data is cached locally to improve performance. Additional processing includes:
- Age extraction and cleaning
- Method classification from notes
- District parsing from addresses
- Geocoding for map visualization

### Files in Part 2 (project06)
- `app.R` – Single-file Shiny application with full dashboard functionality.
- `Dockerfile` – Docker configuration for running the Shiny app in a container.
- `run_dashboard.sh` – Shell script to build and run the dashboard container.
- `README.md` – This documentation.

### How to Run
1. Ensure Docker is installed on your system.
2. Navigate to the project06 directory.
3. Run the dashboard:
   ```bash
   ./run_dashboard.sh
   ```
4. Open your browser and go to `http://localhost:3838` to access the dashboard.

The script will automatically build the Docker image and start the container. The dashboard will scrape data on first run and cache it for subsequent uses.

### Screenshots
*(Placeholder for dashboard screenshots)*

- **Dashboard Overview**: Main interface with filters and summary statistics.
- **Trends Chart**: Example of the homicides over time visualization.
- **Incident Map**: Sample map view with markers.
- **Data Table**: Filtered data table view.

### Technical Details
- Built with Shiny and shinydashboard for the web interface.
- Uses Plotly for interactive charts and Leaflet for mapping.
- Geocoding performed using the tidygeocoder package.
- All dependencies are CRAN packages for reproducibility.
- Containerized with Docker for easy deployment.

### Edge Cases Handling
- Displays friendly messages when no data matches filters.
- Gracefully handles missing or NA values in all columns.
- Fallback to cached data if scraping fails.
