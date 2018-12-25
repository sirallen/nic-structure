#' @import data.table
#' @import dplyr

getHcCounts <- function(yearqtrs, histories) {
  # Number of holding companies over time, by ENTITY_TYPE.
  # Note: Don't use hc-name-list.txt; dates do not reflect holding
  # company status. But make sure all HCs are in the histories file.
  
  # Important: use [closed, open] interval
  HCcounts <- rbindlist(
    lapply(as.character(yearqtrs) %>% setNames(nm = .), function(yearqtr) {
      yqCounts <- histories[bhc == 1][yearqtr >= `Event Date` &
                                        yearqtr < next_Event_Date,
                                      uniqueN(Id_Rssd), by = 'Type']
      yqCounts[, yearqtr:= as.Date(yearqtr)]
      
      return(yqCounts)
    })
  )
  
  HCcounts[, Type:= factor(Type, levels = BHC_CATEGORIES, labels = names(BHC_CATEGORIES))]
  
  # Save for use in About.Rmd
  fwrite(HCcounts, 'data/app/HCcounts.csv', quote = TRUE)
  
  return(NULL)
}


getHcEvents <- function(histories, yearqtrs) {
  # Breakdown of change in HCcounts by event type
  # For simplicity, change label of "Foreign Banking Organization as a BHC"
  histories[, Event:= gsub('as a BHC', 'Holding', Event)]
  
  histories[, `:=`(
    established = grepl('established', Event),
    changed_to_hc = grepl('changed((?!Holding).)* to .*Holding', Event, perl = TRUE),
    changed_from_hc = grepl('changed.*Holding.* to (.(?!Holding))*$', Event, perl = TRUE),
    closed = grepl('closed|inactive', Event),
    acquired = grepl('acquired|sold|split', Event),
    # only count "exit" events if it was an hc in last period
    bhc_last_period = shift(bhc, 1))]
  
  # Last day of quarter when event took place (comparable with yearqtrs above)
  histories[, `Event Yearqtr`:= as.character(
    as.Date(as.yearqtr(`Event Date`, '%Y-%m-%d') + 1/4) - 1)]
  
  HCevents <- rbindlist(
    lapply(as.character(yearqtrs) %>% setNames(nm = .), function(yearqtr) {
      # entry events
      Z = histories[bhc == 1][`Event Yearqtr` == yearqtr]
      yqEvents.entry <- Z[, .(
        Established   = if (nrow(Z) > 0) sum(established) else 0,
        Changed_to_hc = if (nrow(Z) > 0) sum(changed_to_hc) else 0)]
      
      # exit events
      Z <- histories[bhc_last_period == 1][`Event Yearqtr` == yearqtr]
      yqEvents.exit <- Z[, .(
        Acquired      = if (nrow(Z) > 0) -sum(acquired) else 0,
        Closed        = if (nrow(Z) > 0) -sum(closed) else 0,
        Changed_from_hc = if (nrow(Z) > 0) -sum(changed_from_hc) else 0)]
      
      yqEvents <- cbind(yqEvents.entry, yqEvents.exit)
      yqEvents[, yearqtr:= as.Date(yearqtr)]
      
      return(yqEvents)
      
    })
  )
  
  HCevents <- melt.data.table(HCevents, 'yearqtr', variable.name = 'Event Type')
  HCevents[, event.type:=
             ifelse(`Event Type` %in% c('Established', 'Changed_to_hc'),
                    'entry', 'exit')]
  
  # Save for use in About.Rmd
  fwrite(HCevents, 'data/app/HCevents.csv', quote = TRUE)
  
  return(NULL)
}
