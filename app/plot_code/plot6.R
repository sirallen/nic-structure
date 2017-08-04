if (link.node.ratio[Id_Rssd==rssd, .N] > 2) {
  dat = entity.region[Id_Rssd==rssd, .(N=sum(N)), by='asOfDate']
  dat.ratio = link.node.ratio[Id_Rssd==rssd]
  
  dat = dat[dat.ratio, on='asOfDate']
  dat[, discontinuity:= c(FALSE, diff(asOfDate) > 92)]
  dat[, group:= cumsum(discontinuity)]
  
  p = ggplot(dat, aes(x=link.node.ratio, y=N)) +
    geom_point() + geom_point(data=dat[month(asOfDate)==12], col='red') +
    geom_path(aes(group=group)) +
    scale_x_continuous(limits=c(1,NA)) +
    scale_y_continuous(limits=c(0,NA)) +
    labs(x='#Connections / #Subsidiaries', y='Number of entities')
  
  # dotted lines for discontinuities
  for (d in dat[, which(discontinuity)]) {
    p = p + geom_path(data=dat[c(d-1,d)], lty=3) }
  
  p + geom_text(data=dat[month(asOfDate)==12],
                aes(label=year(asOfDate) + 1), size=3, col='red',
                nudge_x = -.02*dat[, max(link.node.ratio) - 1])
  
}
