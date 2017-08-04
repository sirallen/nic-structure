if (entity.region[Id_Rssd==rssd, uniqueN(asOfDate) > 2]) {
  dat = entity.region[Id_Rssd==rssd]
  dat.ofc = entity.ofc[Id_Rssd==rssd]
  lev = dat[, N[.N], by='Region'][order(V1), Region]
  dat[, Region:= factor(Region, lev)]
  dat = zero_pad_plot1(dat)
  
  # Define "groups" to plot discontinuous geom_areas separately
  # (i.e., breaks when a firm was not an HC)
  dat[, group:= cumsum(c(TRUE, diff(asOfDate) > 92))]
  dat.ofc[, group:= cumsum(c(TRUE, diff(asOfDate) > 92))]
  
  p = ggplot(dat, aes(x=asOfDate, y=N))
  
  for (g in dat[, unique(group)]) {
    p = p + geom_area(data=dat[group==g], aes(fill=Region),
                      col='lightgray', pos='stack', size=.2, alpha=.9) +
      geom_line(data=dat.ofc[group==g],
                aes(x=asOfDate, y=N, color=factor('OFC', labels= str_wrap(
                  'Offshore Financial Centers (IMF Classification)', 30))),
                lwd=1.3, lty=2)
  }
  
  p + scale_color_manual(values='black') +
    scale_x_date(date_breaks='2 years', labels=function(x) year(x)) +
    labs(x='', y='Number of entities', color='') +
    guides(fill = guide_legend(order=1),
           color = guide_legend(order=2))
}

