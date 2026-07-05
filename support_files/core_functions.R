# core functions
library(readxl)
library(dplyr)
library(tidyr)
library(lubridate)
library(slider)
library(sf)
library(readr)
library(ggplot2)
library(scales)
source("../support_files/theme.R")

#-- Functions in Functions
#----- bounded area in lat and long
declare_area_LL <- function(N=-45.7919, S=-45.9225,E=170.6657,W=170.32774) {
  declared = c("N"=N,"S"=S,"E"=E,"W"=W)
}

make_boundingbox_LL <- function(x){
  bbox_ll <- st_bbox(
    c(
      xmin = as.numeric(x["W"]),  # min longitude
      ymin = as.numeric(x["S"]),  # min latitude
      xmax = as.numeric(x["E"]),  # max longitude
      ymax = as.numeric(x["N"])   # max latitude
    ),
    crs = 4326
  )
  return(bbox_ll)
}

# functions reading in data

#----------bus functions
bus_read_data <- function(){
  boardings <- read_excel("../Data/ORC/David Hood request.xlsx")
  processed <- boardings |> 
    summarise(.by=c(`Operations Day`, Route),
              boardings = sum(`Boardings incl transfers`)) |> 
    mutate(adjusted_date = if_else(year(`Operations Day`) == 2025,
                                   `Operations Day` - days(1),
                                   `Operations Day`),
           Transport = "Bus Patrons") |> 
    filter(month(adjusted_date) < 6, year(adjusted_date) > 2024) |> 
    select(Transport, actual_date = `Operations Day`, adjusted_date, subdivision=Route, daily_subtotal=boardings)
}

cycle_read_data <- function(){
  sheets <- excel_sheets("../Data/DCC/Cycle & Pedestrian Counters - 2025 & 2026.xlsx")
  counames <- read.csv("../Data/DCC/counternames.csv")
  
  read_sheet <- function(x){
    sheetcontents <- read_excel(path = "../Data/DCC/Cycle & Pedestrian Counters - 2025 & 2026.xlsx", sheet=x, skip=1)
    # date formatting in excel file is a bit unstable
    # but it is in a higher predictable order, so easy to replace
    sheetcontents$Time = seq.Date(from=as.Date("2026-01-01"),
                                  to=as.Date("2026-12-31"),
                                  by="day")
    longform <- pivot_longer(sheetcontents, -Time, names_to = "locYr", values_to = "dailycount")
    return(longform)}
  
  allsheets_list <- lapply(sheets, read_sheet)
  cycle_contents <- bind_rows(allsheets_list) |> 
    separate(locYr, into=c("countloc", "yrtail"), sep = " 20") |> 
    mutate(cDate = if_else(yrtail == "26", Time,
                           Time - days(365)),
           countloc = gsub("â€™","'",countloc)) |> 
    inner_join(counames, by = join_by(countloc)) |>
    filter(type == "cycle") |> 
    mutate(adjusted_date = if_else(year(cDate) == 2025,
                                   cDate - days(1),
                                   cDate),
           Transport = "Cycle Counts") |> 
    filter(month(adjusted_date) < 6, year(adjusted_date) > 2024) |> 
    select(Transport, actual_date=cDate, adjusted_date, subdivision=countloc, daily_subtotal=dailycount)
}

pedestrian_read_data <- function(){
  sheets <- excel_sheets("../Data/DCC/Cycle & Pedestrian Counters - 2025 & 2026.xlsx")
  counames <- read.csv("../Data/DCC/counternames.csv")
  
  read_sheet <- function(x){
    sheetcontents <- read_excel(path = "../Data/DCC/Cycle & Pedestrian Counters - 2025 & 2026.xlsx", sheet=x, skip=1)
    # date formatting in excel file is a bit unstable
    # but it is in a higher predictable order, so easy to replace
    sheetcontents$Time = seq.Date(from=as.Date("2026-01-01"),
                                  to=as.Date("2026-12-31"),
                                  by="day")
    longform <- pivot_longer(sheetcontents, -Time, names_to = "locYr", values_to = "dailycount")
    return(longform)}
  
  allsheets_list <- lapply(sheets, read_sheet)
  cycle_contents <- bind_rows(allsheets_list) |> 
    separate(locYr, into=c("countloc", "yrtail"), sep = " 20") |> 
    mutate(cDate = if_else(yrtail == "26", Time,
                           Time - days(365)),
           countloc = gsub("â€™","'",countloc)) |> 
    inner_join(counames, by = join_by(countloc)) |>
    filter(type == "pedestrian") |> 
    mutate(adjusted_date = if_else(year(cDate) == 2025,
                                   cDate - days(1),
                                   cDate),
           Transport = "Pedestrian Counts") |> 
    filter(month(adjusted_date) < 6, year(adjusted_date) > 2024) |> 
    select(Transport, actual_date=cDate, adjusted_date, subdivision=countloc, daily_subtotal=dailycount)
}


