#!/usr/bin/env Rscript

library(ggplot2)
library(dplyr)
library(tidyr)
library(stringr)
library(DBI)
library(RSQLite)

main <- function() {
  stopifnot(file.exists('output.sqlite'))
  
  db <- dbConnect(SQLite(), 'output.sqlite')
  
  output <- dbGetQuery(db, 'SELECT * FROM output')
  
  output_HAF <- gather(
    output %>% select(time, H, A, F),
    `H`, `A`, `F`,
    key = 'state', value = 'count'
  )
  
  p_HAF <- ggplot(output_HAF, aes(x = time, y = count, color = state)) +
    geom_line()
  ggsave('state_over_time.pdf', p_HAF)
  
  p_beta <- ggplot(output, aes(x = time)) +
    geom_line(aes(y = log(beta_mean)), color = 'blue') +
    geom_line(aes(y = log(beta_500)), color = 'red')
  ggsave('beta.pdf', p_beta)
  
  dbDisconnect(db)
}

main()
