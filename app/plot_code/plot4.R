if (link.node.ratio[Id_Rssd==rssd, .N > 2]) {
  dat = link.node.ratio[Id_Rssd==rssd]
  dat[, discontinuity:= c(FALSE, diff(asOfDate) > 92)]
  dat[, group:= cumsum(discontinuity)]
  
  p = ggplot(dat, aes(x=asOfDate, y=link.node.ratio)) +
    geom_line(aes(group=group)) +
    scale_x_date(date_breaks='2 years', labels=function(x) year(x)) +
    scale_y_continuous(limits=c(1,NA)) +
    labs(x='', y='#Connections / #Subsidiaries')
  
  # dotted lines for discontinuities
  for (d in dat[, which(discontinuity)]) {
    p = p + geom_path(data=dat[c(d-1,d)], lty=3) }
  
  p
}
