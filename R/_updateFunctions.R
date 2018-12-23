#' @import data.table
#' @import dplyr
#' @import stringr

updateBhcList <- function() {
  # Use most recent file for each rssd (need to get most recent HC name)
  bhcList <- dir(TXT_DIR, '.txt', full.names = TRUE) %>%
    `[`(!duplicated(str_extract(., '\\d+'), fromLast = TRUE)) %>%
    lapply(fread, nrows = 1, select = c('Name','Id_Rssd')) %>%
    rbindlist() %>%
    setkey(Name)
  
  bhcList <- setNames(bhcList$Id_Rssd, bhcList$Name)
  
  save(bhcList, file = 'app/bhcList.RData')
  
  ### Also update the histories saved file (saving a subset to
  # save space)
  histories <- fread('data/bhc-institution-histories.txt', key = 'Id_Rssd')
  histories <- histories[J(bhcList)]
  
  save(histories, file = 'app/data/histories.RData')
  
  return(NULL)
}


updateAll <- function(rssds = NULL, start_date = '2000-01-01', redownload = FALSE) {
  # Master function to update the data
  load('app/bhcList.RData')
  bhcList <- c(bhcList, rssds)
  bhcList <- bhcList[bhcList != 3833526]
  
  # Load/process 'histories' & function getBhcSpan()
  histories <- getHistories()
  
  as_of_dates <- lapply(bhcList, getBhcSpan, start_date = start_date, histories = histories)
  
  oldFiles <- setdiff(
    dir(TXT_DIR, full.names = TRUE),
    if (redownload) gsub('pdf', 'txt', unlist(Map(getPdfName, bhcList, as_of_dates)))
  )
  
  # Download new pdfs and convert to txt
  for (j in seq_along(bhcList)) {
    if (length(as_of_dates[[j]]) > 0) {
      cat('Requesting', names(bhcList)[j], '...\n')
      
      mapply(getReport, rssd = bhcList[j], as_of_date = as_of_dates[[j]],
             redownload = redownload)
    }
  }
  
  cat('\n\nUpdating app/BhcList.Rdata...\n')
  updateBhcList()
  
  #newFiles <- setdiff(dir(TXT_DIR, full.names = TRUE), oldFiles)
  newFiles <- file.info(dir(TXT_DIR, full.names = TRUE))
  newFiles <- rownames(newFiles)[newFiles$mtime > '2018-12-20']
  
  # Run the geolocator
  cat('Running geolocator...\n')
  system2('python', args = c('py/_geolocator.py', '--files', newFiles), invis = FALSE)
  
  # Prompt to continue (may need to update _locationMasterEdits first)
  menu(c('Yes','No'), title = 'Continue?')
  
  system2('python', args = c('py/_locationMasterEdits.py'))
  
  # Run the geolocator again (in case updates were made)
  cat('Running geolocator with updates...\n')
  system2('python', args = c('py/_geolocator.py', '--files', newFiles), invis = FALSE)
  
  cat('Converting txt/ to app/rdata/...\n')
  convertTxt2RData()
  
  cat('Tabulating entities...\n')
  tabulateEntities()
  
  cat('Tabulating assets...\n')
  tabulateAssets()
  
  cat('Updating coverage plot...\n')
  plotCoverage()
  
  return(NULL)
}


