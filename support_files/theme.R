library(ggplot2)
library(ggthemes)
library(viridisLite)

six_cols <- colorblind_pal()(6)
six_cols <- viridis(6, begin = .05, end = .9)
five_cols <- viridis(5, begin = .05, end = .70)

dual_ax_1 <- six_cols[2]
dual_ax_2 <- six_cols[3]


make_footer <- function(x){
  paste0(x,"\n Made by David Hood, ", Sys.Date())
}

bodyfont <- "Lato Regular"
systemfonts::register_font(
  name = bodyfont,
  plain = "/Users/hooda84p/Library/Fonts/Lato-Regular.ttf"
)

headfont <- "Lato Semibold"
systemfonts::register_font(
  name = headfont,
  plain = "/Users/hooda84p/Library/Fonts/Lato-Semibold.ttf"
)

theme_david <- function(){
  theme_minimal(base_family=bodyfont,
                header_family=headfont,
                base_size = 9,
                ink = "#000000", 
                paper = "#FFFFFF", 
                accent = "red") %+replace% 
    theme(text=element_text(family=bodyfont),
      axis.line = element_line(linewidth=0.2),
      axis.ticks = element_line(linewidth=0.2),
      axis.title = element_text(size = 8),
      axis.title.y.left = element_text(margin = margin(t = 5, r = 7, b = 5, l = 7, unit = "pt")),
      axis.title.x.bottom = element_text(margin = margin(t = 7, r = 5, b = 0, l = 5, unit = "pt")),
      panel.background = element_rect(fill = "#FFFFFF", colour = "#F7F7F7", linewidth=1),
      panel.grid = element_blank(),
      panel.spacing = unit(1, "lines"),
      plot.title.position = "plot",
      plot.title = element_text(lineheight = 1.18, size=12,
                                margin=margin(t = 5, r = 5, b = 10, l = 10, unit = "pt"),
                                hjust=0, vjust=0),
      plot.subtitle = element_text(lineheight = 1.18, size=10,
                                   margin=margin(t = 0, r = 5, b = 20, l = 10, unit = "pt"),
                                   hjust=0),
      plot.background = element_rect(fill = "#FFFFFF", colour="#FFFFFF"),
      plot.caption = element_text(margin=margin(t = 2, r = 5, b = 5, l = 5, unit = "pt"),
                                  lineheight = 1.15,
                                  size=8, hjust=1),
      plot.caption.position = "plot",
      plot.margin = margin(t=10,r=10,b=10,l=10),
      strip.text = element_text(margin = margin_part(b = -15, l = 6), hjust=0,
                                size = rel(1), colour="#00000099"),
      strip.clip = "off",
      strip.background = element_blank()
    )
}

theme_david_dual <- function(){
  theme_david() %+replace% 
    theme(axis.title.y.left  = element_text(color = dual_ax_1, hjust = .1),
          axis.text.y.left   = element_text(
            color = dual_ax_1,
            margin = margin(
              t = 5,
              r = 5,
              b = 5,
              l = 5,
              unit = "pt"
            )
          ),
          axis.ticks.y.left  = element_line(color = dual_ax_1),
          axis.line.y.left =  element_line(color = dual_ax_1, linewidth=.2),
          axis.title.y.right = element_text(color = dual_ax_2, hjust = .9),
          axis.text.y.right  = element_text(
            color = dual_ax_2,
            margin = margin(
              t = 5,
              r = 5,
              b = 5,
              l = 5,
              unit = "pt"
            )
          ),
          axis.ticks.y.right = element_line(color = dual_ax_2),
          axis.line.y.right = element_line(color = dual_ax_2, linewidth=.2),
          axis.title.x.bottom = element_text(margin = margin(t = 7, r = 5, b = 0, l = 5, unit = "pt")),
          panel.background = element_rect(fill = "#FFFFFF", colour = NA, linewidth=NULL)
    )
}

theme_david_map <- function(){
  theme_david() %+replace% 
    theme(
      text=element_text(family=bodyfont),
      axis.line = element_blank(),
      axis.ticks = element_blank(),
      axis.text = element_blank(),
      axis.title = element_blank(),
      axis.title.x.bottom = element_blank(),
      axis.title.y.left = element_blank(),
      panel.background = element_rect(fill = "#FFFFFF", colour = NA),
      panel.grid = element_blank(),
      plot.title.position = "plot",
      plot.title = element_text(lineheight = 1.18, size=12,
                                margin=margin(t = 5, r = 5, b = 10, l = 10, unit = "pt"),
                                hjust=0, vjust=0),
      plot.subtitle = element_text(lineheight = 1.18, size=10,
                                   margin=margin(t = 0, r = 5, b = 20, l = 10, unit = "pt"),
                                   hjust=0),
      plot.background = element_rect(fill = "#FFFFFF", colour="#FFFFFF"),
      plot.caption = element_text(margin=margin(t = 2, r = 5, b = 5, l = 5, unit = "pt"),
                                  lineheight = 1.15,
                                  size=8, hjust=1),
      plot.caption.position = "plot",
      plot.margin = margin(t=10,r=10,b=10,l=10),
      strip.text = element_text(margin = margin_part(b = -15, l = 6), hjust=0,
                                size = rel(1), colour="#00000099"),
      strip.clip = "off",
      strip.background = element_blank(),
      panel.spacing = unit(1, "lines")
    )
}

theme_david_round <- function(){
  theme_david() %+replace% 
    theme(text=element_text(family=bodyfont),
          axis.line.x = element_line(linewidth=0.2),
          axis.line.y = element_line(linewidth=0.2, colour="white"),
          axis.ticks = element_line(linewidth=0.2),
          axis.title.y = element_text(margin = margin(t = 5, r = 7, b = 5, l = 7, unit = "pt"), colour="black", angle=90, hjust=0.7),
          axis.title.x.bottom = element_text(margin = margin(t = 7, r = 5, b = 0, l = 5, unit = "pt")),
          panel.background = element_rect(fill = "#FFFFFF", colour = NA, linewidth=1),
          panel.grid = element_line(colour="grey", linewidth = 0.1),
          plot.title.position = "plot",
          plot.title = element_text(lineheight = 1.18, size=12,
                                    margin=margin(t = 5, r = 5, b = 10, l = 10, unit = "pt"),
                                    hjust=0, vjust=0),
          plot.subtitle = element_text(lineheight = 1.18, size=10,
                                       margin=margin(t = 0, r = 5, b = 20, l = 10, unit = "pt"),
                                       hjust=0),
          plot.background = element_rect(fill = "#FFFFFF", colour="#FFFFFF"),
          plot.caption = element_text(margin=margin(t = 2, r = 5, b = 5, l = 5, unit = "pt"),
                                      lineheight = 1.15,
                                      size=8, hjust=1),
          plot.caption.position = "plot",
          plot.margin = margin(t=5,r=5,b=5,l=5),
          strip.text = element_text(margin = margin_part(b = -15, l = 6), hjust=0,
                                    size = rel(1), colour="#00000099"),
          strip.clip = "off",
          strip.background = element_blank(),
          panel.spacing = unit(1, "lines")
    )
}

