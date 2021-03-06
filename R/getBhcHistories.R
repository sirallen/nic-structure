# Function getBhcSpan() takes rssd as input, outputs vector of yearqtrs
# when it had holding company status, based on institution histories
# scraped from NIC and stored in "bhc-institution-histories.txt";
# Optional argument "start_date" controls the earliest date returned
#' @import data.table
#' @import zoo

getHistories <- function() {
  histories <- fread('data/bhc-institution-histories.txt')
  setnames(histories, 'Historical Event', 'Event')
  
  # Really, everything except "moved" and "renamed"; but events can be
  # combined into one line, so not enough to just exclude those (i.e.,
  # want to keep events where entity "changed" AND "moved");
  histories <- histories[Event == '' | grepl(
    'established|changed|acquired|closed|inactive|sold|split', Event)]
  
  # Mark events with "x" and then use a Reduce() trick to figure out when
  # an RSSD was a BHC.
  # Note: Type can be "Foreign Banking Organization as a BHC"
  histories[grepl('established', Event),
            x:= as.numeric(grepl('Holding|BHC', Event))]
  # Terminal events
  histories[Event == '' | grepl('acquired|closed|inactive|sold|split', Event),
            x:= -1]
  histories[grepl('changed', Event),
            x:= ifelse(grepl('changed.* to .*(Holding|BHC)',
                             Event, perl = TRUE), 2, -1)]
  
  # bhc: indicator of whether a firm was a BHC/FHC during period starting
  # at event date, until next event date
  histories[, bhc:= Reduce(function(a, b) as.numeric(a + b > 0),
                           x, accumulate = TRUE), by = 'Id_Rssd']
  
  histories[, next_Event_Date:= shift(`Event Date`, type = 'lead',
                                      fill = '9999-12-31'), keyby = 'Id_Rssd']
  
  return(histories)
}


getBhcSpan <- function(rssd, start_date, histories, returnQtrs = TRUE) {
  # Given rssd, figure out when it was a BHC or FHC
  intervals <- histories[J(rssd)][bhc == 1, .(
    start = as.Date(`Event Date`), end = as.Date(next_Event_Date))]
  
  if (!returnQtrs) return(intervals)
  
  start_date <- as.Date(as.yearqtr(start_date, '%Y-%m-%d'))
  qtrs <- seq(as.Date(start_date), Sys.Date(), by = '3 months') - 1
  
  return(qtrs[qtrs %inrange% intervals])
}


getBhcSpans <- function(start_date = as.Date('2000-03-31')) {
  load('data/app/bhcList.RData')
  histories <- getHistories()
  
  spans <- lapply(bhcList, getBhcSpan, start_date = start_date,
                  histories = histories, returnQtrs = FALSE)
  spans <- rbindlist(spans, idcol = 'Name')
  spans[end == '9999-12-31', end:= Sys.Date()]
  
  ### Join contiguous intervals together
  while (nrow(spans[spans, on = .(Name, end = start), nomatch = 0]) > 0) {
    spans[spans, on = .(Name, end = start), end:= i.end]
  }
  
  spans <- spans[!duplicated(spans[, .(Name, end)])]
  spans[, Name:= str_wrap(Name, width = 23)]
  spans[, Name:= factor(Name, levels = rev(unique(Name)))]
  
  save(spans, file = 'data/app/coverage.RData')
  
  return(spans)
}
