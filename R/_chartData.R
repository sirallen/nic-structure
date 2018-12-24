#' @import data.table
#' @import dplyr
#' @import ggplot2
#' @import stringr
#' @import xts

theme_set(
  theme_bw() +
    theme(panel.border = element_rect(color = NA))
)

# Load and transform bhc-institution-histories; bhc==1 indicates
# whether firm was an HC during each interval between events
histories <- getHistories()
histories[bhc == 1, Type:= gsub('.*(?<=as |to )(a )?([^\\.]*)\\.?$',
                              '\\2', Event, perl = TRUE)]
histories[Type == 'BHC', Type:= 'Foreign Banking Organization as a BHC']

# Number of holding companies over time, by ENTITY_TYPE.
# Note: Don't use hc-name-list.txt; dates do not reflect holding
# company status. But make sure all HCs are in the histories file.
yearqtrs <- seq.Date(as.Date('1960-04-01'), as.Date('2017-01-01'), by = '3 months') - 1

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
fwrite(HCcounts, 'app/data/HCcounts.csv', quote = TRUE)


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
           ifelse(`Event Type` %in% c('Established','Changed_to_hc'),
                  'entry', 'exit')]

# Save for use in About.Rmd
fwrite(HCevents, 'app/data/HCevents.csv', quote = TRUE)


plotLinkNodeRatioTs <- function() {
  # Heterogeneity in link-node ratios -- make this interactive
  # (hover over line --> bold + bhc label)
  linkNodeRatio <- fread('app/data/linkNodeRatio.csv')
  linkNodeRatio[, asOfDate:= as.Date(asOfDate)]
  
  plot <- ggplot(linkNodeRatio, aes(x = asOfDate, y = 1 / link.node.ratio)) +
    geom_line(aes(group = Id_Rssd)) +
    scale_y_continuous(limits = c(0,1)) +
    scale_x_date(limits = c(as.Date('2010-01-01'), NA)) +
    labs(x = '') +
    ggsave('charts/linkNodeRatio.pdf', dev = 'pdf', width = 7.5, height = 5.5)
  
  return(plot)
}


# ------------------------------------------------------------------

plotAssetsVsLinkNodeRatio10Bn <- function() {
  hc10bn <- fread('app/data/HC10bn.csv')
  setnames(hc10bn, c('12/31/2016 Total Assets', 'RSSD ID'), c('asset', 'rssd'))
  hc10bn[, asset:= as.numeric(gsub('[^0-9]', '', asset))]
  
  files <- dir(TXT_DIR, pattern = '20161231', full.names = TRUE)
  
  dt <- rbindlist(
    lapply(files, function(z) {
      dat <- fread(z)
      
      dat[, .(
        rssd = as.numeric(str_extract(z, '\\d+')),
        N.links = .N,
        N.nodes = uniqueN(Id_Rssd),
        N.locs  = uniqueN(label),
        # not right--fix this
        #N.countries = uniqueN(gsub('.*(?>=, )(.*)', '\\1', label, perl=T)),
        link.node.ratio = .N / uniqueN(Id_Rssd) )]
    })
  )
  
  dt <- dt[hc10bn, on = 'rssd', nomatch = 0]
  
  plot <- ggplot(dt, aes(x = -log(asset), y = link.node.ratio)) +
    geom_point() +
    labs(y = paste0('log(# Nodes)'))
  
  return(plot)
}

plotNumberVsComplexity <- function(rssd) {
  files <- dir(TXT_DIR, pattern = rssd, full.names = TRUE)
  
  dt <- rbindlist(
    lapply( files, function(z) {
      dat <- fread(z)
      
      dat[, .(
        # Number of unique entities
        V1 = uniqueN(Id_Rssd),
        # Fraction of links to remove so that each subsidiary
        # has exactly one parent
        V2 = 1 - (uniqueN(Id_Rssd) - 1) / (.N - 1),
        asOfDate = as.Date(str_extract(z, '(?<=-)\\d+'), '%Y%m%d'))]
      
    })
  )
  
  rm(files)
  # scale factor for secondary axis
  sec_sc <- dt[, mean(V1) / mean(V2)]
  
  plot <- ggplot(dt, aes(x = asOfDate)) +
    geom_line(aes(y = V1, color = 'Number')) +
    geom_line(aes(y = V2 * sec_sc, color = 'Complexity')) +
    scale_y_continuous(sec.axis  =  sec_axis(~ . / sec_sc, 'Complexity')) +
    scale_color_manual(values  =  c('royalblue', 'orangered')) +
    labs(x = '', y = 'Number of entities', color = 'Measure') +
    theme(legend.position = c(.8,.9)) +
    ggsave(paste0('charts/', rssd, '.pdf'), dev = 'pdf', width = 7.5, height = 5.5)
  
  return(plot)
}

# Goldman Sachs
plotNumberVsComplexity('2380443')


