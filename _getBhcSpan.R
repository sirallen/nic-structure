# Function getBhcSpan() takes rssd as input, outputs vector of yearqtrs
# when it had holding company status, based on institution histories
# scraped from NIC and stored in "bhc-institution-histories.txt";
# Optional argument "start_date" controls the earliest date returned
library(data.table)
library(zoo)

histories = fread('bhc-institution-histories.txt')
setnames(histories, 'Historical Event', 'Event')

# Really, everything except "moved" and "renamed"; but events can be
# combined into one line, so not enough to just exclude those (i.e.,
# want to keep events where entity "changed" AND "moved");
histories = histories[Event=='' | grepl(
  'established|changed|acquired|closed|inactive|sold|split', Event)]

# Mark events with "x" and then use a Reduce() trick to figure out when
# an RSSD was a BHC.
# Note: Type can be "Foreign Banking Organization as a BHC"
histories[grepl('established', Event),
          x:= as.numeric(grepl('Holding|BHC', Event))]
# Terminal events
histories[Event=='' | grepl('acquired|closed|inactive|sold|split', Event),
          x:= -1]
histories[grepl('changed', Event),
          x:= ifelse(grepl('changed.* to .*(Holding|BHC)',
                           Event, perl=TRUE), 2, -1)]

# bhc: indicator of whether a firm was a BHC/FHC during period starting
# at event date, until next event date
histories[, bhc:= Reduce(function(a,b) as.numeric(a+b > 0),
                         x, accumulate=TRUE), by='Id_Rssd']

histories[, next_Event_Date:= shift(`Event Date`, type='lead',
                                    fill='9999-12-31'), keyby='Id_Rssd']


getBhcSpan = function(rssd, start_date, returnQtrs=TRUE) {
  # Given rssd, figure out when it was a BHC or FHC
  intervals = histories[J(rssd)][bhc==1, .(
    start=as.Date(`Event Date`), end=as.Date(next_Event_Date))]
  
  if (!returnQtrs) return(intervals)
  
  start_date = as.Date(as.yearqtr(start_date, '%Y-%m-%d'))
  qtrs = seq(as.Date(start_date), Sys.Date(), by='3 months') - 1
  qtrs[qtrs %inrange% intervals]
}

