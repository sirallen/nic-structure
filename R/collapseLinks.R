#' @import data.table

collapse_links <- function(dt) {
  # input - data.table of <from, to> pairs constituting the set of
  # new links (relative to previous period structure);
  # 
  # returns - data.table of <from, to> pairs where 'to' is a
  # 'top-level' new node, i.e., its parent 'from' is not new;
  # also a count of the new nodes that are subsidiaries of
  # the top-level new node
  d <- copy(dt)
  
  # function is otherwise identical for set of links removed /
  # destroyed; rename for convenience
  if ('to.removed' %in% names(d)) setnames(d, 'to.removed', 'to.new')
  
  d[, from.new:= as.numeric(from %in% to[to.new == 1])]
  # For now, only care about links to new nodes
  d <- d[to.new == 1]
  # Store list of subsidiary rssds (simply storing counts will
  # lead to double-counting)
  d[, to.children:= list()]
  
  N_lastiter <- nrow(d)
  
  # Need to identify "top-level" new nodes, and count
  # their subsidiaries. Start from the bottom (new nodes
  # with no subsidiaries) and count/collapse until reaching
  # a <from, to> link where from.new=0 and to.new=1
  while (d[, !all(from.new == 0)]) {
    d[, to.terminal:= as.numeric(!to %in% d$from)]
    # Also mark 'circular ownership' relationships as terminal (but
    # only when none have any other children); e.g., BoA 2004Q2, 2009Q1
    d.oneChild <- d[sapply(to, function(s) sum(s == d$from) == 1), .(from, to)]
    d.circular <- copy(d.oneChild)
    for (i in 1:3) {
      d.circular <- d.circular[d.oneChild, on = .(to == from), nomatch = 0]
      d.circular[from != to, to:= i.to][, i.to:= NULL]
    }
    
    d[d.circular[from == to], on = .(from == to), to.terminal:= 1]
    
    terminal.children <- d[to.terminal == 1,
                          .(list(unique(c(to, unlist(to.children))))),
                          by = 'from']
    
    # Drop the 'terminal' subsidiaries at the current iteration,
    # except after reaching a link to a 'top-level' subsidiary (when
    # from.new=0)
    d <- d[to.terminal == 0 | from.new == 0]
    
    # Update the list of children for parents of the (now removed)
    # 'terminal' nodes. Need to wrap in list() when there is only
    # one row (likewise below)
    d[terminal.children, on = .(to == from),
      to.children:= list(Map(c, to.children, V1))]
    
    # If no rows were removed, throw warning, break
    if (nrow(d) == N_lastiter) {
      warning('Ran into trouble; collapse incomplete', immediate. = TRUE)
      break
    }
    
    N_lastiter <- nrow(d)
  }
  
  # final de-duplication
  d[, to.children:= list(lapply(to.children, unique))]
  
  # result
  d[, .(from, to, to.numChildren = lengths(to.children))]
}
