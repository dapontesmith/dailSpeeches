#purpose of the file: 
#to code a speech as "local" if it contains a place-name mention
#to create a metric for proportion of all speech-words which are place-names 
setwd("C:/Users/dapon/Dropbox/Smith-Daponte-Smith")

#load and prepare for analysis - same as in "create_index" file 
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

##################################################################################################
#### BEGIN ANALYSIS ####################################
#####################################################################################
#need to define a function that codes a speech as "local" if it contains a placename 


speeches_data <- speeches1997
places_data <- places1995
constit_year <- places_full$const95
speakers <- unique(speeches_data$name_clean)
local_holder <- NULL

#loop through speakers 
for(j in 1:length(speakers[1:5])){
  print(j)
  #define speeches 
  speeches_speaker <- speeches_data$text[speeches_data$name_clean == speakers[j]]
  #make holder matrix, nrow = speakers, ncol = speeches
  #loop through speeches given by speaker
  for(i in 1:length(speeches_speaker)){
    #mae holder vector, length = number of speeches
    holder <- NULL
    is_local <- NULL
    #getdistrict
    constituency <- unique(speeches_data$district[speeches_data$name_clean == speakers[j]])
    #get places in the constit
    places_in_constit <- unique(places_data$name[constit_year == constituency])
    places_in_constit <- places_in_constit[!(is.na(places_in_constit))]
    appears <- NULL
    for(k in 1:length(places_in_constit)){
      place_appears <- str_detect(speeches_speaker[i], places_in_constit[k])
      appears[k] <- place_appears
      
    }
    is_local <- ifelse(appears == TRUE, 1, 0)
    #loop through place-names 
    if(sum(is_local) != FALSE){
      holder[i] <- 1
    } else {
      holder[i] <- 0
    }
  }
  local_holder[[j]] <- holder
  
}

code_speeches_func <- function(speeches_data, places_data, constit_year){
 
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
