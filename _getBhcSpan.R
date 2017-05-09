library(data.table)

bhcHistories = fread('active-bhc-institution-histories.txt')
setnames(bhcHistories, 'Historical Event', 'Event')

bhcHistories = bhcHistories[grepl('established|changed', Event)]
bhcHistories[grepl('established', Event),
             x:= as.numeric(grepl('Holding', Event))]
bhcHistories[grepl('changed', Event),
             x:= ifelse(grepl('(?<=to ).*Holding',
                              Event, perl=T), 2, -1)]

# bhc: indicator of whether a firm was a BHC/FHC during period starting
# at event date, until next event date
bhcHistories[, bhc:= Reduce(function(a,b) as.numeric(a+b > 0),
                            x, acc=T), by='Id_Rssd']

bhcHistories[, next_Event_Date:= shift(`Event Date`, type='lead'), by='Id_Rssd']
bhcHistories[is.na(next_Event_Date), next_Event_Date:= '2016-12-31']
setkey(bhcHistories, 'Id_Rssd')


getBhcSpan = function(rssd, start_date='2008-04-01') {
  # Given rssd, figure out when it was a BHC or FHC
  intervals = bhcHistories[J(rssd)][bhc==1, .(
    start=as.Date(`Event Date`), end=as.Date(next_Event_Date))]
  
  qtrs = seq(as.Date(start_date), Sys.Date(), by='3 months') - 1
  qtrs[qtrs %inrange% intervals]
}

