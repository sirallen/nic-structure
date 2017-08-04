start_date = as.Date('2000-03-31')
load('data/coverage.RData')

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
  labs(x='', y='')

