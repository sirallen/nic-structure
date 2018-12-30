#' @import data.table
#' @import dplyr
#' @import ggplot2
#' @import stringr
#' @import xts

theme_set(
  theme_bw() +
    theme(panel.border = element_rect(color = NA))
)

plotCoverage <- function(spans, start_date = as.Date('2000-03-31')) {
  
  plot <- ggplot(spans, aes(x = Name, y = seq.Date(min(start), max(end),
                                           along.with = spans$start))) +
    geom_segment(aes(x = Name, xend = Name,
                     y = pmax(start, start_date),
                     yend = pmax(end, start_date))) +
    geom_point(aes(x = Name, y = pmax(start, start_date)), color = 'red', size = 2) +
    geom_point(aes(x = Name, y = pmax(end, start_date)), color = 'red', size = 2) +
    #scale_y_date(sec.axis = dup_axis()) + # can't do this
    scale_y_date(position = 'bottom') +
    coord_flip() +
    labs(x = '', y = '') +
    theme(axis.text.y = element_text(size = 6)) +
    # ggsave('charts/HoldingCompanyCoverage.pdf', dev = 'pdf', width = 8, height = 12) +
    ggsave('charts/HoldingCompanyCoverage.png', dev = 'png', width = 8, height = 12, dpi = 150)
  
  return(plot)
}

plotLinkNodeRatioTs <- function() {
  # Heterogeneity in link-node ratios -- make this interactive
  # (hover over line --> bold + bhc label)
  linkNodeRatio <- fread('data/app/linkNodeRatio.csv')
  linkNodeRatio[, asOfDate:= as.Date(asOfDate)]
  
  plot <- ggplot(linkNodeRatio, aes(x = asOfDate, y = 1 / link.node.ratio)) +
    geom_line(aes(group = Id_Rssd)) +
    scale_y_continuous(limits = c(0, 1)) +
    scale_x_date(limits = c(as.Date('2010-01-01'), NA)) +
    labs(x = '') +
    ggsave('charts/linkNodeRatio.pdf', dev = 'pdf', width = 7.5, height = 5.5)
  
  return(plot)
}


# ------------------------------------------------------------------

plotAssetsVsLinkNodeRatio10Bn <- function() {
  hc10bn <- fread('data/app/HC10bn.csv')
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

