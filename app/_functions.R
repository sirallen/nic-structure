# Load data
cc = fread('entityTypeGrouping.csv')
entity.region = fread('data/EntitiesByRegion.csv')
entity.region[, asOfDate:= as.Date(asOfDate)]

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
  bhcList = unique(rbindlist(lapply(
        dir('../txt/', '.txt', full.names=T),
        fread, nrows=1, select=c('Name','Id_Rssd') ) ))
  
  setkey(bhcList, Name)
  
  bhcList = setNames(bhcList$Id_Rssd, bhcList$Name)
  
  save(bhcList, file = 'bhcList.RData')
}


