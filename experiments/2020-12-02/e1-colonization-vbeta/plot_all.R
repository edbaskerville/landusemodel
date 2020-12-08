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
  plot_beta_states(subdf)
}

plot_state <- function(subdir, df) {
  p <- ggplot(df, aes(x = time, y = density, color = state)) +
    geom_line() +
    facet_grid(rows = vars(max_rate_FH), cols = vars(rate_DF), labeller = labeller(.rows = label_both, .cols = label_both))
  ggsave(file.path(subdir, 'state_e1_vb.pdf'), p, width = 15, height = 15)
  ggsave(file.path(subdir, 'state.pdf'), p, width = 15, height = 15)
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
  ggsave(file.path("experiments/2020-12-02/e1-colonization-vbeta/", 'vbeta_states.png'),   gridExtra::grid.arrange(pH,pA,pF,pD), width = 12, height = 12)
  

  beta_S<-df%>%
    dplyr::filter(time>600)%>%
    dplyr::mutate(Variant = substring(productivity_function_FH, 4))%>%
    dplyr::group_by(max_rate_FH,Variant,rate_DF)%>%
    
    dplyr::summarise_all(mean)%>% 
    ggplot(aes(y = beta_mean, x= factor(1/rate_DF),fill=Variant)) + 
    geom_bar(stat = "identity",position=position_dodge(),color="black")+
    geom_errorbar(aes(ymin = beta_mean-beta_sd, ymax = beta_mean+beta_sd),position=position_dodge()) +
    scale_y_continuous("deforestation rate",expand = expansion(mult = c(0, .1)))+
    scale_x_discrete("Forest re-generation time")+
    facet_grid(rows = vars(), cols = vars(max_rate_FH), labeller = labeller(.rows = label_both, .cols = label_both))+
    ggtitle("")+
    theme_classic() +
    scale_fill_manual(values=c('#999999','#E69F00'))
  
  ggsave(file.path("experiments/2020-12-02/e1-colonization-vbeta/", 'vbeta_mean_sd_vs_rate_DF.png'),   beta_S, width = 22, height = 10)
  
  
  
  beta_points<-df%>%
    dplyr::filter(time>600)%>%
    dplyr::mutate(Variant = substring(productivity_function_FH, 4))%>%
    dplyr::group_by(max_rate_FH,Variant,rate_DF)%>%
    
    dplyr::summarise_all(mean)%>% 
    ggplot(aes(y = beta_mean, x= factor(1/rate_DF),color=Variant,size=max_rate_FH)) + 
    geom_point()+
    scale_y_continuous("deforestation rate",expand = expansion(mult = c(0, .1)))+
    scale_x_discrete("Forest re-generation time")+
    scale_size(range=c(0.2,4))+
    scale_color_manual("Variant",values=c('#999999','#E69F00'),labels = c("A", "AF"))+
    ggtitle("")+
    theme_classic()+
    theme(text = element_text(size=10))
  
  ggsave(file.path("experiments/2020-12-02/e1-colonization-vbeta/", 'vbeta_mean_sd_vs_rate_DF_points.png'),   beta_points, width = 14, height = 7,units = "cm")
  
  
  
  
}

plot_beta_states<-function(df){
  LxL <- 200 * 200
  pFD<-df%>%
    dplyr::filter(time>600)%>%
    dplyr::mutate(Variant = substring(productivity_function_FH, 4))%>%
    dplyr::group_by(max_rate_FH,Variant,rate_DF)%>%
    
    dplyr::summarise_all(mean)%>%
    ggplot(aes(x = rate_DF, y=F/LxL, size = max_rate_FH))+
    geom_point(aes(y=F/LxL,color="Forest"))+
    geom_point(aes(y=D/LxL,color="Degraded"))+
    scale_y_continuous("Density")+
    scale_size("maximum colonization rate",range=c(0.1,3))+
    scale_colour_manual("Land type",values = c("Forest"="darkgreen","Degraded"="brown"))+
    theme_classic() +
    facet_grid(rows = vars(), cols = vars(Variant), labeller = labeller(.rows = label_both, .cols = label_both))+theme_bw()

  pH<-df%>%
    dplyr::filter(time>600)%>%
    dplyr::mutate(Variant = substring(productivity_function_FH, 4))%>%
    dplyr::group_by(max_rate_FH,Variant,rate_DF)%>%
  
    dplyr::summarise_all(mean)%>%
    ggplot(aes(x = rate_DF, size = max_rate_FH))+
  geom_point(aes(y=H/LxL,color="Human settlement"))+
    geom_point(aes(y=A/LxL,color="Agriculture"))+
    scale_y_continuous("")+
    scale_colour_manual("",values = c("Human settlement"="red","Agriculture"="yellow"))+
  scale_size(range=c(0.1,3),guide="none")+
    theme_classic() +
    facet_grid(rows = vars(), cols = vars(Variant), labeller = labeller(.rows = label_both, .cols = label_both))+theme_bw()


  
  
  
    ggsave(file.path("experiments/2020-12-02/e1-colonization-vbeta/", 'states_SS.png'),   gridExtra::grid.arrange(pH,pFD,ncol=2), width = 16, height = 10,units = "cm")
}


main()
