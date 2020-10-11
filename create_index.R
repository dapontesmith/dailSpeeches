setwd("C:/Users/dapon/Dropbox/Smith-Daponte-Smith")
library(tidyverse)
#libraries for parallelizing 
library(parallel)
library(foreach)
library(doParallel)
library(electoral) #for ENP function we'll use to make HH index

#RUN "FINAL_CLEANING.R BEFORE RUNNING THIS FILE - 
#"FINAL_CLEANING.R defines the data we can use 
#
finaljoin <- readRDS("speeches/speeches_1997_2019_FINAL.Rdata") 
places_full <- readRDS("constituencies/constituencies_placenames_matched.Rdata")
#define types of locations
location_types <- c("town","civil parish","electoral district","population centre",
                    "administrative county","city","county","sub-townland","island or archipelago",
                    "barony","canal","port","junction, interchange","field","quay, pier, wharf",
                    "house","river","wood","man-made feature", "monument",
                    "mountain or mountain range", "locality","valley","feature")
#make county names 
places_full$name <- ifelse(places_full$location_type == "county", 
                           paste("County", places_full$name), places_full$name)

#filter on location types 
places <- places_full %>% filter(location_type %in% location_types)

#get places with only one constituency, and get distinct names 
places2017 <- places %>% group_by(name) %>% 
  filter(n_distinct(const2017) == 1) %>% 
  distinct(name, .keep_all = TRUE)

places2013 <- places %>% group_by(name) %>% 
  filter(n_distinct(const2013) == 1) %>% 
  distinct(name, .keep_all = TRUE)
places2007 <- places %>% group_by(name) %>% 
  filter(n_distinct(const2007) == 1) %>% 
  distinct(name, .keep_all = TRUE)
places1998 <- places %>% group_by(name) %>% 
  filter(n_distinct(const98) == 1) %>% 
  distinct(name, .keep_all = TRUE)
places1995 <- places %>% group_by(name) %>% 
  filter(n_distinct(const95) == 1) %>% 
  distinct(name, .keep_all = TRUE)
##################s
#some place-names occur more than once 
#for instance, Leitrim occurs as a barony, a civil parish, a town, a county, and an electoral district
#so we take the distinct names 
places <- places %>% distinct(name)

#add some counties that weren't in the data
counties_not_in_data <- c("County Laois", "County Clare", "County Cork",
                          "County Dublin", "County Kerry", "County Kilkenny",
                          "County Limerick","County Mayo","County Meath")
#places <- append(places, counties_not_in_data)

speeches1997 <- finaljoin %>% filter(date > as.Date("1997-06-06") & date <= as.Date("2002-05-17"))
speeches2002 <- finaljoin %>% filter(date > as.Date("2002-05-17") & date <= as.Date("2007-05-24"))
speeches2007 <- finaljoin %>% filter(date > as.Date("2007-05-24") & date <= as.Date("2011-02-25"))
speeches2011 <- finaljoin %>% filter(date > as.Date("2011-02-25") & date <= as.Date("2016-02-26"))
speeches2016 <- finaljoin %>% filter(date > as.Date("2016-02-26") & date <= as.Date("2020-02-08"))


####################################################################################################
###################################################################################################
#define functions

