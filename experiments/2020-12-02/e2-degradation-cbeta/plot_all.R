#!/usr/bin/env Rscript

library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(stringr)
library(tidyr)

main <- function() {
  output <- load_table('output')
  runs <- load_table('runs')
  output_runs <- output %>% left_join(runs, 'run_id')

  if(!dir.exists('plots')) {
    dir.create('plots')
  }
  
  for(prod_func in c('A', 'AF')) {
    for(beta in sort(unique(runs$beta_init_mean))) {
      for(rate_DF in sort(unique(runs$rate_DF))) {
        plot_one(output_runs, prod_func, beta, rate_DF)
      }
    }
  }
}

load_table <- function(tbl_name) {
  db <- dbConnect(SQLite(), 'db.sqlite')
  tbl <- dbGetQuery(db, str_glue('SELECT * FROM {tbl_name}'))
  dbDisconnect(db)
  
  tbl
}

plot_one <- function(df, prod_func, beta, rate_DF_) {
  subdir <- file.path(
    'plots', prod_func, sprintf('beta=%.2f', beta), sprintf('rate_DF=%.2f', rate_DF_)
  )
  if(!dir.exists(subdir)) {
    dir.create(subdir, recursive = TRUE)
  }

  LxL <- 200 * 200

  subdf <- df %>%
    filter(
      productivity_function_FH == sprintf('FH_%s', prod_func) &
      beta_init_mean == beta &
      rate_DF == rate_DF_
    )
  
  df_state = subdf %>%
    select(time, max_rate_AD, min_rate_frac_AD, H, A, F) %>%
    mutate(H = H / LxL, A = A / LxL, F = F / LxL) %>%
    mutate(D = 1 - H - A - F) %>%
    gather(`H`, `A`, `F`, `D`, key = 'state', value = 'density')
  
  plot_state(subdir, df_state)
}

plot_state <- function(subdir, df) {
  p <- ggplot(df, aes(x = time, y = density, color = state)) +
    geom_line() +
    facet_grid(rows = vars(min_rate_frac_AD), cols = vars(max_rate_AD), labeller = labeller(.rows = label_both, .cols = label_both))
  ggsave(file.path(subdir, 'timeseries.pdf'), p, width = 15, height = 15)
}

main()
