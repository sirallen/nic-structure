#' @import data.table

convertTxt2RData <- function() {
  txtFiles <- dir(TXT_DIR, 'txt$', full.names = TRUE)
  
  lapply(txtFiles, function(f) {
    df <- fread(f)
    if (df[, Type.code[1] %in% HC_TYPES] & nrow(df) > 1) {
      df[, c('Idx', 'Loc'):= NULL]
      save_name <- sub(TXT_DIR, RDATA_DIR, f)
      save_name <- sub('txt$', 'RData', save_name)
      save(df, file = save_name)
    }
  })
  
  return(NULL)
}
