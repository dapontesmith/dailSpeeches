setwd("C:/Users/dapon/Dropbox/Smith-Daponte-Smith")
#get placenames that appear multiple times 
mult <- places %>% 
  group_by(name) %>% 
  filter(n() > 1) %>% 
  arrange(name) %>% 
  select(name, location_type, everything())
write.csv(mult,"constituencies/non_unique_placenames.csv")

#get placenames that appear in multiple districts
mult_dist <- places %>% 
  group_by(name) %>% 
  filter(n_distinct(const2013) > 1) %>% 
  arrange(name) %>% 
  select(name, location_type, const2013, everything())
write.csv(mult_dist, "constituencies/multiple_district_placenames.csv")


names <- places %>% pull(name) %>% as_tibble() %>% 
  group_by(value) %>% 
  filter(!(n() >1))

uniques <- places %>% pull(name) %>% 
  as_tibble() %>% 
  distinct(value)

twice <- places %>% pull(name) %>% as_tibble() %>% 
  group_by(value) %>% 
  filter(n() > 1)

#exclude places if they have multiple associated constituencies; 



test2017 <- places %>% group_by(name) %>% 
  filter(n_distinct(const2017) == 1) %>% 
  distinct(name, .keep_all = TRUE)

test2013 <- places %>% group_by(name) %>% 
  filter(n_distinct(const2013) == 1) %>% 
  distinct(name, .keep_all = TRUE)
test2007 <- places %>% group_by(name) %>% 
  filter(n_distinct(const2007) == 1) %>% 
  distinct(name, .keep_all = TRUE)
test1998 <- places %>% group_by(name) %>% 
  filter(n_distinct(const98) == 1) %>% 
  distinct(name, .keep_all = TRUE)




speeches_data <- speeches1997 %>% sample_n(., size = 10000)

library(electoral)
sum_district_mentions_func <- function(speeches_data, places_data, constit_year,
                                       dail_start_date, dail_end_date){
  #param speeches_data -- data frame of speeches, corresponding to a given general election
  #param places_data -- data frame of places names, with matching constituencies, defined outside function
  #param constit_year -- year of constituencies we care about. This should match the general election of speeches_data 
  #get unique speakers
  speakers <- unique(speeches_data$name_clean)
  #define matrix in which each row is a place and each column is a speaker
  holder <- list()
  #loop to calculate how many times each speaker mentions each place 
  for(j in 1:length(speakers)){
    #get speakre constit 
    constituency <- unique(speeches_data$district[speeches_data$name_clean == speakers[j]])
    #get places in the constit
    places_in_constit <- unique(places_data$name[constit_year == constituency])
    print(j)
    speeches_by_speaker <- speeches_data$text[speeches_data$name_clean == speakers[j]]
    holder[[j]] <- matrix(nrow = length(places_in_constit), ncol = 1)
    for(i in 1:length(places_in_constit)){
      #sum the number of times a certain speaker mentions a certain place
      holder[[j]][i,] <- sum(str_count(speeches_by_speaker, places_in_constit[i]))
    }
    rownames(holder[[j]]) <- places_in_constit
    colnames(holder[[j]]) <- speakers[j]
  }
  
  #now sum the number of in-district mentions 
  district_mentions_holder <- data.frame(matrix(NA, nrow = length(holder), ncol = 3))
  district_mentions_holder$name_clean <- NULL
  district_mentions_holder$sum_mentioned <- NULL
  district_mentions_holder$enp <- NULL
  district_mentions_holder$n_mentioned <- NULL
  
  for(i in 1:length(holder)){
    #assign speaker name the relevant column name in holder 
    district_mentions_holder$name_clean[i] <- colnames(holder[[i]])
    #sum number of total metions 
    district_mentions_holder$sum_mentioned[i] <- sum(holder[[i]], na.rm = T)
    #get ENP of mentions 
    district_mentions_holder$enp[i] <- 1/sum((holder[[i]]/sum(holder[[i]], na.rm = T))^2, na.rm = T)
    #sum number of places mentioned 
    district_mentions_holder$n_mentioned[i] <- sum(holder[[i]] > 0, na.rm = T)
  }
  #get only relevant columns 
  out <- district_mentions_holder %>% 
    dplyr::select(name_clean, sum_mentioned, enp, n_mentioned)
  
  elecdatafull <- finaljoin %>% 
    filter(name_clean != "") %>%
    dplyr::select(-dail, -name, -text, -subject, -date) %>%
    mutate(electiondate_clean = as.Date(as.character(electiondate), "%m/%d/%y")) %>% 
    filter(electiondate_clean >= as.Date(dail_start_date) & electiondate_clean < as.Date(dail_end_date)) %>% 
    distinct()
  
  #join electoral data with enp data 
  full_out <- left_join(elecdatafull, out, by = "name_clean")
  
  return(full_out)
  
}

