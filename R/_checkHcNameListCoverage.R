#' @import data.table
#' @import stringr
# 1. Check to see if all HCs in txt/ files are in hc-name-list

checkBhcNameListCoverage <- function() {
  hcNameList <- fread('data/hc-name-list.txt')
  setnames(hcNameList, 'ID_RSSD','Id_Rssd')
  hcNameList <- hcNameList[!duplicated(Id_Rssd)]
  txtFiles <- dir(TXT_DIR, full.names = TRUE)
  
  allHcs <- rbindlist(
    lapply(txtFiles, function(z) {
      da <- fread(z, select = c('Id_Rssd','Type.code','Tier','Name'))
      top_rssd_name <- da[1, Name]
      da <- da[Type.code %in% hc.types]
      da[, `:=`(yearqtr = str_extract(z, '(?<=-)\\d{8}'),
                top_rssd = str_extract(z, '\\d+'),
                top_rssd_name = top_rssd_name)]
    })
  )
  
  setkey(allHcs, Id_Rssd, yearqtr)
  allHcs <- unique(allHcs)
  
  allHcs[, sum(Id_Rssd %in% hcNameList$Id_Rssd) / .N]
  
  #View( allHcs[!Id_Rssd %in% hcNameList$Id_Rssd] )
}


# Likewise, check that all HCs in FR Y-9Cs are in hc-name-list

