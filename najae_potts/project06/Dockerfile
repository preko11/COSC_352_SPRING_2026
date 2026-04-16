FROM rocker/shiny:latest

# Install additional packages
RUN R -e "install.packages(c('rvest', 'dplyr', 'lubridate', 'plotly', 'DT', 'leaflet'), repos='https://cran.rstudio.com/')"

# Copy app files
COPY app.R /srv/shiny-server/
COPY scrape.R /srv/shiny-server/

# Expose port
EXPOSE 3838

# Run the app
CMD ["R", "-e", "shiny::runApp('/srv/shiny-server/app.R', port=3838, host='0.0.0.0')"]