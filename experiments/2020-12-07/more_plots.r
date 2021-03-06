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

  output <- load_table_cb('output')
  runs <- load_table_cb('runs')
  output_runs_e1_cb <- output %>% left_join(runs, 'run_id')
  
    
  
  output <- load_table_e3('output')
  runs <- load_table_e3('runs')
  output_runs_e3 <- output %>% left_join(runs, 'run_id')
  
  LxL=200*200
  
  output_runs %>%
    dplyr::mutate(Variant = substring(productivity_function_FH, 4))%>%
    dplyr::mutate(`forest regeneration` = 1/rate_DF)%>%
    dplyr::filter(max_rate_FH ==40) %>%
    dplyr::select(time, max_rate_FH, `forest regeneration`, H, A, F,Variant) %>%
    dplyr::mutate(H = H / LxL, A = A / LxL, F = F / LxL) %>%
    dplyr::mutate(D = 1 - H - A - F) %>%
    gather(`H`, `A`, `F`, `D`, key = 'state', value = 'density')->subdf
  
  plot_timeseries(subdf)
  
  
  output_runs %>%
    dplyr::mutate(Variant = substring(productivity_function_FH, 4))%>%
    dplyr::mutate(`forest regeneration` = 1/rate_DF)%>%
    dplyr::filter(max_rate_FH ==40)->subdf2
  
  plot_beta(subdf2)
  
  
  output_runs_e3 %>%
    dplyr::mutate(Variant = substring(productivity_function_FH, 4))%>%
    dplyr::mutate(`forest regeneration` = 1/rate_DF)%>%
    dplyr::filter(frac_global_FH ==0, time>600)%>%
    dplyr::mutate(H = H / LxL, A = A / LxL, F = F / LxL,D=D/ LxL) %>%
    dplyr::select(`forest regeneration`, H_lifetime_avg, A_lifetime_avg,F_lifetime_avg, D_lifetime_avg,H,A,F,D,Variant)%>%  
    dplyr::group_by(`forest regeneration`,Variant)%>%
    dplyr::summarise_all(mean)->subdf3
  
  plot_lifespan(subdf3)
  
  output_runs_e1_cb%>%
    dplyr::filter(time==1200,max_rate_FH==32,rate_DF==0.02)%>%
    dplyr::mutate(`forest regeneration` = 1/rate_DF)%>%
    dplyr::mutate(Variant = substring(productivity_function_FH, 4))%>%
    dplyr::select(time,`forest regeneration`,H,A,F,D,Variant, beta_init_mean)%>%  
    dplyr::group_by(Variant,`forest regeneration`, beta_init_mean)%>%
    dplyr::summarise(H=mean(H)/ LxL,
                         A=mean(A)/ LxL,
                         F=mean(F)/ LxL,
                         D=mean(D)/ LxL
                         )->df_e1_cb
  
  
  output_runs%>%
    dplyr::filter(time>600,max_rate_FH==32,rate_DF==0.02)%>%
    dplyr::mutate(`forest regeneration` = 1/rate_DF)%>%
    dplyr::mutate(Variant = substring(productivity_function_FH, 4))%>%
    dplyr::select(time,`forest regeneration`,H,A,F,D,Variant, beta_mean,beta_025,beta_750)%>%  
    dplyr::group_by(Variant,`forest regeneration`)%>%
    dplyr::summarise(beta_mean=mean(beta_mean, na.rm=TRUE),
                     beta_025=mean(beta_025, na.rm=TRUE),
                     beta_750=mean(beta_750, na.rm=TRUE),
                     H=mean(H)/ LxL,
                     A=mean(A)/ LxL,
                     F=mean(F)/ LxL,
                     D=mean(D)/ LxL
    )->df_e1_vb
  
  
  plot_betastate_v_vs_c_beta(df_v =df_e1_vb,df_c = df_e1_cb)
  
  
}

load_table <- function(tbl_name) {
  db <- dbConnect(SQLite(), 'experiments/2020-12-07/e1-colonization-vbeta/db.sqlite')
  tbl <- dbGetQuery(db, str_glue('SELECT * FROM {tbl_name}'))
  dbDisconnect(db)
  
  tbl
}

