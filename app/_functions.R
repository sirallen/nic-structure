
quoteStr = function(v) paste(paste0('\"', v, '\"'), collapse=',')

load_data = function(bhc, asOfDate) {
  dateStr = format.Date(asOfDate, '%Y%m%d')
  
  file = paste0('rdata/', bhc,'-',dateStr,'.RData')
  
  if (!file.exists(file)) {
    message = paste('File', file, 'not found.')
    tryCatch(
      { shinyjs::logjs(message) },
      error = function(e) NULL )
    return(NULL) }
  
  load(file) # object "df"
  df[, Type.code:= cc$domain[match(Type.code, cc$Type.code)]]
  setnames(df, 'Type.code', 'Type')
  df = df[cc[, .(domain, group)], on=.(Type==domain), Group:= group]
  
  links = df[, .(
    from = Name[match(Parent, Id_Rssd)], to = Name, Id_Rssd, Parent, Type, Tier,
    from.lat = lat[match(Parent, Id_Rssd)], from.lng = lng[match(Parent, Id_Rssd)],
    to.lat = lat, to.lng = lng, Group)][-1,]
  
  nodes = rbind(
    data.table(Id_Rssd=as.integer(bhc), name=links[1, from]),
    unique(links[, .(Id_Rssd, name=to)])
  )
  
  # id needs to be zero-indexed
  nodes[, id:= .I - 1L]; setcolorder(nodes, c(3,1,2))
  nodes[df, on='Id_Rssd', Group:= Group]
  
  # Add the node ids to links
  links[nodes, on=.(Parent==Id_Rssd), from.id:= id]
  links[nodes, on='Id_Rssd', to.id:= id]
  links[, value:= 1L]
  
  # links: <from, to, Id_Rssd, Parent, Type, Tier, from.lat, from.lng, to.lat,
  #         to.lng, from.id, to.id, value, Group>
  # nodes: <id, Id_Rssd, name, Group>
  # df:    <Note, Name, Id_Rssd, Parent, Type, Tier, label, lat, lng, Group>
  list(links, nodes, df)
}

updateBhcList = function() {
  mostRecentTxt = dir('../txt/', '.txt', full.names=T)
  # Index of last file for each rssd... since I need the most recent name
  lastIdxByRssd = by(mostRecentTxt, str_extract(mostRecentTxt, '\\d+'),
                     FUN=function(x) tail(x, 1))
  mostRecentTxt = mostRecentTxt[lastIdxByRssd]
  
  bhcList = unique(rbindlist(lapply(
        mostRecentTxt,
        fread, nrows=1, select=c('Name','Id_Rssd') ) ))
  
  setkey(bhcList, Name)
  
  bhcList = setNames(bhcList$Id_Rssd, bhcList$Name)
  
  save(bhcList, file = 'bhcList.RData')
  
  ### Also update the histories saved file (saving a subset to
  # save space)
  histories = fread('../bhc-institution-histories.txt', key='Id_Rssd')
  histories = histories[J(bhcList)]
  
  save(histories, file='data/histories.RData')
}

get_ymax = function(ggplot_object) {
  # return y-value of highest minor gridline
  tail(ggplot_build(ggplot_object)$layout$panel_ranges[[1]]$y.minor_source, 1)
}

zero_pad_plot1 = function(dat) {
  # Expand dat to include N=0 for missing regions for each asOfDate
  # (will fill in unwanted gaps in geom_area due to interpolation)
  dat.0 = expand.grid(Id_Rssd=dat[, Id_Rssd[1]], Region=dat[, unique(Region)],
                      asOfDate=dat[, unique(asOfDate)])
  setDT(dat.0)
  dat.0[dat, on=.(Id_Rssd, Region, asOfDate), N:= N]
  dat.0[is.na(N), N:= 0]
  dat.0
}

null_pad_plot3 = function(dat) {
  # input is a data.table with country counts and labels and "unit"
  # pad with 'NULL' labels (N=0) if number of states or countries < 10
  n.states.missing = dat[unit=='States', 10 - .N]
  n.countries.missing = dat[unit=='Countries', 10 - .N]
  dat = rbind(
    dat,
    if (n.states.missing > 0) data.table(
      label=paste0(mapply(strrep, ' ', 0:(n.states.missing-1)), 'NULL'),
      N=0,
      unit=rep('States', n.states.missing)),
    if (n.countries.missing > 0) data.table(
      label=paste0(mapply(strrep, ' ', 0:(n.countries.missing-1)), 'NULL'),
      N=0,
      unit=rep('Countries', n.countries.missing)))
  dat
}