#function to count mentions of places and whether places are in the district
mentions_func <- function(speeches_data, places_data, constit_year){
    #param speeches_data -- data frame of speeches, corresponding to a given general election
    #param places_data -- data frame of places names, with matching constituencies, defined outside function
    #param constit_year -- year of constituencies we care about. This should match the general election of speeches_data 
    #dail_start_date -- character, telling us earliest start date for dail data (date of general election at time t)
    #dail_end_date -- character, telling us end date for dail data (date of general election at time t+1)
    #get unique speakers
    speakers <- unique(speeches_data$name_clean)
    #define matrix in which each row is a place and each column is a speaker
    holder <- matrix(nrow = nrow(places_data), ncol = length(speakers))
    #loop to calculate how many times each speaker mentions each place 
    for(j in 1:length(speakers)){
      print(j)
      for(i in 1:nrow(places_data)){
        #sum the number of times a certain speaker mentions a certain place
        holder[i,j] <- sum(str_count(speeches_data$text[speeches_data$name_clean == speakers[j]], places_data$name[i]))
      }
    }
    #assign places to row names and speakers to column names, matching structure of data 
    rownames(holder) <- places_data$name
    colnames(holder) <- speakers
    
    #define holder matrix of same dimensions as the holder matrix above 
    places_district_holder <- matrix(nrow = nrow(places_data), ncol = length(speakers))
    
    #this matrix is of 1s and 0s, telling us whether a place is in a speaker's district 
    for(j in 1:ncol(places_district_holder)){
      speaker_district <- unique(speeches_data$district[speeches_data$name_clean == colnames(holder)[j]])
      print(j)
      for(i in 1:nrow(places_district_holder)){
        #get speaker district 
        #get place district
        places_district <- unique(constit_year[places$name == rownames(holder)[i]])
        #some places having NA districts or NA speakers, so we skip them 
        #this is the case for senators who have snuck into the data 
        if(is.na(places_district) | is.na(speaker_district)){
          next
        } else if(places_district == speaker_district){
          places_district_holder[i,j] <- 1
        } else {
          places_district_holder[i,j] <- 0
        }
      }
    }
    
    rownames(places_district_holder) <- places_data$name
    colnames(places_district_holder) <- speakers
    
    #multiply matrices element-wise, then sum columns of result to get count of places mentioned in the district
    #to get total mentions, sum columns of holder 
    total_mentions <- colSums(holder)
    
    #multiply matrices element-wise to get matrix only of within-district mention counts
    mentions_in_district <- holder * places_district_holder
    
    #get total number of mentions in district
    total_mentions_in_district <- colSums(mentions_in_district)
    
    #get within-district proportion of mentions
    within_district_proportion_mentions <- mentions_in_district / total_mentions_in_district
    
    #return holder and places_district_holder
    return(list(holder, places_district_holder))
}

#function to count proportion of place-mentions are in the district
prop_mentions_in_district_func <- function(mentions_matrix, in_district_matrix, 
                                           dail_start_date, dail_end_date){
  #param mentions_matrix = first element of output list of mentions_func
  #param in_district_matrix = second element of output list of mentions_func
  #param dail_start_date = character, defining earliest date of speeches ofi nterest 
  #param dail_end_date = character, defining latest date of speeches of interest (typically next general election)
  
  #get total number of placename mentions
  total_mentions <- colSums(mentions_matrix, na.rm = TRUE)
  
  #matrix only of placename mentions in the district
  mentions_in_district <- mentions_matrix * in_district_matrix
  
  #total placename mentions in district
  total_mentions_in_district <- colSums(mentions_in_district, na.rm = TRUE)
  
  #divide the two vectors to get the proportion of mentions that are in the district. 
  prop_mentions_in_district <- total_mentions_in_district / total_mentions
  
  propmentions_df <- as.data.frame(matrix(nrow = length(names(prop_mentions_in_district)), ncol = 2))
  propmentions_df$prop <- prop_mentions_in_district
  propmentions_df$name_clean <- names(prop_mentions_in_district)
  
  
  #get electoral data corresponding to general election of interest 
  elecdatafull <- finaljoin %>% 
    filter(name_clean != "") %>%
    dplyr::select(-dail, -name, -text, -subject, -date) %>%
    mutate(electiondate_clean = as.Date(as.character(electiondate), "%m/%d/%y")) %>% 
    filter(electiondate_clean >= as.Date(dail_start_date) & electiondate_clean < as.Date(dail_end_date)) %>% 
    distinct()
  
  #join with the proportion data frame
  full_out <- left_join(elecdatafull, propmentions_df, by = "name_clean") %>% 
    select(-V1, -V2) 
  
  return(full_out)
  
  
}
#function to create HH index of within-district placename mentions
hh_index_func <- function(mentions_matrix, in_district_matrix,
                          dail_start_date, dail_end_date){
  #param mentions_matrix - first element of output list from mentions_func
  #param in_district_matrix - second element of output from mentions_func
  #param dail_start_date - character, date of corresponding general election
  #param dail_start_date - character, date of general election at t+1 
  
  #get matrix only of within-district mentions 
  mentions_in_district <- mentions_matrix * in_district_matrix
  #get total number of mentions in the district
  total_mentions_in_district <- colSums(mentions_matrix, na.rm = TRUE)
  
  #define enp_out data frame - colnames ensures speaker names are consistent 
  enp_out <- data.frame(name_clean = colnames(mentions_in_district), 
                        hh_index = rep(NA, length(colnames(mentions_in_district))))
  
  #loop over speakers
  for(j in 1:ncol(mentions_in_district)){
    #define holder matrix
    prop_holder <- NULL
    #loop over indices of mentioned places
    for(i in which(mentions_in_district[,j] > 0)){
      #proportion of mentions represented by element i 
      prop <- mentions_in_district[i,j] / total_mentions_in_district[j]
      #append to prop_holder 
      prop_holder <- append(prop_holder, prop)
    }
    #in the case that someone has no mentions at all, they'll be NaN - assign NA to these people 
    if(is.null(prop_holder) == TRUE){
      enp_out$hh_index[j] <- NA
      #otherwise, run enp function on prop_holder vector
    } else{
      enp_out$hh_index[j] <- enp(votes = prop_holder)
    }
  }
  
  #get electoral data from corresponding general election
  elecdatafull <- finaljoin %>% 
    filter(name_clean != "") %>%
    dplyr::select(-dail, -name, -text, -subject, -date) %>%
    mutate(electiondate_clean = as.Date(as.character(electiondate), "%m/%d/%y")) %>% 
    filter(electiondate_clean >= as.Date(dail_start_date) & electiondate_clean < as.Date(dail_end_date)) %>% 
    distinct()
  
  #join electoral data with enp data 
  full_out <- left_join(elecdatafull, enp_out, by = "name_clean")
  
  return(full_out)
  
}

