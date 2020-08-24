# -*- coding: utf-8 -*-
"""
Created on Mon Aug 24 12:53:26 2020

@author: dapon
"""

# -*- coding: utf-8 -*-
"""
Created on Thu Aug  6 15:40:10 2020

@author: dapon
"""

from bs4 import BeautifulSoup
#import urllib
#from urllib.request import urlopen
#from urllib.request import urlretrieve
import requests
import pandas as pd
from datetime import datetime

#make list of urls to loop through - this follows the structure of te site
urls = []
for i in range(1, 85): 
    url_to_append = "page=" + str(i) + "&"
    urls.append("https://www.oireachtas.ie/en/debates/find/?" + url_to_append + "datePeriod=all&debateType=dail&resultsPerPage=100")
urls.insert(0, "https://www.oireachtas.ie/en/debates/find/?datePeriod=all&debateType=dail&resultsPerPage=100")

#get all urls for all debate pages, so we can loop through them (which might be easier)
all_debates = []
for page in urls: 
    print(page)
    r = requests.get(page)
    text = r.text
    soup = BeautifulSoup(text)
    links_raw = []
    links_raw = soup.find_all("a", href = True)
    links = []
    prefix = "/en/debates/debate/"
    for a in links_raw: 
        links.append(a["href"])
    debates = [x for x in links if x.startswith(prefix)]
    all_debates.extend(debates)
#remove urls having to do with "select_committee_on_members'_interests_of_seanad_éireann", 
    #since the links for all of those appear to be non-functional at the moment 
all_debates_clean = []
for element in all_debates: 
    if "#" not in element: 
        all_debates_clean.append(element)
        
def scrape_question(number): 
    #initialize empty lists to add stuff to
    full_text_holder = []
    full_speaker_list = []
    df = pd.DataFrame()
    date_list = []
    #for each url, loop through all the pages
    print(all_debates_clean[number])   
    date = []
    debate_date_text_holder = []
    url_to_use = "https://www.oireachtas.ie"  + all_debates_clean[number]
    r = requests.get(url_to_use)
    text = r.text
    soup = BeautifulSoup(text)
    #get date 
    debate_date = soup.find_all("h1",{"class":"c-hero__title"})
    date = []
    for j in debate_date: 
        date.append(j.text)
    date = date[0].split(" - ")[1]
    #get committee name
    text_holder = []  
    text_url_holder = []
    speaker_suffixes = []
    #find all speeches and links 
    holder = soup.find_all("div", {"class":"question"})
    for div in holder: 
        t = div.find_all("a", href = True)
        #get each hyperlink that corresponds to a speech
        #this gets us only as many speeches as name hyperlinks
        #if someone doesn't have a hyperlink (extrmeely rare), their speech is not included 
        for a in t: 
            if not "#" in a["href"]: 
            #put together speech and url 
                text_url_holder.append(div.text + a["href" ])
    text_url_holder = text_url_holder[::2]
    #get only those speeches which contain member links, not other links
    #this deals with caes in which a speaker doesn't have a member link (i.e. public health official)
    #but their speech does contain a link
    text_member_links = []
    for entry in text_url_holder: 
        if "/en/members/member" in entry: 
            text_member_links.append(entry)      
    #separate text from links in the list      
    for index in range(0, len(text_member_links)): 
        #split speech and url
        speaker_suffixes.append(text_member_links[index].split("/en/",1)[1])
        text_holder.append(text_member_links[index].split("/en/",1)[0])
        #add prefix "/en/" back to url 
        speaker_suffixes[index] = "/en/"+ speaker_suffixes[index]
    debate_date_text_holder.extend(text_holder)
    #split speech entries at "Share", which separates speaker from speech 
    for index in range(0, len(debate_date_text_holder)):
        full_text_holder.append(debate_date_text_holder[index].split("Share",1)[1].split("Question",1)[1])
    for suffix in speaker_suffixes: 
    #initialize empty list to store names of each section's speakers
    #we find the speaker names in the URLs of their webpage! This is pretty quick 
        speaker_name_dash = suffix.split("/member/",1)[1].split(".",1)[0]
        speaker_name = speaker_name_dash.replace("-", " " )
        full_speaker_list.append(speaker_name )
    date_list.extend([date] * len(text_holder))
    full = [full_text_holder, full_speaker_list]
    df["speech"] = full[0]
    df["speaker"] = full[1]
    # df["section"] = full[2]
    #insert date column 
    df["date"] = date_list
    return(df)
    


def replace_month_names(column): 
    #column is a column of a pandas dataframe
    column = column.str.replace(" Jan ", "-01-").replace()
    column =column.str.replace(" Feb ", "-02-")
    column =column.str.replace(" Mar ", "-03-")
    column =column.str.replace(" Apr ", "-04-")
    column =column.str.replace(" May ", "-05-")
    column =column.str.replace(" Jun ", "-06-")
    column =column.str.replace(" Jul ", "-07-")
    column =column.str.replace(" Aug ", "-08-")
    column =column.str.replace(" Sep ", "-09-")
    column =column.str.replace(" Oct ", "-10-")
    column =column.str.replace(" Nov ", "-11-")
    column =column.str.replace(" Dec ", "-12-")
    column = column.str.replace("Monday", "")
    column = column.str.replace("Tuesday", "")
    column = column.str.replace("Wednesday", "")
    column = column.str.replace("Thursday", "")
    column = column.str.replace("Friday", "")
    column = column.str.replace("Saturday", "")
    column = column.str.replace("Sunday", "")
    column = column.str.replace(" ", "")
    column = column.str.replace(",", "")

    #convert dates to yyyy-mm-dd
    for index in range(0, len(column)): 
      column.iloc[index] =  datetime.strptime(column.iloc[index], "%d-%m-%Y").strftime("%Y-%m-%d")
    return(column)
    #convert dates to yyyy-mm-dd
    
    
#run function
df_holder = []
num_list = range(1, 500)
all_scraped = []
for i in num_list: 
    out = scrape_question(i)
    df_holder.append(out)
    all_scraped.append(i)
df_holder = pd.concat(df_holder)
df_holder["date"] = replace_month_names(df_holder["date"])
df_holder.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/questions1.csv")



df_holder2 = []
num_list2 = range(all_scraped[-1]+1, 2000)
all_scraped2 = []
for i in num_list2: 
    out = scrape_question(i)
    df_holder2.append(out)
    all_scraped2.append(i)
df_holder2 = pd.concat(df_holder2)
df_holder2["date"] = replace_month_names(df_holder2["date"])
df_holder2.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/questions2.csv")




df_holder3 = []
num_list3 = range(all_scraped2[-1]+1, 10000)
all_scraped3 = []
for i in num_list3: 
    print(i)
    out = scrape_question(i)
    df_holder3.append(out)
    all_scraped3.append(i)
df_holder3 = pd.concat(df_holder3)
df_holder3["date"] = replace_month_names(df_holder3["date"])
df_holder3.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/questions3.csv")



df_holder4 = []
num_list4 = range(all_scraped3[-1]+1, 20000)
all_scraped4 = []
for i in num_list4: 
    print(i)
    out = scrape_question(i)
    df_holder4.append(out)
    all_scraped4.append(i)
df_holder4 = pd.concat(df_holder4)
df_holder4["date"] = replace_month_names(df_holder4["date"])
df_holder4.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/questions4.csv")