mentions1997 <- sum_district_mentions_func(speeches_data = speeches1997, 
                      places_data = places, constit_year = places$const95,
                      dail_start_date = "1997-06-06", dail_end_date = "2002-05-17")

                                          
mentions2016 <-sum_district_mentions_func(speeches_data = speeches2016, 
                                     places_data = places, constit_year = places$const2013,
                                     dail_start_date = "2016-02-26", dail_end_date = "2020-02-08")

mentions2011 <- sum_district_mentions_func(speeches_data = speeches2011, 
                                           places_data = places, constit_year = places$const2007,
                                           dail_start_date = "2011-02-25", dail_end_date = "2016-02-26")

mentions2002 <- sum_district_mentions_func(speeches_data = speeches2002, 
                                           places_data = places, constit_year = places$const98,
                                           dail_start_date = "2002-05-17",dail_end_date = "2007-05-24")



#get electoral data from next election as well 

elecdata1997_next <- finaljoin %>% 
  filter(name_clean != "") %>%
  dplyr::select(-dail, -name, -text, -subject, -date) %>%
  mutate(electiondate_clean = as.Date(as.character(electiondate), "%m/%d/%y")) %>% 
  filter(electiondate_clean >= as.Date("2002-05-17") & electiondate_clean < as.Date("2007-05-24")) %>% 
  distinct() %>% 
  dplyr::select(c(voteshare, quotashare, result, name_clean)) %>% 
  rename(voteshare_next = voteshare, 
         quotashare_next = quotashare, 
         result_next = result)

full1997_next_distinct <- left_join(mentions1997, elecdata1997_next, by = "name_clean" )
saveRDS(full1997_next_distinct, "speeches/elec_data_1997_with_hh_prop_distinct2.Rdata")


elecdata2002_next <- finaljoin %>% 
  filter(name_clean != "") %>%
  dplyr::select(-dail, -name, -text, -subject, -date) %>%
  mutate(electiondate_clean = as.Date(as.character(electiondate), "%m/%d/%y")) %>% 
  filter(electiondate_clean >= as.Date("2007-05-24") & electiondate_clean < as.Date("2011-02-25")) %>% 
  distinct() %>% 
  dplyr::select(c(voteshare, quotashare, result, name_clean)) %>% 
  rename(voteshare_next = voteshare, 
         quotashare_next = quotashare, 
         result_next = result)

full2002_next_distinct <- left_join(mentions2002, elecdata2002_next, by = "name_clean" )
saveRDS(full2002_next_distinct, "speeches/elec_data_2002_with_hh_prop_distinct2.Rdata")



elecdata2011_next <- finaljoin %>% 
  filter(name_clean != "") %>%
  dplyr::select(-dail, -name, -text, -subject, -date) %>%
  mutate(electiondate_clean = as.Date(as.character(electiondate), "%m/%d/%y")) %>% 
  filter(electiondate_clean >= as.Date("2016-02-26") & electiondate_clean < as.Date("2020-02-08")) %>% 
  distinct() %>% 
  dplyr::select(c(voteshare, quotashare, result, name_clean)) %>% 
  rename(voteshare_next = voteshare, 
         quotashare_next = quotashare, 
         result_next = result)

full2011_next_distinct <- left_join(mentions2011, elecdata2011_next, by = "name_clean" )
saveRDS(full2011_next_distinct, "speeches/elec_data_2011_with_hh_prop_distinct2.Rdata")



elecdata2016_next <- finaljoin %>% 
  filter(name_clean != "") %>%
  dplyr::select(-dail, -name, -text, -subject, -date) %>%
  mutate(electiondate_clean = as.Date(as.character(electiondate), "%m/%d/%y")) %>% 
  filter(electiondate_clean >=  as.Date("2020-02-08")) %>% 
  distinct() %>% 
  dplyr::select(c(voteshare, quotashare, result, name_clean)) %>% 
  rename(voteshare_next = voteshare, 
         quotashare_next = quotashare, 
         result_next = result)

full2016_next_distinct <- left_join(mentions2016, elecdata2016_next, by = "name_clean" )
saveRDS(full2016_next_distinct, "speeches/elec_data_2016_with_hh_prop_distinct2.Rdata")










