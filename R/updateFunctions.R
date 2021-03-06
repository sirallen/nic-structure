#' @import data.table
#' @import dplyr
#' @import stringr

updateBhcList <- function() {
  # Use most recent file for each rssd (need to get most recent HC name)
  bhcList <- dir(TXT_DIR, '.txt', full.names = TRUE) %>%
    `[`(!duplicated(str_extract(., '\\d+'), fromLast = TRUE)) %>%
    lapply(fread, nrows = 1, select = c('Name', 'Id_Rssd')) %>%
    rbindlist() %>%
    setkey(Name)
  
  bhcList <- setNames(bhcList$Id_Rssd, bhcList$Name)
  
  save(bhcList, file = 'data/app/bhcList.RData')
  
  ### Also update the histories saved file (saving a subset to
  # save space)
  histories <- fread('data/bhc-institution-histories.txt', key = 'Id_Rssd')
  histories <- histories[J(bhcList)]
  
  save(histories, file = 'data/app/histories.RData')
  
  return(NULL)
}


updateAll <- function(rssds = NULL, start_date = '2000-01-01', redownload = FALSE) {
  # Master function to update the data
  load('data/app/bhcList.RData')
  bhcList <- c(bhcList, rssds)
  
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
  
  cat('\n\nUpdating data/app/BhcList.Rdata...\n')
  updateBhcList()
  
  newFiles <- setdiff(dir(TXT_DIR, full.names = TRUE), oldFiles)
  
  # Run the geolocator
  cat('Running geolocator...\n')
  system2('python', args = c('py/_geolocator.py', '--files', newFiles), invis = FALSE)
  
  # Prompt to continue (may need to update _locationMasterEdits first)
  continue <- menu(c('Yes', 'No'), title = 'Continue?')
  
  if (continue == 2) stop()
  
  system2('python', args = c('py/_locationMasterEdits.py'))
  
  # Run the geolocator again (in case updates were made)
  cat('Running geolocator with updates...\n')
  system2('python', args = c('py/_geolocator.py', '--files', newFiles), invis = FALSE)
  
  cat('Converting txt/ to app/rdata/...\n')
  convertTxt2RData()
  
  cat('Computing graph summaries...\n')
  computeGraphSummaries()
  
  cat('Tabulating assets...\n')
  if (dir.exists(CSV_DIR)) tabulateAssets() else cat('SKIPPED\n')
  
  cat('Updating plots...\n')
  updatePlots()
  
  return(NULL)
}


updateHcCountsAndEvents <- function() {
  # Load and transform bhc-institution-histories; bhc==1 indicates
  # whether firm was an HC during each interval between events
  histories <- getHistories()
  histories[bhc == 1, Type:= gsub('.*(?<=as |to )(a )?([^\\.]*)\\.?$',
                                  '\\2', Event, perl = TRUE)]
  histories[Type == 'BHC', Type:= 'Foreign Banking Organization as a BHC']
  
  yearqtrs <- seq.Date(START_QTR, END_QTR, by = '3 months') - 1
  
  hcCounts <- getHcCounts(yearqtrs, histories)
  fwrite(HCcounts, 'data/app/HCcounts.csv', quote = TRUE)
  
  hcEvents <- getHcEvents(yearqtrs, histories)
  fwrite(HCevents, 'data/app/HCevents.csv', quote = TRUE)
  
  return(NULL)
}


updatePlots <- function() {
  spans <- getBhcSpans()
  plotCoverage(spans)
  plotLinkNodeRatioTs()
  plotAssetsVsLinkNodeRatio10Bn()
  plotNumberVsComplexity()
  # Goldman Sachs
  #plotNumberVsComplexity('2380443')
  
  return(NULL)
}
