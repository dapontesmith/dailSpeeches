#purpose of the file: 
#to code a speech as "local" if it contains a place-name mention
#to create a metric for proportion of all speech-words which are place-names 
setwd("C:/Users/dapon/Dropbox/Smith-Daponte-Smith")

#load and prepare for analysis - same as in "create_index" file 
finaljoin <- readRDS("speeches/speeches_1997_2019_FINAL.Rdata") 
places_full <- readRDS("constituencies/constituencies_placenames_matched.Rdata")
full1997 <- readRDS("speeches/elec_data_1997_with_hh_prop_distinct2.Rdata")
full2002 <- readRDS("speeches/elec_data_2002_with_hh_prop_distinct2.Rdata")
full2011 <- readRDS("speeches/elec_data_2011_with_hh_prop_distinct2.Rdata")
full2016 <- readRDS("speeches/elec_data_2016_with_hh_prop_distinct2.Rdata")


#define types of locations
location_types <- c("town","civil parish","electoral district","population centre",
                    "administrative county","city","county","sub-townland","island or archipelago",
                    "barony","canal") # ,"port","junction, interchange","field","quay, pier, wharf",
                    #"house","river","wood","man-made feature", "monument",
                    #"mountain or mountain range", "locality","valley","feature")
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

##################################################################################################
#### BEGIN ANALYSIS ####################################
#####################################################################################
#need to define a function that codes a speech as "local" if it contains a placename 


code_speeches_func <- function(speeches_data, places_data, 
                               constit_year){ 

  speakers <- unique(speeches_data$name_clean)
  local_holder <- NULL

  #loop through speakers 
  for(j in 1:length(speakers)){
    print(j)
    #define speeches 
    speeches_speaker <- speeches_data$text[speeches_data$name_clean == speakers[j]]

    #getdistrict
    #get places in the constit
    constituency <- unique(speeches_data$district[speeches_data$name_clean == speakers[j]])
    places_in_constit <- unique(places_data$name[constit_year == constituency])
    places_in_constit <- places_in_constit[!(is.na(places_in_constit))]
  
    #define holder 
    is_local <- NULL
    #loop through speeches given by speaker
    for(i in 1:length(speeches_speaker)){
      #mae holder vector, length = number of speeches
      place_mentioned <- NULL
    
      for(k in 1:length(places_in_constit)){
        place_mentioned[k] <- ifelse(str_detect(speeches_speaker[i], places_in_constit[k]) == TRUE, 1, 0)
      }
      #if any element of place_mentioned is TRUE, the speech is local 
      if(sum(place_mentioned, na.rm = T) != 0){
        is_local[i] <- 1
      } else {
        is_local[i] <- 0
      }
    }
    local_holder[[j]] <- is_local
  }

#now go through and divide sum of local_holder[[j]] by length of local_holder[[j]]
#summing the elemnt of holder list gives us proportion of speeches that are local
  prop_holder <- NULL
  for(j in 1:length(speakers)){
    prop_holder[j] <- sum(local_holder[[j]])/length(local_holder[[j]])
  }
  out <- data.frame(cbind(unique(speeches_data$name_clean), prop_holder))
}




#run function on the various datasets 
prop_speeches_local1997 <- code_speeches_func(speeches_data = speeches1997, 
                               places_data = places1995, 
                               constit_year = places1995$const95) %>% 
  as_tibble()
prop_speeches_local1997 <- prop_speeches_local1997 %>% 
  rename("name_clean" = "V1", "prop_speeches_local" = "prop_holder")
#merge this back in with the full data 
full1997 <- left_join(full1997, prop_speeches_local1997, by = "name_clean")

prop_speeches_local2002 <- code_speeches_func(speeches_data = speeches2002, 
                                              places_data = places1998, 
                                              constit_year = places1998$const98) %>% 
  as_tibble() %>% 
  rename("name_clean" = "V1", "prop_speeches_local" = "prop_holder")
full2002 <- left_join(full2002, prop_speeches_local2002, by = "name_clean")


prop_speeches_local2011 <- code_speeches_func(speeches_data = speeches2011, 
                                              places_data = places2007, 
                                              constit_year = places2007$const2007) %>% 
  as_tibble() %>% 
  rename("name_clean" = "V1", "prop_speeches_local" = "prop_holder")
full2011 <- left_join(full2011, prop_speeches_local2011, by = "name_clean")


prop_speeches_local2016 <- code_speeches_func(speeches_data = speeches2016, 
                                              places_data = places2013, 
                                              constit_year = places2013$const2013) %>% 
  as_tibble() %>% 
  rename("name_clean" = "V1", "prop_speeches_local" = "prop_holder")
full2016 <- left_join(full2016, prop_speeches_local2016, by = "name_clean")


#save data 
saveRDS(full1997, "speeches/full_elec_data_with_speech_indexes1997.Rdata")
saveRDS(full2002, "speeches/full_elec_data_with_speech_indexes2002.Rdata")
saveRDS(full2011, "speeches/full_elec_data_with_speech_indexes2011.Rdata")
saveRDS(full2016, "speeches/full_elec_data_with_speech_indexes2016.Rdata")




