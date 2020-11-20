library(DBI)
library(RSQLite)
library(dplyr)
library(magrittr)
library(ggplot2)
setwd("c:/Users/Andres/Documents/GitHub/landusemodel/julia/20-11-19/")



db_conn <- dbConnect(SQLite(), 'db.sqlite')
output_1 <- tbl(db_conn, 'output') %>%  collect()
params <- tbl(db_conn, 'runs') %>%  collect()
results=inner_join(x = params, y = output_1,by="run_id")
dbDisconnect(db_conn)

setwd("c:/Users/Andres/Documents/GitHub/landusemodel/julia/20-11-16/")



db_conn <- dbConnect(SQLite(), 'db.sqlite')
output_2 <- tbl(db_conn, 'output') %>%  collect()
params <- tbl(db_conn, 'runs') %>%  collect()


results2=inner_join(x = params, y = output_2,by="run_id")
dbDisconnect(db_conn)


g1<-results%>%
  dplyr::filter(time==150)%>%
  ggplot(aes(x=factor(rate_DF),y=beta_mean,fill=productivity_function_FH))+
  geom_boxplot()+
  scale_fill_discrete(guide="none")+theme_bw()

g2<-results%>%
  dplyr::filter(time==150)%>%
  ggplot(aes(x=factor(max_rate_AD),y=beta_mean,fill=factor(productivity_function_FH)))+
  geom_boxplot()+
  scale_fill_discrete(guide="none")+theme_bw()


g3<-results%>%
  dplyr::filter(time==150)%>%
  ggplot(aes(x=factor(frac_global_FH),y=beta_mean,fill=productivity_function_FH))+
  geom_boxplot()+
  scale_fill_discrete(guide="none")+theme_bw()

g4<-results%>%
  dplyr::filter(time==150)%>%
  ggplot(aes(x=factor(min_rate_frac_AD),y=beta_mean,fill=productivity_function_FH))+
  geom_boxplot()+
  scale_fill_discrete(guide="none")+theme_bw()

gridExtra::grid.arrange(g1,g2,g3,g4,ncol=2)


g5<-results%>%
  filter(max_rate_AD==0.1 & frac_global_FH==0)%>%
  ggplot(aes(x=time,y=beta_mean,colour=productivity_function_FH,group=run_id))+
  geom_point()+geom_line()+
  scale_y_continuous("average deforestation rate")+
  facet_grid(rate_DF~max_rate_FH)+
  theme_bw()


g1<-results%>%
  dplyr::filter(time==150)%>%
  ggplot(aes(x=factor(rate_DF),y=H/(200*200),fill=productivity_function_FH))+
  geom_boxplot()+
  scale_fill_discrete(guide="none")+theme_bw()
g2<-results%>%
  dplyr::filter(time==150)%>%
  ggplot(aes(x=factor(rate_DF),y=F/(200*200),fill=productivity_function_FH))+
  geom_boxplot()+
  scale_fill_discrete(guide="none")+theme_bw()


g3<-results%>%
  dplyr::filter(time==150)%>%
  ggplot(aes(x=factor(rate_DF),y=A/(200*200),fill=productivity_function_FH))+
  geom_boxplot()+
  scale_fill_discrete(guide="none")+theme_bw()

g4<-results%>%
  dplyr::filter(time==150)%>%
  ggplot(aes(x=factor(rate_DF),y=D/(200*200),fill=productivity_function_FH))+
  geom_boxplot()+
  scale_fill_discrete(guide="none")+theme_bw()

gridExtra::grid.arrange(g1,g2,g3,g4,ncol=1)



g_H_panel<-results%>%
  filter(max_rate_AD==0.1 & frac_global_FH==0)%>%
  ggplot(aes(x=time,y=H/(200*200),colour=productivity_function_FH,group=run_id))+
  geom_point()+geom_line()+
  scale_y_continuous("Humans sites %")+
  facet_grid(rate_DF~max_rate_FH)+
  theme_bw()


g_A_panel<-results%>%
  filter(max_rate_AD==0.1 & frac_global_FH==0)%>%
  ggplot(aes(x=time,y=100 * A/(200*200),colour=productivity_function_FH,group=run_id))+
  geom_point()+geom_line()+
  scale_y_continuous("Agriculture land %")+
  facet_grid(rate_DF~max_rate_FH)+
  theme_bw()

g_F_panel<-results%>%
  filter(max_rate_AD==0.1 & frac_global_FH==0)%>%
  ggplot(aes(x=time,y=100 * F/(200*200),colour=productivity_function_FH,group=run_id))+
  geom_point()+geom_line()+
  scale_y_continuous("Forest land %")+
  facet_grid(rate_DF~max_rate_FH)+
  theme_bw()


g_D_panel<-results%>%
  filter(max_rate_AD==0.1 & frac_global_FH==0)%>%
  ggplot(aes(x=time,y=100 * D/(200*200),colour=productivity_function_FH,group=run_id))+
  geom_point()+geom_line()+
  scale_y_continuous("Degradated land %")+
  facet_grid(rate_DF~max_rate_FH)+
  theme_bw()
