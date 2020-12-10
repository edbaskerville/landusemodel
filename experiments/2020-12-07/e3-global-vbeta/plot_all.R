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
    plot_one(output_runs, prod_func)
  }
  
  plot_beta_mean(output_runs)
}

load_table <- function(tbl_name) {
  db <- dbConnect(SQLite(), 'experiments/2020-12-07/e3-global-vbeta/db.sqlite')
  tbl <- dbGetQuery(db, str_glue('SELECT * FROM {tbl_name}'))
  dbDisconnect(db)
  
  tbl
}

plot_one <- function(df, prod_func) {
  subdir <- file.path(
    'plots', prod_func
  )
  if(!dir.exists(subdir)) {
    dir.create(subdir, recursive = TRUE)
  }

  LxL <- 200 * 200

  subdf <- df %>%
    filter(
      productivity_function_FH == sprintf('FH_%s', prod_func)
    )
  
  df_state = subdf %>%
    select(time, frac_global_FH, rate_DF, H, A, F) %>%
    mutate(H = H / LxL, A = A / LxL, F = F / LxL) %>%
    mutate(D = 1 - H - A - F) %>%
    gather(`H`, `A`, `F`, `D`, key = 'state', value = 'density')
  
  plot_state(subdir, df_state)
  plot_beta(subdir, subdf)
}

plot_state <- function(subdir, df) {
  p <- ggplot(df, aes(x = time, y = density, color = state)) +
    geom_line() +
    facet_grid(rows = vars(frac_global_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))
  ggsave(file.path(subdir, 'state.pdf'), p, width = 15, height = 15)
}

plot_beta <- function(subdir, df) {
  p <- ggplot(df, aes(x = time, color = state)) +
    geom_ribbon(aes(ymin = beta_025, ymax = beta_975), color = 'lightgray', fill = 'lightgray') +
    geom_line(aes(y = beta_500), color = 'darkgray') +

    scale_y_continuous("Deforestation rate")+

    geom_line(aes(y = beta_mean), color = 'red') +
    facet_grid(rows = vars(frac_global_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))
  ggsave(file.path(subdir, 'beta.pdf'), p, width = 15, height = 15)
}

plot_beta_mean <-function(df){
  beta_S<-df%>%
    dplyr::filter(time>600)%>%
    dplyr::mutate(Variant = substring(productivity_function_FH, 4))%>%
    dplyr::group_by(Variant,rate_DF,frac_global_FH)%>%
    dplyr::summarise_all(mean)%>% 
    ggplot(aes(y = beta_mean, x= factor(frac_global_FH),fill=Variant)) + 
    geom_bar(stat = "identity",position=position_dodge(),color="black")+
    geom_errorbar(aes(ymin = beta_025, ymax = beta_750),position=position_dodge()) +
    scale_y_continuous("deforestation rate",expand = expansion(mult = c(0, .1)))+
    scale_x_discrete("Fraction of global colonization events")+
    ggtitle("")+
    scale_fill_manual(values=c('#999999','#E69F00'))+
    facet_grid(rows = vars(), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))+
    theme_minimal(base_size = 9) 
    
  
  ggsave(file.path("experiments/2020-12-07/e3-global-vbeta/", 'vbeta_mean_sd_vs_frac_global.png'),   beta_S, width = 8.5, height = 4,units = "in")
  
}



main()