load_table_cb <- function(tbl_name) {
  db <- dbConnect(SQLite(), 'experiments/2020-12-07/e1-colonization-cbeta/db.sqlite')
  tbl <- dbGetQuery(db, str_glue('SELECT * FROM {tbl_name}'))
  dbDisconnect(db)
  
  tbl
}



load_table_e3 <- function(tbl_name) {
  db <- dbConnect(SQLite(), 'experiments/2020-12-07/e3-global-vbeta/db.sqlite')
  tbl <- dbGetQuery(db, str_glue('SELECT * FROM {tbl_name}'))
  dbDisconnect(db)
  
  tbl
}



plot_timeseries <- function(subdf) {
  p <- ggplot(subdf, aes(x = time, y = density, color = state)) +
    geom_line(size=1.2) +
    scale_color_manual(values = c("yellow","brown","darkgreen","blue"),guide="none")+
    facet_grid(rows = vars(Variant), cols = vars(`forest regeneration`), labeller = labeller(.rows = label_both, .cols = label_both))+
  theme_minimal(base_size = 10)
  ggsave(file.path('experiments/2020-12-07/e1_timeseries_states_vb.png'), p, width = 8.5, height = 4,units = "in")
}


plot_beta <- function(subdf2) {
  p <- subdf2%>% 
    ggplot(aes(x = time)) +
    geom_ribbon(aes(ymin = beta_025, ymax = beta_975), color = 'lightgray', fill = 'lightgray') +
    geom_line(aes(y = beta_500), color = 'darkgray') +
    geom_line(aes(y = beta_mean), color = 'red') +
    scale_y_continuous("Deforestation rate")+
    facet_grid(rows = vars(Variant), cols = vars(`forest regeneration`), labeller = labeller(.rows = label_both, .cols = label_both))+
    theme_minimal(base_size = 10)
  ggsave(file.path('experiments/2020-12-07/e1_beta_ts_vb.png'), p, width = 8.5, height = 4,units = "in")
}


plot_lifespan<-function(subdf3){

  ggsave(file.path('experiments/2020-12-07/e3_lifetime_land.png'), 
  
gridExtra::grid.arrange(  
  subdf3%>%
    ggplot(aes(x=`forest regeneration`,y=H_lifetime_avg,color=Variant))+geom_point()+geom_line()+scale_y_continuous("years",limits = c(0,35))+ggtitle("Human settlements")+scale_x_continuous("",breaks = c(5,10,25,50,100))+scale_color_manual(values=c('#999999','#E69F00'))+theme_classic(base_size = 10)
,  
  
  subdf3%>%
    ggplot(aes(x=`forest regeneration`,y=A_lifetime_avg,color=Variant))+geom_point()+geom_line()+scale_y_continuous("",limits = c(0,8))+ggtitle("Agriculture")+scale_x_continuous("",breaks = c(5,10,25,50,100))+scale_color_manual(values=c('#999999','#E69F00'))+theme_classic(base_size = 10)
,  
  subdf3%>%
    ggplot(aes(x=`forest regeneration`,y=F_lifetime_avg,color=Variant))+geom_point()+geom_line()+scale_y_continuous("years",limits = c(0,130))+ggtitle("Forest")+scale_x_continuous("Forest regeneration [year]",breaks = c(5,10,25,50,100))+scale_color_manual(values=c('#999999','#E69F00'))+theme_classic(base_size = 10)
,  

  subdf3%>%
    ggplot(aes(x=`forest regeneration`,y=D_lifetime_avg,color=Variant))+geom_point()+geom_line()+scale_y_continuous("",limits = c(0,100))+ggtitle("Degraded")  +scale_x_continuous("Forest regeneration [year]",breaks = c(5,10,25,50,100)) +scale_color_manual(values=c('#999999','#E69F00'))+theme_classic(base_size = 10)
,
ncol=2
),
width = 8.5, height = 8.5,units = "in")  

  
#############################
  ggsave(file.path('experiments/2020-12-07/e3_land_frac.png'), 
         
    gridExtra::grid.arrange(  
    subdf3%>%
      ggplot(aes(x=`forest regeneration`,y=H,color=Variant))+geom_point()+geom_line()+scale_y_continuous("",limits = c(0,0.5))+ggtitle("Human settlements")+scale_color_manual(values=c('#999999','#E69F00'))+theme_classic(base_size = 10)
    ,  
    
    subdf3%>%
      ggplot(aes(x=`forest regeneration`,y=A,color=Variant))+geom_point()+geom_line()+scale_y_continuous("",limits = c(0,0.5))+ggtitle("Agriculture")+scale_color_manual(values=c('#999999','#E69F00'))+theme_classic(base_size = 10)
    ,  
    subdf3%>%
      ggplot(aes(x=`forest regeneration`,y=F,color=Variant))+geom_point()+geom_line()+scale_y_continuous("",limits = c(0,1))+ggtitle("Forest")+scale_color_manual(values=c('#999999','#E69F00'))+theme_classic(base_size = 10)
    ,  
    
    subdf3%>%
      ggplot(aes(x=`forest regeneration`,y=D,color=Variant))+geom_point()+geom_line()+scale_y_continuous("",limits = c(0,1))+ggtitle("Degraded")   +scale_color_manual(values=c('#999999','#E69F00'))+theme_classic(base_size = 10)
    ,
    ncol=2
  ),
  width = 8.5, height = 8.5,units = "in")  
  
  
  
  
}

