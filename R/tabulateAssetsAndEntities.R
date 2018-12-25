#' @import data.table
#' @import stringr

tabulateAssets <- function() {
  load('data/app/bhcList.RData')
  csvFiles <- dir(CSV_DIR, pattern = 'csv$', full.names = TRUE)
  
  assets <- rbindlist(
    lapply(csvFiles, function(z) {
      cat('Reading', z, '...\n')
      da = fread(z, select = c('RSSD9999', 'RSSD9001', 'BHCK2170'))
      da = da[RSSD9001 %in% bhcList]
      da[, BHCK2170:= as.numeric(BHCK2170)]
    })
  )
  
  setnames(assets, 'RSSD9999', 'yearqtr')
  setnames(assets, 'RSSD9001', 'Id_Rssd')
  assets[, yearqtr:= as.Date(as.character(yearqtr), '%Y%m%d')]
  setkey(assets, Id_Rssd, yearqtr)
  
  fwrite(assets, 'data/app/Assets.csv')
  
  return(NULL)
}


tabulateEntities <- function() {
  
  files <- dir(TXT_DIR, full.names = TRUE)
  
  # By world region
  cat('Tabulating world regions...\n')
  dt <- rbindlist(
    lapply( files, function(z) {
      rssd <- as.numeric(str_extract(z, '\\d+'))
      dat <- fread(z, select = c('Id_Rssd', 'Type.code', 'label'))
      
      if (dat[, !Type.code[1] %in% HC_TYPES] | !nrow(dat) > 1) {
        return(NULL)
      }
      
      # Unique entities
      dat <- dat[!duplicated(Id_Rssd)]
      
      dat[, Country:= gsub('.*(?<=,) *(.*)', '\\1', label, perl = TRUE)]
      dat[grepl(STATES_RX, label), Country:= 'USA']
      
      # Remove nomatch=0 to check for missed values
      dat <- COUNTRY_REGIONS[dat[, .(Id_Rssd = rssd, Country)], on = 'Country', nomatch = 0]
      
      dat <- dat[, .N, by = .(Id_Rssd, Region)]
      dat[, asOfDate:= as.Date(str_extract(z, '(?<=-)\\d+'), '%Y%m%d')]
    })
  )
  
  fwrite(dt, 'data/app/EntitiesByRegion.csv')
  
  
  # By OFC status (IMF Classification)
  cat('Tabulating Offshore status...\n')
  dt <- rbindlist(
    lapply( files, function(z) {
      rssd <- as.numeric(str_extract(z, '\\d+'))
      dat <- fread(z, select = c('Id_Rssd', 'Type.code', 'label'))
      
      if (dat[, !Type.code[1] %in% HC_TYPES] | !nrow(dat) > 1) {
        return(NULL)
      }
      
      # Unique entities
      dat <- dat[!duplicated(Id_Rssd)]
      
      dat[, Country:= gsub('.*(?<=,) *(.*)', '\\1', label, perl = TRUE)]
      dat[grepl(STATES_RX, label), Country:= 'USA']
      dat[grepl('Macao|Macau|Labuan', label), Country:= str_extract(label, 'Macao|Macau|Labuan')]
      
      # Remove nomatch=0 to check for missed values
      dat <- COUNTRY_REGIONS[dat[, .(Id_Rssd = rssd, Country)], on = 'Country', nomatch = 0]
      
      dat <- dat[, .(N = sum(IMF_OFC == 1)), by = 'Id_Rssd']
      dat[, asOfDate:= as.Date(str_extract(z, '(?<=-)\\d+'), '%Y%m%d')]
    })
  )
  
  fwrite(dt, 'data/app/EntitiesByOFC.csv')
  
  
  # By entity type
  cat('Tabulating entity types...\n')
  dt <- rbindlist(
    lapply( files, function(z) {
      rssd <- as.numeric(str_extract(z, '\\d+'))
      dat <- fread(z, select = c('Id_Rssd', 'Type.code'))
      
      if (dat[, !Type.code[1] %in% HC_TYPES] | !nrow(dat) > 1) {
        return(NULL)
      }
      
      # Unique entities
      dat <- dat[!duplicated(Id_Rssd)]
      dat[, Id_Rssd:= rssd]
      
      dat <- dat[, .N, by = .(Id_Rssd,Type.code)]
      dat[, Type.code:= ENTITY_TYPE_GROUPING$domain[match(Type.code, ENTITY_TYPE_GROUPING$Type.code)]]
      dat[, asOfDate:= as.Date(str_extract(z, '(?<=-)\\d+'), '%Y%m%d')]
    })
  )
  
  setnames(dt, 'Type.code', 'Type')
  
  fwrite(dt, 'data/app/EntitiesByType.csv')
  
  
  # Link-node ratio
  cat('Tabulating link-node ratios...\n')
  dt <- rbindlist(
    lapply( files, function(z) {
      rssd <- as.numeric(str_extract(z, '\\d+'))
      dat <- fread(z, select = c('Id_Rssd', 'Type.code'))
      
      if (dat[, !Type.code[1] %in% HC_TYPES] | !nrow(dat) > 1) {
        return(NULL)
      }
      
      dat[, .(Id_Rssd = rssd,
              asOfDate = as.Date(str_extract(z, '(?<=-)\\d+'), '%Y%m%d'),
              link.node.ratio = .N / (uniqueN(Id_Rssd)-1))]
    })
  ); rm(files)
  
  fwrite(dt, 'data/app/linkNodeRatio.csv')
  
  return(NULL)
}