#################################################################
#####RUN FUNCTIONS FOR 2002 SPEECHES ##################
mentions2002 <- mentions_func(speeches_data = speeches2002, 
                              places_data = places1998, 
                              constit_year = places1998$const98)
mentions2002_distinct <- mentions2002

prop_mentions2002_distinct <- prop_mentions_in_district_func(mentions_matrix = mentions2002_distinct[[1]], 
                                                    in_district_matrix = mentions2002_distinct[[2]],
                                                    dail_start_date = "2002-05-17", dail_end_date = "2007-05-24")

hh_index2002_distinct <- hh_index_func(mentions_matrix = mentions2002_distinct[[1]], 
                              in_district_matrix = mentions2002_distinct[[2]],
                              dail_start_date = "2002-05-17", dail_end_date = "2007-05-24")
prop_mentions <- as.data.frame(cbind(prop_mentions2002_distinct$name_clean, 
                                     prop_mentions2002_distinct$prop))
colnames(prop_mentions) <- c("name_clean","prop")
full2002_distinct <- left_join(hh_index2002_distinct, prop_mentions, by = "name_clean")
saveRDS(full2002_distinct, "speeches/elec_data_2002_with_hh_prop_distinct.Rdata")

######################################
#run for 2016 speeches
mentions2016 <- mentions_func(speeches_data = speeches2016, 
                              places_data = places2013, 
                              constit_year = places2013$const2013)
mentions2016_distinct <- mentions2016

prop_mentions2016_distinct <- prop_mentions_in_district_func(mentions_matrix = mentions2016_distinct[[1]], 
                                                    in_district_matrix = mentions2016_distinct[[2]],
                                                    dail_start_date = "2016-02-26", dail_end_date = "2020-02-28")


hh_index2016_distinct <- hh_index_func(mentions_matrix = mentions2016_distinct[[1]], 
                              in_district_matrix = mentions2016_distinct[[2]],
                              dail_start_date = "2016-02-26", dail_end_date = "2020-02-08")

prop_mentions <- as.data.frame(cbind(prop_mentions2016_distinct$name_clean, 
                                     prop_mentions2016_distinct$prop))
colnames(prop_mentions) <- c("name_clean","prop")
full2016_distinct <- left_join(hh_index2016_distinct, prop_mentions, by = "name_clean")
saveRDS(full2016_distinct, "speeches/elec_data_2016_with_hh_prop_distinct.Rdata")

#########################################
#run for 2011 speeches
mentions2011 <- mentions_func(speeches_data = speeches2011, 
                              places_data = places2007, 
                              constit_year = places2007$const2007)
mentions2011_distinct <- mentions2011

prop_mentions2011_distinct <- prop_mentions_in_district_func(mentions_matrix = mentions2011_distinct[[1]], 
                                                    in_district_matrix = mentions2011_distinct[[2]],
                                                    dail_start_date = "2011-02-25", dail_end_date = "2016-02-26")

hh_index2011_distinct <- hh_index_func(mentions_matrix = mentions2011_distinct[[1]], 
                              in_district_matrix = mentions2011_distinct[[2]],
                              dail_start_date = "2011-02-25", dail_end_date = "2016-02-26")

prop_mentions <- as.data.frame(cbind(prop_mentions2011_distinct$name_clean,
                                     prop_mentions2011_distinct$prop))
colnames(prop_mentions) <- c("name_clean","prop")
full2011_distinct <- left_join(hh_index2011_distinct, prop_mentions, by = "name_clean")
saveRDS(full2011_distinct, "speeches/elec_data_2011_with_hh_prop_distinct.Rdata")


