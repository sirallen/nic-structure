
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
  
  load(file) # data.table "df"
  df[, Type.code:= cc$domain[match(Type.code, cc$Type.code)]]
  setnames(df, 'Type.code', 'Type')
  df = df[cc[, .(domain, group)], on=.(Type==domain), Group:= group]
  
  links = df[, .(
    from = Name[match(Parent, Id_Rssd)], to = Name, Id_Rssd, Parent, Type, Tier,
    from.lat = lat[match(Parent, Id_Rssd)], from.lng = lng[match(Parent, Id_Rssd)],
    to.lat = lat, to.lng = lng, to.Group = Group, value = 1L)][-1,]
  
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
  
  # links: <from, to, Id_Rssd, Parent, Type, Tier, from.lat, from.lng, to.lat,
  #         to.lng, to.Group, value, from.id, to.id>
  # nodes: <id, Id_Rssd, name, Group>
  # df:    <Note, Name, Id_Rssd, Parent, Type, Tier, label, lat, lng, Group>
  list(links, nodes, df)
}

updateIds = function(nodes, links) {
  # After subsetting nodes, update ids so that forceNetwork() works properly
  nodes[, new.id:= .I - 1L]
  links[nodes, on=.(to.id==id), to.id:= new.id]
  links[nodes, on=.(from.id==id), from.id:= new.id]
  nodes[, `:=`(id = new.id, new.id = NULL)]
}