###########################################################################



plot_betastate_v_vs_c_beta<-function(df_v, df_c){

  p_H <- ggplot()+
    geom_line(data =df_c, aes(x = beta_init_mean , y = H,color= Variant ,group=Variant))+
    geom_point(data =df_c, aes(x = beta_init_mean , y = H,color= Variant ,group=Variant))+
    geom_point(data = df_v,aes(x=beta_mean,y=H,color= Variant),shape=19,size=4)+
    geom_errorbarh(data = df_v,aes(x=beta_mean,y=H,xmax = beta_750, xmin =0.000001+beta_025,color= Variant))+
    scale_color_manual(values=c('#999999','#E69F00'))+
    scale_x_continuous("")+
    theme_classic()#+scale_x_log10("")
  p_H
  
  
  
  p_F<- ggplot()+
    geom_line(data =df_c, aes(x = beta_init_mean , y = F,color= Variant ,group=Variant))+
    geom_point(data =df_c, aes(x = beta_init_mean , y = F,color= Variant ,group=Variant))+
    geom_point(data = df_v,aes(x=beta_mean,y=F,color= Variant),shape=19,size=4)+
    geom_errorbarh(data = df_v,aes(x=beta_mean,y=F,xmax = beta_750, xmin =0.000001+beta_025,color= Variant))+
    scale_color_manual(values=c('#999999','#E69F00'))+
    scale_x_continuous("")+
    theme_classic()#+scale_x_log10("")
  p_F
  
  p_A<- ggplot()+
    geom_line(data =df_c, aes(x = beta_init_mean , y = A,color= Variant ,group=Variant))+
    geom_point(data =df_c, aes(x = beta_init_mean , y = A,color= Variant ,group=Variant))+
    geom_point(data = df_v,aes(x=beta_mean,y=A,color= Variant),shape=19,size=4)+
    geom_errorbarh(data = df_v,aes(x=beta_mean,y=A,xmax = beta_750, xmin =0.000001+beta_025,color= Variant))+
    scale_color_manual(values=c('#999999','#E69F00'))+
    scale_x_continuous("Deforestation rate")+
    theme_classic()#+scale_x_log10("Deforestation rate")
  p_A
  
  p_D<- ggplot()+
    geom_line(data =df_c, aes(x = beta_init_mean , y = D,color= Variant ,group=Variant))+
    geom_point(data =df_c, aes(x = beta_init_mean , y = D,color= Variant ,group=Variant))+
    geom_point(data = df_v,aes(x=beta_mean,y=D,color= Variant),shape=19,size=4)+
    geom_errorbarh(data = df_v,aes(x=beta_mean,y=D,xmax = beta_750, xmin =0.000001+beta_025,color= Variant))+
    scale_color_manual(values=c('#999999','#E69F00'))+
    scale_x_continuous("Deforestation rate")+
    theme_classic()#+scale_x_log10("Deforestation rate")
  p_D
  
  ggsave(file.path('experiments/2020-12-07/e1_cb_vb_states.png'), 
  gridExtra::grid.arrange(p_H,p_A,p_F,p_D),
  width = 8.5, height = 8.5,units = "in")
  
  
}

main() 