#these boh work! 
############################################################################
##run for 1997 speeches 
mentions1997 <- mentions_func(speeches_data = speeches1997, 
                              places_data = places1995, 
                              constit_year = places1995$const95)
mentions1997_distinct <- mentions1997

prop_mentions1997_distinct <- prop_mentions_in_district_func(mentions_matrix = mentions1997_distinct[[1]], 
                                                    in_district_matrix = mentions1997_distinct[[2]],
                                                    dail_start_date = "1997-06-06", dail_end_date = "2002-05-17")

hh_index1997_distinct <- hh_index_func(mentions_matrix = mentions1997_distinct[[1]], 
                              in_district_matrix = mentions1997_distinct[[2]],
                              dail_start_date = "1997-02-25", dail_end_date = "2002-05-17")

prop_mentions <- as.data.frame(cbind(prop_mentions1997_distinct$name_clean, prop_mentions1997_distinct$prop))
colnames(prop_mentions) <- c("name_clean","prop")
full1997_distinct <- left_join(hh_index1997_distinct, prop_mentions, by = "name_clean")
saveRDS(full1997_distinct, "speeches/elec_data_1997_with_hh_prop_distinct.Rdata")




######################################################################################################
##########
#try to link data to the *next* election 

elecdata1997_next <- finaljoin %>% 
  filter(name_clean != "") %>%
  dplyr::select(-dail, -name, -text, -subject, -date) %>%
  mutate(electiondate_clean = as.Date(as.character(electiondate), "%m/%d/%y")) %>% 
  filter(electiondate_clean >= as.Date("2002-05-17") & electiondate_clean < as.Date("2007-05-24")) %>% 
  distinct() %>% 
  select(c(voteshare, quotashare, result, name_clean)) %>% 
  rename(voteshare_next = voteshare, 
         quotashare_next = quotashare, 
         result_next = result)

full1997_next_distinct <- left_join(full1997_distinct, elecdata1997_next, by = "name_clean" )
saveRDS(full1997_next_distinct, "speeches/elec_data_1997_with_hh_prop_distinct.Rdata")


elecdata2002_next <- finaljoin %>% 
  filter(name_clean != "") %>%
  dplyr::select(-dail, -name, -text, -subject, -date) %>%
  mutate(electiondate_clean = as.Date(as.character(electiondate), "%m/%d/%y")) %>% 
  filter(electiondate_clean >= as.Date("2007-05-24") & electiondate_clean < as.Date("2011-02-25")) %>% 
  distinct() %>% 
  select(c(voteshare, quotashare, result, name_clean)) %>% 
  rename(voteshare_next = voteshare, 
         quotashare_next = quotashare, 
         result_next = result)

full2002_next_distinct <- left_join(full2002_distinct, elecdata2002_next, by = "name_clean" )
saveRDS(full2002_next_distinct, "speeches/elec_data_2002_with_hh_prop_distinct.Rdata")



elecdata2011_next <- finaljoin %>% 
  filter(name_clean != "") %>%
  dplyr::select(-dail, -name, -text, -subject, -date) %>%
  mutate(electiondate_clean = as.Date(as.character(electiondate), "%m/%d/%y")) %>% 
  filter(electiondate_clean >= as.Date("2016-02-26") & electiondate_clean < as.Date("2020-02-08")) %>% 
  distinct() %>% 
  select(c(voteshare, quotashare, result, name_clean)) %>% 
  rename(voteshare_next = voteshare, 
         quotashare_next = quotashare, 
         result_next = result)

full2011_next_distinct <- left_join(full2011_distinct, elecdata2011_next, by = "name_clean" )
saveRDS(full2011_next_distinct, "speeches/elec_data_2011_with_hh_prop_distinct.Rdata")



elecdata2016_next <- finaljoin %>% 
  filter(name_clean != "") %>%
  dplyr::select(-dail, -name, -text, -subject, -date) %>%
  mutate(electiondate_clean = as.Date(as.character(electiondate), "%m/%d/%y")) %>% 
  filter(electiondate_clean >=  as.Date("2020-02-08")) %>% 
  distinct() %>% 
  select(c(voteshare, quotashare, result, name_clean)) %>% 
  rename(voteshare_next = voteshare, 
         quotashare_next = quotashare, 
         result_next = result)

full2016_next_distinct <- left_join(full2016_distinct, elecdata2016_next, by = "name_clean" )
saveRDS(full2016_next_distinct, "speeches/elec_data_2016_with_hh_prop_distinct.Rdata")











