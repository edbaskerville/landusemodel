#!/usr/bin/env Rscript

library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(stringr)
library(tidyr)

EXP_DIR_RELATIVE <- 'experiments/2020-12-09/e3-global-vbeta'

main <- function() {
  # Change to correct WD
  old_wd <- change_directory()
  
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
  
  # Reset WD
  setwd(old_wd)
}

change_directory <- function() {
  exp_name <- basename(EXP_DIR_RELATIVE)
  date_str <- basename(dirname(EXP_DIR_RELATIVE))
  
  old_wd <- getwd()
  cat(sprintf('old wd: %s\n', old_wd))
  
  old_wd_basename <- basename(old_wd)
  old_wd_dirname <- basename(dirname(old_wd))
  if(old_wd_basename == exp_name) {
    if(old_wd_dirname == date_str) {
      cat('Already in correct directory\n')
    }
    else {
      stop('In directory for wrong date!')
    }
  }
  else {
    if(endsWith(old_wd_basename, 'landusemodel')) {
      cat('In root; changing to experiment directory\n')
      setwd(EXP_DIR_RELATIVE)
    }
    else {
      stop("Can't deal with current WD")
    }
  }
  
  old_wd
}

load_table <- function(tbl_name) {
  db <- dbConnect(SQLite(), 'db.sqlite')
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
    dplyr::mutate(`forest regeneration` = 1/rate_DF)%>%
    select(time, frac_global_FH, `forest regeneration`, H, A, F) %>%
    mutate(H = H / LxL, A = A / LxL, F = F / LxL) %>%
    mutate(D = 1 - H - A - F) %>%
    gather(`H`, `A`, `F`, `D`, key = 'state', value = 'density')
  
  plot_state(subdir, df_state)
  plot_beta(subdir, subdf)
}

plot_state <- function(subdir, df) {
  p <- ggplot(df, aes(x = time, y = density, color = state)) +
    geom_line() +
    facet_grid(rows = vars(frac_global_FH), cols = vars(`forest regeneration`), labeller = labeller(.rows = label_both, .cols = label_both))
  ggsave(file.path(subdir, 'state.pdf'), p, width = 15, height = 15)
}

plot_beta <- function(subdir, df) {

  p <-  df%>%
    dplyr::mutate(`forest regeneration` = 1/rate_DF)%>%
    ggplot(aes(x = time, color = state)) +
    geom_ribbon(aes(ymin = beta_025, ymax = beta_975), color = 'lightgray', fill = 'lightgray') +
    geom_line(aes(y = beta_500), color = 'darkgray') +

    scale_y_continuous("Deforestation rate")+

    geom_line(aes(y = beta_mean), color = 'red') +
    facet_grid(rows = vars(frac_global_FH), cols = vars(`forest regeneration`), labeller = labeller(.rows = label_both, .cols = label_both))
  ggsave(file.path(subdir, 'beta.pdf'), p, width = 15, height = 15)
}

plot_beta_mean <-function(df){

  beta_S<-df%>%
    dplyr::filter(time>600)%>%
    dplyr::mutate(Variant = substring(productivity_function_FH, 4))%>%
    dplyr::mutate(`forest regeneration` = 1/rate_DF)%>%
    dplyr::group_by(Variant,`forest regeneration`,frac_global_FH)%>%
    dplyr::summarise_all(mean)%>% 
    ggplot(aes(y = beta_mean, x= factor(frac_global_FH),fill=Variant)) + 
    geom_bar(stat = "identity",position=position_dodge(),color="black",size=0.3)+
    geom_errorbar(aes(ymin = beta_025, ymax = beta_750),position=position_dodge(),size=0.3) +
    scale_y_continuous("Forest generation [years]",expand = expansion(mult = c(0, .1)))+
    scale_x_discrete("Fraction of global colonization events")+
    ggtitle("")+
    scale_fill_manual(values=c('#999999','#E69F00'))+
    facet_grid(rows = vars(), cols = vars(`forest regeneration`), labeller = labeller(.rows = label_both, .cols = label_both))+
    theme_minimal(base_size = 10) +
    theme(panel.grid.major.x = element_blank(),
          panel.grid.minor.x = element_blank(),axis.text.x = element_text(size=6))
    
  
  ggsave('vbeta_mean_sd_vs_frac_global.png',   beta_S, width = 8.5, height = 3,units = "in")
  
}



main()
