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
  
}

load_table <- function(tbl_name) {
  db <- dbConnect(SQLite(), 'experiments/2020-12-02/e1-colonization-vbeta/db.sqlite')
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
    select(time, max_rate_FH,productivity_function_FH,rate_DF, H, A, F) %>%
    mutate(H = H / LxL, A = A / LxL, F = F / LxL) %>%
    mutate(D = 1 - H - A - F) %>%
    gather(`H`, `A`, `F`, `D`, key = 'state', value = 'density')
  
  plot_state(subdir, df_state)
  plot_beta(subdir, subdf)
  plot_beta_SS(subdf)
}

plot_state <- function(subdir, df) {
  p <- ggplot(df, aes(x = time, y = density, color = state)) +
    geom_line() +
    facet_grid(rows = vars(max_rate_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))
  ggsave(file.path(subdir, 'state_e1_vb.pdf'), p, width = 15, height = 15)
}

plot_beta <- function(subdir, df) {
  p <- ggplot(df, aes(x = time, color = state)) +
    geom_ribbon(aes(ymin = beta_025, ymax = beta_975), color = 'lightgray', fill = 'lightgray') +
    geom_line(aes(y = beta_500), color = 'darkgray') +
    geom_line(aes(y = beta_mean), color = 'red') +
    facet_grid(rows = vars(max_rate_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))
  ggsave(file.path(subdir, 'beta_e1_vb.pdf'), p, width = 15, height = 15)
}




plot_beta_SS <- function(df) {
 
  pH <-df%>%
    dplyr::filter(time>600)%>%
    dplyr::group_by(max_rate_FH,productivity_function_FH,rate_DF)%>%
    
    dplyr::summarise_all(mean)%>%
    dplyr::ungroup()%>%
    ggplot(aes(x = beta_mean, y = H/LxL,color=productivity_function_FH)) +
    geom_point()+
    scale_x_log10()+
    facet_grid(rows = vars(max_rate_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))+
    ggtitle("Seattlements")
  
  pA <-df%>%
    dplyr::filter(time>600)%>%
    dplyr::group_by(max_rate_FH,productivity_function_FH,rate_DF)%>%
    
    dplyr::summarise_all(mean)%>% 
    ggplot(aes(x = beta_mean, y = A/LxL,color=productivity_function_FH)) +
    geom_point()+
    scale_x_log10()+
    geom_point(aes(x = beta_500), shape=2) +
    geom_point(aes(x = beta_max), shape=3) +
    scale_shape()+
    facet_grid(rows = vars(max_rate_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))+
    ggtitle("Agriculture")
  pF <-df%>%
    dplyr::filter(time>600)%>%
    dplyr::group_by(max_rate_FH,productivity_function_FH,rate_DF)%>%
    
    dplyr::summarise_all(mean)%>% 
    ggplot(aes(x = beta_mean, y = F/LxL,color=productivity_function_FH)) +
    geom_point()+
    scale_x_log10()+
    facet_grid(rows = vars(max_rate_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))+
    ggtitle("Forest")
  
  pD <-df%>%
    dplyr::filter(time>600)%>%
    dplyr::group_by(max_rate_FH,productivity_function_FH,rate_DF)%>%
    
    dplyr::summarise_all(mean)%>% 
    ggplot(aes(x = beta_mean, y = A/LxL,color=productivity_function_FH)) +
    geom_point()+
    scale_x_log10()+
    facet_grid(rows = vars(max_rate_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))+
    ggtitle("Degraded")
  ggsave(file.path("experiments/", 'vbeta_states.png'),   gridExtra::grid.arrange(pH,pA,pF,dP), width = 12, height = 12)
  
  
}

plot_beta_states<-function(df){
  pFD<-df%>%
    dplyr::filter(time>600)%>%
    dplyr::group_by(max_rate_FH,productivity_function_FH,rate_DF)%>%
    
    dplyr::summarise_all(mean)%>%
    ggplot(aes(x = rate_DF, y=F/LxL, size = max_rate_FH))+
    geom_point(aes(y=F/LxL),color="darkgreen")+
    geom_point(aes(y=D/LxL),color="brown")+
    
    scale_size(range=c(0.1,3))+
    facet_grid(rows = vars(), cols = vars(productivity_function_FH), labeller = labeller(.rows = label_both, .cols = label_both))+theme_bw()
  pFD
  pH<-df%>%
    dplyr::filter(time>600)%>%
    dplyr::group_by(max_rate_FH,productivity_function_FH,rate_DF)%>%
  
    dplyr::summarise_all(mean)%>%
    ggplot(aes(x = rate_DF, y=H/LxL, size = max_rate_FH))+
  geom_point(aes(y=H/LxL),color="red")+
    geom_point(aes(y=A/LxL),color="yellow")+
    
  scale_size(range=c(0.1,3))+
    facet_grid(rows = vars(), cols = vars(productivity_function_FH), labeller = labeller(.rows = label_both, .cols = label_both))+theme_bw()


  gridExtra::grid.arrange(pH,pFD)
  
  
  
  
    ggsave(file.path("experiments/2020-12-02/e1-colonization-vbeta/", 'states_SS.png'),   gridExtra::grid.arrange(pH,pFD), width = 12, height = 12)
}
plot_beta_states(output_runs)

main()
