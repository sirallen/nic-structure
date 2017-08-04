dat = data()[[3]][, .(Id_Rssd, label)]
dat = dat[!duplicated(Id_Rssd)]
dat[, label:= gsub('.*, *(.*)', '\\1', label)]

dat = dat[, .N, by='label']
dat[, unit:= ifelse(label %in% c(state.abb,'DC'), 'States', 'Countries')]
# full names for states
dat[unit=='States', label:= c(state.name, 'District of Columbia')[
  match(label, c(state.abb,'DC'))]]
# pad with 'NULL' labels (N=0) if number of states or countries < 10
dat = null_pad_plot3(dat)

dat = dat[order(unit, N)]
dat = dat[dat[, tail(.I, 10), by='unit']$V1]

p1 = ggplot(dat[unit=='States'], aes(x=factor(label, label), y=N)) +
  geom_bar(stat='identity', fill='coral') +
  coord_flip() +
  labs(x='', y='Number of entities') +
  ggtitle('Top 10 States')

p2 = ggplot(dat[unit=='Countries'], aes(x=factor(label, label), y=N)) +
  geom_bar(stat='identity', fill='coral') +
  coord_flip() +
  labs(x='', y='Number of entities') +
  ggtitle('Top 10 Countries/Territories (outside U.S.)')

grid.arrange(p1, p2, ncol=2)

