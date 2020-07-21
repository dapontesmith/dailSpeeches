# -*- coding: utf-8 -*-
"""
Created on Sat Jul 18 14:40:33 2020

@author: dapon
"""
from bs4 import BeautifulSoup
#import urllib
#from urllib.request import urlopen
#from urllib.request import urlretrieve
import requests
import pandas as pd
from datetime import datetime


#Define function to scrape dail speeches  
def scrape_dail_func(debate_date):
    import re
    #debate_date = date of the debate in YYYY-MM-DD (string)
    
    #go through beautiful soup protocol for debate  date landing page
    url = "https://www.oireachtas.ie/en/debates/debate/dail/" + debate_date
    r = requests.get(url)
    text = r.text
    soup = BeautifulSoup(text)
    #find all debate topics 
    topics = soup.find_all("div",{"class":"results"})
    #if there is no session on that date, just end the function 
    if topics == []:
        return
    # if there is a session on that date, keep going 
    else: 
        #get list of debate subsections
        topic_holder = []
        for topic in topics:
            topic_holder.append(topic.text)
        #split the list of subsections at the three spaces 
        topic_list = str(topic_holder).split("   ")
        #get all links to the debate sections 
        links_raw = soup.find_all("a", href=True)
        links=[]
        prefix = "/en/debates/debate/dail"
        for a in links_raw: 
            links.append(a["href"])
        debates = [x for x in links if x.startswith(prefix)] 
        #exclude subsection links, since they're already included under a full section link
        debates_clean = [i for i in debates if not ('#' in i)]
        #initialize holder lists 
        full_text_holder = []
        full_speaker_list = []
        full_section_list = []
        df = pd.DataFrame()
        #at the moment this approach is double-counting speeches in the "topical issue" debates ... 
        #has something to do with the structure of the links 
        for number in debates_clean: 
            debate_date_text_holder = []
            url_to_use = "https://www.oireachtas.ie/" + str(number)
            #go through BeautifulSoup protocol for section page 
            r = requests.get(url_to_use)
            text = r.text
            soup = BeautifulSoup(text)
            #define empty lists to which to append 
            text_holder = []
            #find all speeches, which begin with speaker name 
            holder = soup.find_all(id = re.compile("^spk_"))
            date_raw = soup.find("h1", {"class":"c-hero__title"})
            for div in holder: 
                text_holder.append(div.text)
            date = date_raw.text.split(",")[1]
            debate_date_text_holder.extend(text_holder)
            #split speech entries at "Share", which separates speaker from speech 
            for index in range(0, len(debate_date_text_holder)):
                full_speaker_list.append(debate_date_text_holder[index].split("Share",1)[0])
                full_text_holder.append(debate_date_text_holder[index].split("Share",1)[1])
            section_name = str(soup.title.string)
            full_section_list.extend(section_name)
        full = [full_text_holder, full_speaker_list, full_section_list]
        df["speech"] = full[0]
        df["speaker"] = full[1]
       # df["section"] = full[2]
       #insert date column 
        df["date"] = [date] * len(full[0])
        return(df)
        
#define date range for scraping 
def scrape_over_range_func(freq, years): 
    #freq = numeric, how often to create a date to scrape (1 = every day)
    #years = numeric, how many years to scrape 
    freq = "-" + str(freq) + "D"
    date_list = pd.date_range(datetime.today(), periods = 365*years, freq = freq).strftime("%Y-%m-%d").tolist()
    df_holder = []
    for i in date_list: 
        out = scrape_dail_func(debate_date = i)
        df_holder.append(out)
    df_holder = pd.concat(df_holder)
    return(df_holder)

test = scrape_over_range_func(freq = 1, years = 1) 
    
    
freq = '-1D'
date_list = pd.date_range(datetime.today(), periods=365*4, freq = freq).strftime('%Y-%m-%d').tolist()
#now run the function on the list of dates 
df_holder = []
for i in date_list: 
    out = scrape_dail_func(debate_date = i)
    df_holder.append(out)
df_holder = pd.concat(df_holder)

#write file to csv 
df_holder.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/summer2020/speeches.csv")


