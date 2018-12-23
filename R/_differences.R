#' @import data.table
#' @import stringr
#' @import networkD3

options(warn = 0)

# Temporary function to aid debugging
plot_d <- function(d) {
  nodes <- d[, unique(c(from, to))]
  Nodes <- data.table(id = seq_along(nodes) - 1, rssd = as.character(nodes), group = 1)
  Links <- d[, .(from = match(from,nodes) - 1, to = match(to,nodes) - 1, value = 1)]
  
  forceNetwork(Links, Nodes, 'from', 'to', 'value', 'rssd', Group = 'group',
               linkDistance = JS('function(d){return 50}'),
               arrows = TRUE, fontSize = 12, zoom = TRUE, opacityNoHover = 1)
}

# Stuck on Morgan Stanley 2008Q3;
# Northern Trust 2005Q1

computeGraphDifferences <- function(rssd) {
  rssd_files <- dir(path = TXT_DIR, pattern = as.character(rssd), full.names = TRUE)
  
  if (length(rssd_files) < 2) {
    cat('Skipped', names(bhcList)[match(rssd, bhcList)], '\n')
    next
  }
  
  cat('Computing link creation/destruction for',
      names(bhcList)[match(rssd, bhcList)], '...\n')
  
  dat <- setNames(
    lapply(rssd_files, fread),
    str_extract(rssd_files, '(?<=-)\\d{8}')
  )
  
  dat <- Filter(function(d) nrow(d) > 1, dat)
  
  links <- lapply(dat, function(d) d[-1, .(from = Parent, to = Id_Rssd)])
  # Names (to merge in below)
  names <- lapply(dat, function(d) unique(d[, .(to = Id_Rssd, to.name = Name)]))
  
  linksCreated <- Map(function(new, old) {
    z <- fsetdiff(new, old)
    # Indicator of whether 'to' node is new
    z[, to.new:= as.numeric(!to %in% old$to)]
  },
  # Note: Result inherits the names of links[-1]
  links[-1], head(links, -1)
  )
  
  linksCreated <- lapply(linksCreated, collapse_links)
  linksCreated <- Map(merge, linksCreated, names[-1], MoreArgs = list(by = 'to'))
  linksCreated <- lapply(linksCreated, function(d) {
    if (nrow(d) > 0) {
      d <- d[order(-to.numChildren)]
    }
    d[, .(from, to, to.numChildren, to.name)]
  })
  
  # Likewise for links removed (consolidation, sell-off, etc.)
  linksDestroyed <- Map(function(new,old) {
    z <- fsetdiff(old, new)
    z[, to.removed:= as.numeric(!to %in% new$to)]
  },
  links[-1], head(links, -1)
  )
  
  linksDestroyed <- lapply(linksDestroyed, collapse_links)
  linksDestroyed <- Map(merge, linksDestroyed, head(names, -1), MoreArgs = list(by = 'to'))
  linksDestroyed <- lapply(linksDestroyed, function(d) {
    if (nrow(d) > 0) {
      d <- d[order(-to.numChildren)]
    }
    d[, .(from, to, to.numChildren, to.name)]
  })
  
  linksDelta <- Map(list, linksCreated, linksDestroyed)
  linksDelta <- lapply(linksDelta, setNames, c('created', 'destroyed'))
  
  save(linksDelta, file = paste0('data/linksdelta/', rssd, '.Rdata'))
  
  return(NULL)
}

computeAllGraphDifferences <- function(bhcList) {
  lapply(bhcList, computeGraphDifferences)
}
