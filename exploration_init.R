#load packages 
library(tidyverse)
library(sf)
library(xtable)
library(stargazer)

#read in data and alter variable types 
setwd("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/speeches")
full2016 <- readRDS("full_elec_data_with_speech_indexes2016.Rdata")
full2011 <- readRDS("full_elec_data_with_speech_indexes2011.Rdata")
full2002 <- readRDS("full_elec_data_with_speech_indexes2002.Rdata")
full1997 <- readRDS("full_elec_data_with_speech_indexes1997.Rdata")
full <- rbind(full2016, full2011, full2002, full1997)
full$n_mentioned <- as.numeric(as.character(full$n_mentioned))
full$sum_mentioned <- as.numeric(as.character(full$sum_mentioned))
full$enp <- as.numeric(as.character(full$enp))
full$log_n_mentioned <- log(full$n_mentioned)
full$log_sum_mentioned <- log(full$sum_mentioned)
full$prop_speeches_local <- as.numeric(as.character(full$prop_speeches_local))


#histogram of dependent variables 
histogram <- function(dat, var){
  ggplot(data = dat, aes(x = var)) + 
    geom_histogram()
}
histogram(dat = full, var = prop_speeches_local)
ggplot(dat = full,aes(x = prop_speeches_local)) + 
  geom_histogram()

#create variables for dynastic status and whether TD serves / served in cabinet 
full <- full %>%
  mutate(dynastic = case_when(
    pre_cand == 1 ~ 1, 
    pre_local == 1 ~ 1, 
    pre_mp == 1 ~ 1,
    TRUE ~ 0),
    cabinet_in_session = case_when(
      cabappt == 1 ~ 1,
      TRUE ~ 0
    ),
    cabinet_ever = case_when(
      cabexp == 1 ~ 1, 
      cabappt == 1 ~ 1, 
      TRUE ~ 0
    ),
    junior_cabinet_in_session = case_when(
      juniorappt == 1 ~ 1,
      TRUE ~ 0
    ),
    junior_cabinet_ever = case_when(
      juniorexp == 1 ~ 1, 
      juniorappt == 1 ~ 1, 
      TRUE ~ 0
    ),
    full_cabinet_in_session = case_when(
      cabinet_in_session == 1 ~ 1, 
      junior_cabinet_in_session == 1 ~ 1, 
      TRUE ~ 0
    ), 
    full_cabinet_ever = case_when(
      cabinet_ever == 1 ~ 1,
      junior_cabinet_ever == 1 ~ 1, 
      TRUE ~ 0
    ))

dynast <- full %>% 
  filter(n_mentioned != 0) %>% 
  group_by(dynastic) %>% 
  summarize(mean_prop = mean(prop_speeches_local),
            sd_prop = sd(prop_speeches_local), 
            sd_log_prop = mean(log(prop_speeches_local)), 
            sd_log_prop = sd(log(prop_speeches_local)),
            mean_sum = mean(sum_mentioned),
            sd_sum = sd(sum_mentioned), 
            mean_log_sum = mean(log_sum_mentioned),
            sd_log_sum = sd(log_sum_mentioned), 
            mean_n = mean(n_mentioned),
            sd_n = sd(n_mentioned), 
            mean_log_n = mean(log_n_mentioned),
            sd_log_n = sd(log_n_mentioned))


###############
#within MPs, look at localism before and after appointment to cabinet 