NZTA_read_data <- function(x = "Light"){
  # Heavy or Light vehicles
  vclass = x
  # TMS readings for 2025 and earlier are assumed complete
  # so are in an file to save redownloading
  # file goes into 2026 but duplicates are removed later
  TMS_older <- read_csv("../Data/NZTA/TMS_Telemetry_Sites_asof_May1.csv",
                        col_types=cols(
                          OBJECTID = col_double(),
                          `Start Date` = col_datetime(format = "%m/%d/%Y %I:%M:%S %p"),
                          `Site Alias` = col_double(),
                          `Region Name` = col_character(),
                          `Site Reference` = col_character(),
                          `Class Weight` = col_character(),
                          `Site Description` = col_character(),
                          `Lane Number` = col_double(),
                          `Flow Direction` = col_double(),
                          `Traffic Count` = col_double()
                        ))
  
  # 2026 file redownloaded to make updates
  TMS_2026 <- read_csv("../Data/NZTA/TMS_2026.csv",
                       col_types=cols(
                         OBJECTID = col_double(),
                         `Start Date` = col_datetime(format = "%m/%d/%Y %I:%M:%S %p"),
                         `Site Alias` = col_double(),
                         `Region Name` = col_character(),
                         `Site Reference` = col_character(),
                         `Class Weight` = col_character(),
                         `Site Description` = col_character(),
                         `Lane Number` = col_double(),
                         `Flow Direction` = col_double(),
                         `Traffic Count` = col_double()
                       ))
  
  # clip with the bounding box and
  # syncronising 2025 readings with 2026 by days of the week
  time_reduced <- bind_rows(TMS_older, TMS_2026) |> 
    distinct() |> 
    mutate(adjusted_date = if_else(year(`Start Date`) == 2026, 
                                   `Start Date`, `Start Date` - days(1))) |> 
    filter(`Class Weight` == vclass,
           month(adjusted_date) < 6,
           year(adjusted_date) > 2024) |> 
    summarise(.by = c(`Site Reference`, adjusted_date, `Start Date`),
              counts=sum(`Traffic Count`)) |>  
    select(actual_date = `Start Date`, adjusted_date, SiteRef =  `Site Reference`, counts)
  
  #bounding lats & longsx
  area_latlong <- declare_area_LL()
  # easier to check the end map bounds online in lat/long so set it up and convert
  bbox_ll <- make_boundingbox_LL(area_latlong)
  bbox_nztm <- st_bbox(st_transform(st_as_sfc(bbox_ll), 2193))
  #--------------------------------------------------
  # TMS locations already in NZTM coordinates
  TMS_locations <- read_csv("../Data/NZTA/State_highway_traffic_monitoring_sites.csv")
  Bounded_Locations <- TMS_locations |> 
    filter(X > bbox_nztm["xmin"],
           X < bbox_nztm["xmax"],
           Y > bbox_nztm["ymin"],
           Y < bbox_nztm["ymax"])
  limited_set <- time_reduced |> 
    filter(SiteRef %in% Bounded_Locations$siteref) |> 
    group_by(SiteRef) |> 
    mutate(readings_n = n()) |> 
    ungroup() |> 
    filter(readings_n > max(readings_n) - 6) |> 
    select(-readings_n) |> 
    mutate(oneyear = if_else(year(adjusted_date) < 2026,
                             adjusted_date + days(365),
                             adjusted_date),
           Transport = paste(vclass, "Vehicles")) |> 
    group_by(oneyear) |> 
    mutate(daily_coverage = n()) |> 
    ungroup() |> 
    filter(daily_coverage == max(daily_coverage)) |> 
    select(Transport,actual_date, adjusted_date, subdivision=SiteRef, daily_subtotal=counts)
}

