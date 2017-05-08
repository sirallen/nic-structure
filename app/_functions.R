cc = fread('entityTypeGrouping.csv')
entity.region = fread('data/EntitiesByRegion.csv')
entity.region[, asOfDate:= as.Date(asOfDate)]
#regions = fread('Country-regions.csv')

quoteStr = function(v) paste(paste0('\"', v, '\"'), collapse=',')

d3IO    = function(id) div(id=id, class=id)

load_data = function(bhc, asOfDate) {
  dateStr = format.Date(asOfDate, '%Y%m%d')
  
  file = paste0('txt/', bhc,'-',dateStr,'.txt')
  
  if (!file.exists(file)) {
    message = paste('File', file, 'not found.')
    tryCatch(
      { shinyjs::logjs(message) },
      error = function(e) NULL )
    return(NULL) }
  
  df = fread(file)
  
  # Regions
  # df[, Country:= gsub('.*(?<=, )(.*)', '\\1', label, perl=T)]
  # df = regions[df, on='Country']
  
  dfnet = df[, .(from = Name[match(Parent, Idx)], to = Name, Id_Rssd, Type, Tier,
                 from.lat = lat[match(Parent, Idx)], from.lng = lng[match(Parent, Idx)],
                 to.lat = lat, to.lng = lng)][-1,]
  
  # Group entity types
  dfnet = dfnet[cc[, .(domain, group)], on=.(Type==domain), Type:= group]
  
  dfnet[, Tier:= min(Tier), by=.(from,to)]
  
  dfnet = dfnet[!duplicated(dfnet)]
  
  nodes = dfnet[, .(id = 0:uniqueN(to), name = c(from[1], unique(to)))]
  nodes[dfnet, on=.(name==to), Type:= Type]
  
  dfnet[nodes, on=.(from==name), from.id:= id]
  dfnet[nodes, on=.(to==name), to.id:= id]
  
  list(dfnet, nodes, df)
}

updateBhcList = function() {
  bhcList = unique(rbindlist(lapply(
        dir('txt/', '.txt', full.names=T),
        fread, nrows=1, select=c('Name','Id_Rssd') ) ))
  
  setkey(bhcList, Name)
  
  bhcList = setNames(bhcList$Id_Rssd, bhcList$Name)
  
  save(bhcList, file = 'bhcList.RData')
}




