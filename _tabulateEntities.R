library(data.table)
library(stringr)

regions = fread('app/Country-regions.csv')
states.rx = paste0('(',paste(state.abb, collapse='|'),'|DC)$')

files = dir('app/txt/', full.names=T)

# By world region
dt = rbindlist( lapply( files, function(z) {
  rssd = as.numeric(str_extract(z, '\\d+'))
  dat = fread(z)
  
  # Unique entities
  dat = dat[!duplicated(Id_Rssd)]
  
  dat[, Country:= gsub('.*(?<=,) *(.*)', '\\1', label, perl=T)]
  dat[grepl(states.rx, label), Country:= 'USA']
  
  # Remove nomatch=0 to check for missed values
  dat = regions[dat[, .(Id_Rssd=rssd, Country)], on='Country', nomatch=0]
  
  dat = dat[, .N, by=.(Id_Rssd, Region)]
  dat[, asOfDate:= as.Date( str_extract(z, '(?<=-)\\d+'), '%Y%m%d')]
} ) )

fwrite(dt, 'app/data/EntitiesByRegion.csv')


# By entity type
dt = rbindlist( lapply( files, function(z) {
  rssd = as.numeric(str_extract(z, '\\d+'))
  dat = fread(z)
  
  # Unique entities
  dat = dat[!duplicated(Id_Rssd)]
  dat[, Id_Rssd:= rssd]
  
  dat = dat[, .N, by=.(Id_Rssd,Type)]
  dat[, asOfDate:= as.Date( str_extract(z, '(?<=-)\\d+'), '%Y%m%d')]
} ) ); rm(files)

fwrite(dt, 'app/data/EntitiesByType.csv')

