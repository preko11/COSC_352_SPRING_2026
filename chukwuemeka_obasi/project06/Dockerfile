FROM rocker/shiny:latest

RUN R -e "install.packages(c('shiny','plotly','dplyr','leaflet','lubridate'), repos='https://cloud.r-project.org/')"

COPY app.R /srv/shiny-server/
COPY baltimore_homicides.csv /srv/shiny-server/

EXPOSE 3838