setwd('C:/Users/sirallen/Dropbox/FRBR/NIC-structure/')
library(ggplot2)
source('_getBhcSpan.R')

load('app/bhcList.RData')

spans = lapply(bhcList, getBhcSpan, returnQtrs=FALSE)

spans = rbindlist(spans, idcol='Name')

spans[end=='9999-12-31', end:= Sys.Date()]

### Join contiguous intervals together
while (nrow(spans[spans, on=.(Name, end=start), nomatch=0]) > 0) {
  spans[spans, on=.(Name, end=start), end:= i.end]
}

spans = spans[!duplicated(spans[, .(Name, end)])]
###

spans[, Name:= stringr::str_wrap(Name, width=23)]
spans[, Name:= factor(Name, levels=rev(unique(Name)))]

# save
save(spans, file='app/data/coverage.RData')

start_date = as.Date('2000-03-31')

ggplot(spans, aes(x=Name, y=seq.Date(min(start), max(end),
                                     along.with=spans$start))) +
  geom_segment(aes(x=Name, xend=Name,
                   y=pmax(start, start_date),
                   yend=pmax(end, start_date))) +
  geom_point(aes(x=Name, y=pmax(start, start_date)), color='red', size=2) +
  geom_point(aes(x=Name, y=pmax(end, start_date)), color='red', size=2) +
  #scale_y_date(sec.axis=dup_axis()) + # can't do this
  scale_y_date(position='top') +
  coord_flip() +
  labs(x='', y='') +
  theme(axis.text.y=element_text(size=6)) +
  ggsave('charts/HoldingCompanyCoverage.pdf', dev='pdf', width=8, height=12) +
  ggsave('charts/HoldingCompanyCoverage.png', dev='png', width=8, height=12,
         dpi=150)