# functions summarising data

rolling7_total <- function(x){
  aggregated <- x |> 
    summarise(.by=adjusted_date,
              daily_total = sum(daily_subtotal)) |> 
    arrange(adjusted_date) |> 
    mutate(Yr = factor(year(adjusted_date)),
           date_2026 = if_else(Yr == "2026", adjusted_date,
                               adjusted_date + days(365))) |> 
    group_by(Yr) |> 
    mutate(rolling7 = slide_dbl(.x=daily_total, .f=mean, 
                                .before=6, .complete=FALSE)) |> 
    filter(!is.na(rolling7))
}

before_after <- function(x){
  aggregated <- x |> 
    #dailytotals, full fields
    summarise(.by=c(Transport, actual_date, adjusted_date),
              daily_total = sum(daily_subtotal)) |> 
    mutate(Mn = ifelse(month(adjusted_date) < 3,
                       "pre-crisis",
                       "fuel crisis"),
           Yr = factor(year(adjusted_date))) |> 
    # mean daily before and after by year
    summarise(.by=c(Transport, Yr,Mn),
              mean_daily = mean(daily_total)) |> 
    arrange(Yr, Mn) |> 
    group_by(Yr) |> 
    mutate(pre_percent = 100*mean_daily/ mean_daily[2],
           pre_raw = mean_daily - mean_daily[2]) |> 
    ungroup() |> 
    arrange(Mn, Yr) |> 
    group_by(Mn) |> 
    mutate(delta_percent = pre_percent[2] - pre_percent[1],
           delta_raw = pre_raw[2]-pre_raw[1])
}

subdiv_before_after <- function(x){
  aggregated <- x |> 
    mutate(Mn = ifelse(month(adjusted_date) < 3,
                       "pre-crisis",
                       "fuel crisis"),
           Yr = factor(year(adjusted_date))) |> 
    summarise(.by=c(subdivision, Transport, Yr,Mn),
              mean_daily = mean(daily_subtotal)) |> 
    arrange(Yr, Mn) |> 
    group_by(subdivision, Yr) |> 
    mutate(pre_percent = 100*mean_daily/ mean_daily[2] -100,
           pre_raw = mean_daily - mean_daily[2]) |> 
    ungroup() |> 
    arrange(Mn, Yr) |> 
    group_by(subdivision, Mn) |> 
    mutate(delta_percent = round(pre_percent[2]-pre_percent[1],1),
           delta_raw = pre_raw[2]-pre_raw[1],
           delta_percent_format= ifelse(delta_percent>0,
                                        paste0("+",delta_percent,"%"),
                                        paste0(delta_percent,"%"))) |> 
    ungroup() |> 
    filter(Yr == "2026", Mn == "fuel crisis",
           !is.na(delta_percent)) 
}

aggregate_by_weekday <- function(x){
  ## Weekday changes
  aggregs <- x |> 
    summarise(.by=adjusted_date,
              detections = sum(daily_subtotal)) |> 
    mutate(Mn = ifelse(month(adjusted_date) < 3,
                       "pre-crisis",
                       "fuel crisis"),
           Yr = factor(year(adjusted_date)),
           wkd = wday(adjusted_date, label = TRUE)) |> 
    summarise(.by=c(Mn,Yr,wkd),
              aver = mean(detections)) |> 
    arrange(wkd, Yr, Mn) |> 
    summarise(.by=wkd,
              chng = 100*(aver[3]/aver[4] - aver[1]/aver[2]))
  return(aggregs)
}

# functions making visualisations


