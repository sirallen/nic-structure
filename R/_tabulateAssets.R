#' @import data.table
#' @import stringr

tabulateAssets <- function() {
  load('app/bhcList.RData')
  csvFiles <- dir(CSV_DIR, pattern = 'csv$', full.names = TRUE)
  
  assets <- rbindlist(
    lapply(csvFiles, function(z) {
      cat('Reading', z, '...\n')
      da = fread(z, select = c('RSSD9999','RSSD9001','BHCK2170'))
      da = da[RSSD9001 %in% bhcList]
      da[, BHCK2170:= as.numeric(BHCK2170)]
    })
  )
  
  setnames(assets, 'RSSD9999', 'yearqtr')
  setnames(assets, 'RSSD9001', 'Id_Rssd')
  assets[, yearqtr:= as.Date(as.character(yearqtr), '%Y%m%d')]
  setkey(assets, Id_Rssd, yearqtr)
  
  fwrite(assets, 'app/data/Assets.csv')
  
  return(NULL)
}

