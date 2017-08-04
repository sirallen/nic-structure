dat = data()[[3]][-1, .(Id_Rssd, Tier)]

dat[, linkDist:= min(Tier) - 1, by='Id_Rssd']
dat = dat[!duplicated(Id_Rssd)][order(linkDist)][, .N, by='linkDist']
dat[, cumShare:= cumsum(N)/sum(N)]

p = ggplot(dat, aes(x = as.factor(linkDist), y = N)) +
  geom_bar(stat='identity', fill='royalblue') +
  labs(x='Distance from center', y='Number of entities')

p + geom_line(aes(x = linkDist, y = cumShare*get_ymax(p)),
              lty=2, lwd=1.3, col='red') +
  scale_y_continuous(sec.axis = sec_axis(
    ~./get_ymax(p), 'Cum. fraction of entities',
    breaks = seq(0,1,.25)))