create_basemap <- function(x="../Data/OSM/dunedin_osm_layers.gpkg"){
  # 1--read in features from gpkg (OSM + LINZ data)
  gpkg <- x
  land        <- st_read(gpkg, layer = "land", quiet = TRUE)
  coast       <- st_read(gpkg, layer = "coast", quiet = TRUE)
  waterways   <- st_read(gpkg, layer = "waterways", quiet = TRUE)
  roads       <- st_read(gpkg, layer = "roads", quiet = TRUE)
  actualroads <- st_read(gpkg, layer = "polyroads", quiet = TRUE)
  # actualroads LINZ nz-road-centrelines-topo-150k.kml
  bridges     <- st_read(gpkg, layer = "bridges", quiet = TRUE)
  parks       <- st_read(gpkg, layer = "parks", quiet = TRUE)
  buildings   <- st_read(gpkg, layer = "buildings", quiet = TRUE)
  bus_routes  <- st_read(gpkg, layer = "bus_routes", quiet = TRUE)
  landuse     <- st_read(gpkg, layer = "landuse", quiet = TRUE)
  waterbodies <- st_read(gpkg, layer = "waterbodies", quiet = TRUE)

  # 2--bounding box setup
  area_latlong <- declare_area_LL()
  bbox_ll <- make_boundingbox_LL(area_latlong)
  bbox_nztm <- st_bbox(st_transform(st_as_sfc(bbox_ll), 2193))

  # 3--Crop helper
  crop_layer <- function(x, bbox) {
    st_agr(x) <- "constant"
    if (!is.null(x) && nrow(x) > 0) {
      st_crop(x, bbox)
    } else {
      x
    }
  }
  
  # 4--Crop all layers
  # I think it is better to get everything ready, even if not used
  land_c        <- crop_layer(land, bbox_nztm)
  coast_c       <- crop_layer(coast, bbox_nztm)
  waterways_c   <- crop_layer(waterways, bbox_nztm)
  roads_c       <- crop_layer(roads, bbox_nztm)
  actualroads_c <- crop_layer(actualroads, bbox_nztm)
  bridges_c     <- crop_layer(bridges, bbox_nztm)
  parks_c       <- crop_layer(parks, bbox_nztm)
  buildings_c   <- crop_layer(buildings, bbox_nztm)
  bus_routes_c  <- crop_layer(bus_routes, bbox_nztm)
  landuse_c     <- crop_layer(landuse, bbox_nztm)
  waterbodies_c <- crop_layer(waterbodies, bbox_nztm)
  
  # turn the bounding box into an ocean layer

  bbox_geom <- st_as_sfc(bbox_nztm)
  # -----------------------------
  # 8. Plot basemap for later (NZTM)
  # -----------------------------
  watercolour = "#E0F2FF"
  greenery = "#E0F5E0"
  mapbase <- ggplot() +
    #ocean size of rectangle
    geom_sf(data = bbox_geom, fill = watercolour, colour = NA, linewidth = NA)+
    # Land base, that will be some of rectangle
    geom_sf(data = land_c, fill = "white", colour = NA) +
    # Landuse overlay shows where there are a bunch of urban trees
    # so not normally wanted
    # geom_sf(data = landuse_c, fill = greenery, colour = NA, alpha = 0.5) +
    # Water polygons
    #geom_sf(data = waterbodies_c, fill = watercolour, colour = NA) +
    # Parks
    #geom_sf(data = parks_c, fill = greenery, colour = NA) +
    # Roads and Tracks
    geom_sf(data = roads_c, colour = "grey80", size = 0.4) +
    # Actual Roads over the top of Roads and Tracks
    geom_sf(data=actualroads_c, fill=NA, colour="grey80", lwd=.5) +
    # Rivers/streams
    #geom_sf(data = waterways_c, colour = watercolour, size = 0.5) +
    # Bridges not needed as roads and tracks, but if they needed highlighting
    # geom_sf(data = bridges_c, colour = "red", size = 0.7) +
    # Bus routes
    # geom_sf(data = bus_routes_c, colour = "orange", linetype = "dashed") +
    # Buildings (on top)
    # geom_sf(data = buildings_c, fill = "grey75", colour = NA, alpha = 0.7) +
    # Optional coastline line overlay
    geom_sf(data = coast_c, colour = "grey80", size = 0.5) +
    coord_sf(crs = 2193) +
    theme_void()
  return(mapbase)
}

