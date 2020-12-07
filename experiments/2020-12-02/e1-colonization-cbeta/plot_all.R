#!/usr/bin/env Rscript

library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(stringr)
library(tidyr)

main <- function() {
  output <- load_table("output")
  runs <- load_table("runs")
  output_runs <- output %>% left_join(runs, 'run_id')

  if(!dir.exists('plots')) {
    dir.create('plots')
  }
  
  for(prod_func in c('A', 'AF')) {
    for(beta in sort(unique(output_runs$beta_init_mean))) {
      plot_one(output_runs, prod_func, beta)
    }
  }
 
  if(!dir.exists('plots_b')) {
    dir.create('plots_b')
  }
  
   
      plot_two(output_runs)

}

load_table <- function(tbl_name) {
  db <- dbConnect(SQLite(), 'experiments/2020-12-02/e1-colonization-cbeta/db.sqlite')
  tbl <- dbGetQuery(db, str_glue('SELECT * FROM {tbl_name}'))
  dbDisconnect(db)
  
  tbl
}

plot_one <- function(df, prod_func, beta) {
  subdir <- file.path('plots', prod_func, sprintf('beta=%.3f', beta))
  if(!dir.exists(subdir)) {
    dir.create(subdir, recursive = TRUE)
  }

  LxL <- 200 * 200

  subdf <- df %>%
    filter(productivity_function_FH == sprintf('FH_%s', prod_func) & beta_init_mean == beta) %>%
    select(time, max_rate_FH, rate_DF, H, A, F) %>%
    mutate(H = H / LxL, A = A / LxL, F = F / LxL) %>%
    mutate(D = 1 - H - A - F) %>%
    gather(`H`, `A`, `F`, `D`, key = 'state', value = 'density')

  
  
  plot_timeseries(subdir, subdf)
}


plot_two <- function(df) {
  subdir <- file.path('plots_b', sprintf('pop_SS=%.3f', 1))
  if(!dir.exists(subdir)) {
    dir.create(subdir, recursive = TRUE)
  }
  
  LxL <- 200 * 200
  
  subdf2 <- df %>%
    filter(time>1000) %>%
    select(time, beta_mean,max_rate_FH, rate_DF, H, A, F,productivity_function_FH) %>%
    mutate(H = H / LxL, A = A / LxL, F = F / LxL) %>%
    mutate(D = 1 - H - A - F) %>%
    gather(`H`, `A`, `F`, `D`, key = 'state', value = 'density')
  
  
  
  plot_beta_F_A_AF(subdf2)
}



plot_timeseries <- function(subdir, subdf) {
  p <- ggplot(subdf, aes(x = time, y = density, color = state)) +
    geom_line() +
    facet_grid(rows = vars(max_rate_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))
  ggsave(file.path(subdir, 'timeseries.pdf'), p, width = 15, height = 15)
}

plot_beta_F_A_AF <- function(subdf2) {
  p_H <- dplyr::filter(subdf2,state=="H" & beta_mean<30)%>%
    ggplot(aes(x = beta_mean , y = density, color = productivity_function_FH ,group=time)) +
    geom_point()+
    
    facet_grid(rows = vars(max_rate_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))+
    ggtitle("Settlements")
  
  p_A <- dplyr::filter(subdf2,state=="A"  & beta_mean<30)%>%
    ggplot(aes(x = beta_mean , y = density, color = productivity_function_FH ,group=time)) +
    geom_point()+
    
    facet_grid(rows = vars(max_rate_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))+
    ggtitle("Agriculture")
  
  p_F <- dplyr::filter(subdf2,state=="F"  & beta_mean<30)%>%
    ggplot(aes(x = beta_mean , y = density, color = productivity_function_FH ,group=time)) +
    geom_point()+
    
    facet_grid(rows = vars(max_rate_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))+
    ggtitle("Forest")
  
  p_D <- dplyr::filter(subdf2,state=="D"  & beta_mean<30)%>%
    ggplot(aes(x = beta_mean , y = density, color = productivity_function_FH ,group=time)) +
    geom_point()+
    
    facet_grid(rows = vars(max_rate_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))+
    ggtitle("Degraded")
  
  
  
  ggsave(file.path('experiments/2020-12-02/e1-colonization-cbeta/cbeta_vs_states.png'),
         plot =  gridExtra::grid.arrange(p_H,p_A,p_F,p_D,ncol=2),
         width = 15, height = 15)
}



main()
