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


computeGraphSummaries <- function() {
  
  files <- dir(TXT_DIR, full.names = TRUE)
  
  dt <- rbindlist(
    lapply( files, function(z) {
      rssd <- as.numeric(str_extract(z, '\\d+'))
      dat <- fread(z, select = c('Id_Rssd', 'Type.code', 'label'))
      
      if (dat[, !Type.code[1] %in% HC_TYPES] | nrow(dat) < 2) {
        return(NULL)
      }
      
      summary <- dat[, .(Id_Rssd = rssd,
                         asOfDate = as.Date(str_extract(z, '(?<=-)\\d+'), '%Y%m%d'),
                         numLinks = .N - 1)]
      
      dat <- dat[!duplicated(Id_Rssd)]
      dat[, Country:= gsub('.*(?<=,) *(.*)', '\\1', label, perl = TRUE)]
      dat[grepl(STATES_RX, label), Country:= 'USA']
      dat[grepl('Macao|Macau|Labuan', label), Country:= str_extract(label, 'Macao|Macau|Labuan')]
      dat <- COUNTRY_REGIONS[dat[, .(Country, Type.code)], on = 'Country', nomatch = 0]
      
      summary <- cbind(
        summary,
        dat[, .(numNodes = .N, numOFC = sum(IMF_OFC), numCountries = uniqueN(Country))],
        dcast(dat[, .N, by = 'Region'], . ~ Region, value.var = 'N')[, -1],
        dcast(dat[, .N, by = 'Type.code'], . ~ Type.code, value.var = 'N')[, -1]
      )
    }),
    fill = TRUE
  )
  
  dt[is.na(dt)] <- 0
  setcolorder(dt, intersect(c('Id_Rssd', 'asOfDate', 'numLinks', 'numNodes', 'numCountries',
                    'numOFC', sort(unique(COUNTRY_REGIONS$Region)),
                    sort(ENTITY_TYPE_GROUPING$Type.code)), names(dt)))
  
  fwrite(dt, 'data/app/GraphSummary.csv')
}
