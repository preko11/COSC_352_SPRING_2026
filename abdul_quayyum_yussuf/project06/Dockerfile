# Dockerfile for Baltimore Homicide Dashboard

FROM rocker/shiny:4.3.3

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libudunits2-dev \
    libgdal-dev \
    && rm -rf /var/lib/apt/lists/*

# Install CRAN packages
RUN R -e "install.packages(c('shiny', 'shinydashboard', 'plotly', 'leaflet', 'DT', 'dplyr', 'tidyr', 'ggplot2', 'lubridate', 'httr', 'rvest', 'tidygeocoder', 'stringr'), repos='https://cloud.r-project.org/')"

# Copy the app
COPY app.R /srv/shiny-server/app.R

# Make sure the app is executable
RUN chmod +x /srv/shiny-server/app.R

# Expose port
EXPOSE 3838

# Run shiny server
CMD ["/usr/bin/shiny-server"]