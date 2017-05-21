# Function getBhcSpan() takes rssd as input, outputs vector of yearqtrs
# when it had holding company status, based on institution histories
# scraped from NIC and stored in "bhc-institution-histories.txt";
# Optional argument "start_date" controls the earliest date returned
library(data.table)
library(zoo)

bhcHistories = fread('bhc-institution-histories.txt')
setnames(bhcHistories, 'Historical Event', 'Event')

# Really, everything except "moved" and "renamed"; but events can be
# combined into one line, so not enough to just exclude those;
bhcHistories = bhcHistories[Event=='' | grepl(
  'established|changed|acquired|closed|inactive|sold|split', Event)]

# Note: Type can be "Foreign Banking Organization as a BHC"
bhcHistories[grepl('established', Event),
             x:= as.numeric(grepl('Holding|BHC', Event))]
# Terminal events
bhcHistories[Event=='' | grepl('acquired|closed|inactive|sold|split', Event),
             x:= -1]
bhcHistories[grepl('changed', Event),
             x:= ifelse(grepl('changed.* to .*(Holding|BHC)',
                              Event, perl=T), 2, -1)]

# bhc: indicator of whether a firm was a BHC/FHC during period starting
# at event date, until next event date
bhcHistories[, bhc:= Reduce(function(a,b) as.numeric(a+b > 0),
                            x, acc=T), by='Id_Rssd']

bhcHistories[, next_Event_Date:= shift(`Event Date`, type='lead'), by='Id_Rssd']
bhcHistories[is.na(next_Event_Date), next_Event_Date:= '9999-12-31']
setkey(bhcHistories, 'Id_Rssd')


getBhcSpan = function(rssd, start_date='2008-04-01') {
  # Given rssd, figure out when it was a BHC or FHC
  intervals = bhcHistories[J(rssd)][bhc==1, .(
    start=as.Date(`Event Date`), end=as.Date(next_Event_Date))]
  
  start_date = as.Date(as.yearqtr(start_date, '%Y-%m-%d'))
  qtrs = seq(as.Date(start_date), Sys.Date(), by='3 months') - 1
  qtrs[qtrs %inrange% intervals]
}

