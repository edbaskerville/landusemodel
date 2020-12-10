#!/usr/bin/env Rscript

library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(stringr)
library(tidyr)

EXP_DIR_RELATIVE <- 'experiments/2020-12-09/e1-colonization-vbeta'

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
  subdir <- file.path('plots', prod_func)
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
    filter(productivity_function_FH == sprintf('FH_%s', prod_func))
  
  df_state <- subdf %>%
    select(time, max_rate_FH, rate_DF, H, A, F) %>%
    mutate(H = H / LxL, A = A / LxL, F = F / LxL) %>%
    mutate(D = 1 - H - A - F) %>%
    gather(`H`, `A`, `F`, `D`, key = 'state', value = 'density')
  
  plot_state(subdir, df_state)
  plot_beta(subdir, subdf)
  plot_beta_SS(df)
  plot_beta_states(df)
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
  LxL <- 200 * 200
  pH <-df%>%
    dplyr::filter(time>600)%>%
    dplyr::group_by(max_rate_FH,productivity_function_FH,rate_DF)%>%
    
    dplyr::summarise_all(mean)%>%
    dplyr::ungroup()%>%
    ggplot(aes(x = beta_mean, y = H/LxL,color=productivity_function_FH)) +
    geom_point()+
    
    facet_grid(rows = vars(max_rate_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))+
    ggtitle("Seattlements")
  
  pA <-df%>%
    dplyr::filter(time>600)%>%
    dplyr::group_by(max_rate_FH,productivity_function_FH,rate_DF)%>%
    
    dplyr::summarise_all(mean)%>% 
    ggplot(aes(x = beta_mean, y = A/LxL,color=productivity_function_FH)) +
    geom_point()+
    
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
    
    facet_grid(rows = vars(max_rate_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))+
    ggtitle("Forest")
  
  pD <-df%>%
    dplyr::filter(time>600)%>%
    dplyr::group_by(max_rate_FH,productivity_function_FH,rate_DF)%>%
    
    dplyr::summarise_all(mean)%>% 
    ggplot(aes(x = beta_mean, y = A/LxL,color=productivity_function_FH)) +
    geom_point()+
    
    facet_grid(rows = vars(max_rate_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))+
    ggtitle("Degraded")
  ggsave('vbeta_states.png', gridExtra::grid.arrange(pH,pA,pF,pD), width = 12, height = 12)
  

  beta_S<-df%>%
    dplyr::filter(time>600)%>%
    dplyr::mutate(Variant = substring(productivity_function_FH, 4))%>%
    dplyr::mutate(`forest regeneration` = 1/rate_DF)%>%
    dplyr::mutate(` ` = max_rate_FH)%>%
    dplyr::group_by(max_rate_FH,Variant,`forest regeneration`)%>%
    
    dplyr::summarise_all(mean)%>% 
    ggplot(aes(y = beta_mean, x=factor(`forest regeneration`),fill=Variant)) + 
    geom_bar(stat = "identity",position=position_dodge(),color="black",size=0.3)+
    geom_errorbar(aes(ymin = beta_025, ymax = beta_750),size=0.3,position=position_dodge()) +
    scale_y_continuous("deforestation rate",expand = expansion(mult = c(0, .1)))+
    scale_x_discrete("Forest regeneration [years]")+
    theme_minimal(base_size = 10) +
   scale_fill_manual(values=c('#999999','#E69F00'))+
    facet_grid(rows = vars(), cols = vars(` `), labeller = labeller(.rows = label_both, .cols = label_both))+
    ggtitle("")+
    theme(panel.grid.major.x = element_blank(),
          panel.grid.minor.x = element_blank())
  
  ggsave('vbeta_mean_sd_vs_rate_DF.png',   beta_S, width = 8.5, height = 4,units = "in")
  
  
  
  beta_points<-df%>%
    dplyr::filter(time>600)%>%
    dplyr::mutate(Variant = substring(productivity_function_FH, 4))%>%
    dplyr::mutate(`forest regeneration` = 1/rate_DF)%>%
    
    dplyr::group_by(max_rate_FH,Variant,`forest regeneration`)%>%
    
    dplyr::summarise_all(mean)%>% 
    ggplot(aes(y = beta_mean, x= `forest regeneration`,color=Variant,size=max_rate_FH)) + 
    geom_point()+
    scale_y_continuous("deforestation rate",expand = expansion(mult = c(0, .1)))+
    scale_x_discrete("Forest regeneration [years]")+
    scale_size("Max. colonization rate ",range=c(0.1,3))+
    scale_color_manual("Variant",values=c('#999999','#E69F00'),labels = c("A", "AF"))+
    ggtitle("")+
    theme_minimal()+
    theme(text = element_text(size=10))
  
  ggsave('vbeta_mean_sd_vs_rate_DF_points.png',   beta_points, width = 8.5, height = 5,units = "in")
  
  
  
  
}

plot_beta_states<-function(df){
  LxL <- 200 * 200
  pFD<-df%>%
    dplyr::filter(time>600)%>%
    dplyr::mutate(`forest regeneration` = 1/rate_DF)%>%
    dplyr::mutate(Variant = substring(productivity_function_FH, 4))%>%
    dplyr::group_by(max_rate_FH,Variant,`forest regeneration`)%>%
    
    dplyr::summarise_all(mean)%>%
    ggplot(aes(x = `forest regeneration`, y=F/LxL, size = max_rate_FH))+
    geom_point(aes(y=F/LxL,color="Forest"),alpha=0.7)+
    geom_point(aes(y=D/LxL,color="Degraded"),alpha=0.7)+
    scale_y_continuous("Density")+
    scale_x_continuous("",breaks = c(5,10,25,50,100))+
    scale_size("Forest regeneration [years]",range=c(0.1,2),guide="none")+
    scale_colour_manual("Land type",values = c("Forest"="darkgreen","Degraded"="brown"),guide="none")+
    theme_minimal(base_size = 12) +
    facet_grid(rows = vars(), cols = vars(Variant), labeller = labeller(.rows = label_both, .cols = label_both))

  pH<-df%>%
    dplyr::filter(time>600)%>%
    dplyr::mutate(`forest regeneration` = 1/rate_DF)%>%
    dplyr::mutate(Variant = substring(productivity_function_FH, 4))%>%
    dplyr::group_by(max_rate_FH,Variant,`forest regeneration`)%>%
  
    dplyr::summarise_all(mean)%>%
    ggplot(aes(x = `forest regeneration`, size = max_rate_FH))+
  geom_point(aes(y=H/LxL,color="Human settlement"),alpha=0.7)+
    geom_point(aes(y=A/LxL,color="Agriculture"),alpha=0.7)+
    scale_y_continuous("Density")+
    scale_x_continuous("",breaks = c(5,10,25,50,100))+
    scale_colour_manual("",values = c("Human settlement"="red","Agriculture"="yellow"),guide="none")+
  scale_size(range=c(0.1,2),guide="none")+
    theme_minimal(base_size = 12) +
      theme(axis.text.x=element_blank())+
      facet_grid(rows = vars(), cols = vars(Variant), labeller = labeller(.rows = label_both, .cols = label_both))


  
  
  
    ggsave('states_SS.png',   gridExtra::grid.arrange(pH,pFD,ncol=1), width = 8.5, height = 5,units = "in")
}


main()
