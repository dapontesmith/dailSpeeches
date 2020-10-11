#load packages 
library(tidyverse)
library(sf)
library(xtable)
library(stargazer)

#read in data and alter variable types 
setwd("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/speeches")
full2016 <- readRDS("elec_data_2016_with_hh_prop_distinct2.Rdata")
full2011 <- readRDS("elec_data_2011_with_hh_prop_distinct2.Rdata")
full2002 <- readRDS("elec_data_2002_with_hh_prop_distinct2.Rdata")
full1997 <- readRDS("elec_data_1997_with_hh_prop_distinct2.Rdata")
full <- rbind(full2016, full2011, full2002, full1997)
full$n_mentioned <- as.numeric(as.character(full$n_mentioned))
full$sum_mentioned <- as.numeric(as.character(full$sum_mentioned))
full$enp <- as.numeric(as.character(full$enp))
full$log_n_mentioned <- log(full$n_mentioned)
full$log_sum_mentioned <- log(full$sum_mentioned)




#compare place-name mentions of dynastic politicans vs. non-dynastic 
full <- full %>%
  mutate(dynastic = ifelse(pre_cand == 1 | pre_local == 1 | pre_mp == 1, 1, 0))
t.test(sum_mentioned ~ dynastic, data = full)
  


#make variable for whether TD serves in cabinet 