rolling_graph <- function(x){
  labelheight = max(0.5 * x$rolling7[x$date_2026 == ymd("2026-2-28")])
  g1 <- ggplot(trendata, aes(x=date_2026, y=rolling7, colour=Yr)) +
    coord_cartesian(ylim=c(0,NA)) +
    scale_y_continuous(labels = label_comma())+
    scale_colour_manual(name="Year",values=five_cols[c(5,1)]) +
    # 2025
    # 2025 school holidays
    annotate("rect", xmin=ymd("2026-4-12"), xmax=ymd("2026-4-27"),
             ymin=labelheight*.7,ymax=labelheight*2, fill=five_cols[5], alpha=.1)+
    # 2025 school holiday labels
    annotate("text", x=ymd("2026-4-27"), vjust=0, hjust=1, size=2.8,
             y=labelheight*.4, colour=five_cols[5], label="2025 School\nHolidays")+
    # 2026
    # 2026 school holidays
    annotate("rect", xmin=ymd("2026-4-3"), xmax=ymd("2026-4-19"),
             ymin=labelheight*.7,ymax=labelheight*2, fill=five_cols[1], alpha=.1)+
    # 2026 school holiday labels
    annotate("text", x=ymd("2026-4-3"), vjust=1, hjust=0, size=2.8,
             y=labelheight*.3, colour=five_cols[1], label="2026 School\nHolidays")+
    # 
    geom_vline(xintercept = ymd("2026-2-28"), colour=five_cols[3]) +
    annotate("text", x=ymd("2026-2-27"), y=labelheight, label="Start of War",
             colour=five_cols[3], angle=90,vjust=0, size=3.2) +
    
    geom_line() + theme_david() +
    theme(legend.position = "inside",
          legend.position.inside = c(.28,.15)) +
    labs(y=NULL, x=NULL)
  return(g1)
}


weekplot <- function(x){
  wplt <- ggplot(x, aes(x=wkd,y=chng)) + 
    geom_col(fill=five_cols[1]) + 
    theme_david() +
    theme(axis.line.x.bottom = element_blank(),
          axis.line.y.left = element_blank()) +
    geom_hline(yintercept = 0, col="#CCCCCC") +
    labs(x=NULL, y=NULL)
  return(wplt)
}

allgraph <- function(x){
  labelsized <- 2.6
  txtlabs <- x |> 
    filter(Mn == "fuel crisis") |> 
    mutate(xtx = ifelse(delta_percent > 0, 
                        paste0("+", round(delta_percent,1)),
                        as.character(round(delta_percent,1))),
           xtxplus = paste0(Transport,", ", xtx, "%"))
  
  gall <- ggplot(x, aes(colour=Transport, linetype=Transport)) +
    geom_segment(aes(x=x1,xend=x2,y=delta_percent,yend=delta_percent)) +
    theme_david() +
    labs(title="2026 Change in Transport compared to 2025 pattern.",
         subtitle="Mar-May average change as percentage of Jan-Feb baseline",
         y="Change vs. expected percentage", x=NULL,
         caption="Sources: DCC, NZTA, ORC") + 
    coord_cartesian(ylim=c(-10,40)) +
    geom_vline(xintercept = ymd("2026-2-28")+.5, linewidth=0.2) +
    annotate("line",x=c(ymd("2026-01-01"),ymd("2026-02-28")),
             y=c(0,0), linewidth=0.2) +
    annotate("text",x=ymd("2026-02-27"),y=0, hjust=1, size=labelsized,
             label="Baseline expects things\nto be the same as 2025",
             lineheight = 1.1) +
    annotate("text",x=ymd("2026-02-25"),y=8, angle = 90, hjust=0,
             label="Outbreak of war", size=labelsized)  +
    theme(legend.position = "none",
          axis.line.y.left= element_blank(),
          axis.line.x.bottom= element_blank()) +
    geom_text(data=txtlabs, aes(x=x2, 
                                y=delta_percent + c(-3,3,3,
                                                    -3,-3), 
                                label=xtxplus),
              hjust=1, size=labelsized)+
    scale_colour_manual(values=five_cols[c(5,3,3,1,1)]) +
    scale_linetype_manual(values=c(1,1,2,2,1))
  return(gall)
}

# -- saving images

figuresave = function(x, fname){
  pathval <- paste0("../Figures_standalone/",fname,".png")
  ggsave(filename = pathval, plot = x, width=5, height=3,
         units="in", dpi=300)
}
