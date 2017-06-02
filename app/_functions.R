# Load data
cc = fread('entityTypeGrouping.csv')
entity.region = fread('data/EntitiesByRegion.csv')
entity.region[, asOfDate:= as.Date(asOfDate)]
entity.ofc = fread('data/EntitiesByOFC.csv')
entity.ofc[, asOfDate:= as.Date(asOfDate)]
link.node.ratio = fread('data/linkNodeRatio.csv')
link.node.ratio[, asOfDate:= as.Date(asOfDate)]
assets = fread('data/Assets.csv')
assets[, yearqtr:= as.Date(yearqtr)]
# measure in billions
assets[, BHCK2170:= BHCK2170/1e6]

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
  
  load(file)
  df[, Type.code:= cc$domain[match(Type.code, cc$Type.code)]]
  setnames(df, 'Type.code', 'Type')
  df = df[cc[, .(domain, group)], on=.(Type==domain), Group:= group]
  
  dfnet = df[, .(
    from = Name[match(Parent, Idx)], to = Name, Id_Rssd, Type, Tier,
    from.lat = lat[match(Parent, Idx)], from.lng = lng[match(Parent, Idx)],
    to.lat = lat, to.lng = lng)][-1,]
  
  dfnet[, Tier:= min(Tier), by=.(from,to)]
  
  dfnet = dfnet[!duplicated(dfnet)]
  
  nodes = dfnet[, .(id = 0:uniqueN(to), name = c(from[1], unique(to)))]
  nodes[df, on=.(name==Name), Group:= Group]
  
  dfnet[nodes, on=.(from==name), from.id:= id]
  dfnet[nodes, on=.(to==name), to.id:= id]
  dfnet[, value:= 1L]
  
  list(dfnet, nodes, df)
}

updateBhcList = function() {
  mostRecentTxt = dir('../txt/', '.txt', full.names=T)
  # Index of last file for each rssd
  lastIdxByRssd = by(mostRecentTxt, str_extract(mostRecentTxt, '\\d+'),
                     FUN=function(x) tail(x, 1))
  mostRecentTxt = mostRecentTxt[lastIdxByRssd]
  
  bhcList = unique(rbindlist(lapply(
        mostRecentTxt,
        fread, nrows=1, select=c('Name','Id_Rssd') ) ))
  
  setkey(bhcList, Name)
  
  bhcList = setNames(bhcList$Id_Rssd, bhcList$Name)
  
  save(bhcList, file = 'bhcList.RData')
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

