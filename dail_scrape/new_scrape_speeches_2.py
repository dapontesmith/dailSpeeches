from bs4 import BeautifulSoup
#import urllib
#from urllib.request import urlopen
#from urllib.request import urlretrieve
import requests
import pandas as pd
from datetime import datetime, timedelta
import re

#Define function to scrape speeches 
def scrape_dail_func(debate_date):
    print(debate_date)
    url = "https://www.oireachtas.ie/en/debates/debate/dail/" + debate_date
    r = requests.get(url)
    soup = BeautifulSoup(r.text)
    #find all debate topics 
    topics = soup.find_all("div",{"class":"results"})
    if topics == []: 
        return
    else: 
        #if there is no session on that date, just end the function 
        # if there is a session on that date, keep going
        #get list of debate subsections
        #topic_holder = []
        #for topic in topics:
         #   topic_holder.append(topic.text)
            #split the list of subsections at the three spaces 
        #topic_list = str(topic_holder).split("   ")
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
        #full_section_list = []
        df = pd.DataFrame()
        #at the moment this approach is double-counting speeches in the "topical issue" debates ... 
        #has something to do with the structure of the links 
        for number in debates_clean: 
            debate_date_text_holder = []
            url_to_use = "https://www.oireachtas.ie"+ str(number)
            #go through BeautifulSoup protocol for section page 
            r = requests.get(url_to_use)
            text = r.text
            soup = BeautifulSoup(text)
            #define empty lists to which to append 
            text_url_holder = []
            text_holder = []
            #find all speeches and links 
            holder = soup.find_all("div", {"class":"speech"})
            #initialize empty speak vector 
            speaker_suffixes = []
            #find date of debate
            date_raw = soup.find("h1", {"class":"c-hero__title"})
            #get both the text of the speech
            for div in holder: 
                t = div.find_all("a", href = True)
                #get each hyperlink that corresponds to a speech
                #this gets us only as many speeches as name hyperlinks
                #if someone doesn't have a hyperlink (extrmeely rare), their speech is not included 
                for a in t: 
                    if not "#" in a["href"]: 
                    #put together speech and url 
                        text_url_holder.append(div.text + a["href" ])
            #take every other instance of the txt holder, since it gets each speech twice 
            text_url_holder = text_url_holder[::2]
            for index in range(0, len(text_url_holder)): 
                #split speech and url
                speaker_suffixes.append(text_url_holder[index].split("/en/",1)[1])
                text_holder.append(text_url_holder[index].split("/en/",1)[0])
                #add prefix "/en/" back to url 
                speaker_suffixes[index] = "/en/"+ speaker_suffixes[index]
            date = date_raw.text.split(",")[1]
            debate_date_text_holder.extend(text_holder)
            #split speech entries at "Share", which separates speaker from speech 
            for index in range(0, len(debate_date_text_holder)):
                full_text_holder.append(debate_date_text_holder[index].split("Share",1)[1])
            #section_name = str(soup.title.string)
            #full_section_list.extend(section_name)    
            #find speaker names
            for suffix in speaker_suffixes: 
                speaker_name_dash = suffix.split("/member/",1)[1].split(".",1)[0]
                speaker_name = speaker_name_dash.replace("-", " " )
                full_speaker_list.append(speaker_name )
            #initialize empty list to store names of each section's speakers
                #speakers = []
                #BS protocol for speaker profile webpage

        
        df["speech"] = full_text_holder
        df["speaker"] = full_speaker_list
        # df["section"] = full[2]
        #insert date column 
        df["date"] = [date] * len(full_text_holder)
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
    column = column.str.replace(" ", "")
    
    #convert dates to yyyy-mm-dd
    for index in range(0, len(column)): 
      column.iloc[index] =  datetime.strptime(column.iloc[index], "%d-%m-%Y").strftime("%Y-%m-%d")
    return(column)
    #convert dates to yyyy-mm-dd


freq = "-1D"
date_list = pd.date_range("2016-06-29", periods = 365, freq = freq).strftime("%Y-%m-%d").tolist()
#date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
df_holder = []
for i in date_list: 
    out = scrape_dail_func(debate_date = i)
    df_holder.append(out)
df_holder = pd.concat(df_holder)

df_holder["date"] = replace_month_names(df_holder["date"])

df_holder.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_23.csv")

#reformat d


freq = "-1D"
final_date = df_holder["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")

date_list = pd.date_range(day_before_final, periods = 365, freq = freq).strftime("%Y-%m-%d").tolist()
#date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
df_holder24 = []
for i in date_list: 
    out = scrape_dail_func(debate_date = i)
    df_holder24.append(out)
df_holder24 = pd.concat(df_holder24)

df_holder24["date"] = replace_month_names(df_holder24["date"])

df_holder24.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_24.csv")



freq = "-1D"
final_date = df_holder24["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")

date_list = pd.date_range(day_before_final, periods = 365, freq = freq).strftime("%Y-%m-%d").tolist()
#date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
df_holder25 = []
for i in date_list: 
    out = scrape_dail_func(debate_date = i)
    df_holder25.append(out)
df_holder25 = pd.concat(df_holder25)

df_holder25["date"] = replace_month_names(df_holder25["date"])

df_holder25.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_25.csv")



freq = "-1D"
final_date = df_holder25["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
while True: 
    try: 
        date_list = pd.date_range(day_before_final, periods = 365, freq = freq).strftime("%Y-%m-%d").tolist()
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        df_holder26 = []
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder26.append(out)
    except TypeError or ConnectionError:
        False
        break
df_holder26 = pd.concat(df_holder26)
df_holder26["date"] = replace_month_names(df_holder26["date"])
df_holder26.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_26.csv")





freq = "-1D"
final_date = df_holder26["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
#NOTE THAT SOMETJING IS UP WITH 2013-03-06 - NEED TO GO BACK AND CHECK THAT DATE 
while True:
    try: 
        date_list = pd.date_range("2013-03-05", periods = 365, freq = freq).strftime("%Y-%m-%d").tolist()
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        df_holder27 = []
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder27.append(out)
    except TypeError or ConnectionError or IndexError: 
        False
        break
df_holder27 = pd.concat(df_holder27)
df_holder27["date"] = replace_month_names(df_holder27["date"])
df_holder27.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_27.csv")


freq = "-1D"
final_date = df_holder27["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
while True: 
    try: 
        date_list = pd.date_range("2012-10-09", periods = 3650, freq = freq).strftime("%Y-%m-%d").tolist()
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        df_holder28 = []
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder28.append(out)
    except TypeError or IndexError or ConnectionError: 
        False
        break
df_holder28 = pd.concat(df_holder28)
df_holder28["date"] = replace_month_names(df_holder28["date"])
df_holder28.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_28.csv")



freq = "-1D"
final_date = df_holder28["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
while True:
    try:
        date_list = pd.date_range("2011-04-18", periods = 730, freq = freq).strftime("%Y-%m-%d").tolist()
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        df_holder29 = []
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder29.append(out)
    except TypeError or ConnectionError or IndexError: 
        False
        break
df_holder29 = pd.concat(df_holder29)
df_holder29["date"] = replace_month_names(df_holder29["date"])
df_holder29.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_29.csv")



freq = "-1D"
final_date = df_holder29["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
#need to scrape 2010-09-30 again somewhow 
while True:
    try:
        date_list = pd.date_range("2010-09-28", periods = 730, freq = freq).strftime("%Y-%m-%d").tolist()
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        df_holder30 = []
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder30.append(out)
    except TypeError or ConnectionError or IndexError or AttributeError: 
        False
        break
df_holder30 = pd.concat(df_holder30)
df_holder30["date"] = replace_month_names(df_holder30["date"])
df_holder30.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_30.csv")


freq = "-1D"
final_date = df_holder30["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
while True:
    try:
        date_list = pd.date_range(final_date, periods = 730, freq = freq).strftime("%Y-%m-%d").tolist()
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        df_holder31 = []
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder31.append(out)
    except TypeError or ConnectionError or IndexError or AttributeError: 
        False
        break
df_holder31 = pd.concat(df_holder31)
df_holder31["date"] = replace_month_names(df_holder31["date"])
df_holder31.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_31.csv")


freq = "-1D"
final_date = df_holder31["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
while True:
    try:
        date_list = pd.date_range(final_date, periods = 730, freq = freq).strftime("%Y-%m-%d").tolist()
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        df_holder32 = []
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder32.append(out)
    except TypeError or ConnectionError or IndexError or AttributeError: 
        False
        break
df_holder32 = pd.concat(df_holder32)
df_holder32["date"] = replace_month_names(df_holder32["date"])
df_holder32.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_32.csv")

#need to re-scrape 2008-09-24

freq = "-1D"
final_date = df_holder31["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
while True:
    try:
        date_list = pd.date_range("2008-09-23", periods = 730, freq = freq).strftime("%Y-%m-%d").tolist()
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        df_holder33 = []
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder33.append(out)
    except TypeError or ConnectionError or IndexError or AttributeError: 
        False
        break
df_holder33 = pd.concat(df_holder33)
df_holder33["date"] = replace_month_names(df_holder33["date"])
df_holder33.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_33.csv")


freq = "-1D"
final_date = df_holder33["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
while True:
    try:
        date_list = pd.date_range(final_date, periods = 730, freq = freq).strftime("%Y-%m-%d").tolist()
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        df_holder34 = []
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder34.append(out)
    except TypeError or ConnectionError or IndexError or AttributeError: 
        False
        break
df_holder34 = pd.concat(df_holder34)
df_holder34["date"] = replace_month_names(df_holder34["date"])
df_holder34.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_34.csv")

#need to re-scrape 2007-09-26
freq = "-1D"
final_date = df_holder34["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
while True:
    try:
        date_list = pd.date_range("2007-09-25", periods = 730, freq = freq).strftime("%Y-%m-%d").tolist()
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        df_holder35 = []
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder35.append(out)
    except TypeError or ConnectionError or IndexError or AttributeError: 
        False
        break
df_holder35 = pd.concat(df_holder35)
df_holder35["date"] = replace_month_names(df_holder35["date"])
df_holder35.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_35.csv")


freq = "-1D"
final_date = df_holder35["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
while True:
    try:
        date_list = pd.date_range("2006-04-26", periods = 730, freq = freq).strftime("%Y-%m-%d").tolist()
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        df_holder36 = []
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder36.append(out)
    except TypeError or ConnectionError or IndexError or AttributeError: 
        False
        break
df_holder36 = pd.concat(df_holder36)
df_holder36["date"] = replace_month_names(df_holder36["date"])
df_holder36.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_36.csv")


freq = "-1D"
final_date = df_holder36["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
df_holder37 = []
while True:
    if len(df_holder37) < 731: 
        try:
            date_list = pd.date_range(final_date, periods = 730, freq = freq).strftime("%Y-%m-%d").tolist()
            #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
            for i in date_list: 
                out = scrape_dail_func(debate_date = i)
                df_holder37.append(out)
        except TypeError or ConnectionError or IndexError or AttributeError: 
            False
            break
    else: 
        break
df_holder37 = pd.concat(df_holder37)
df_holder37["date"] = replace_month_names(df_holder37["date"])
df_holder37.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_37.csv")


freq = "-1D"
final_date = df_holder37["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
while True:
    try:
        date_list = pd.date_range(final_date, periods = 730, freq = freq).strftime("%Y-%m-%d").tolist()
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        df_holder38 = []
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder38.append(out)
    except TypeError or ConnectionError or IndexError or AttributeError: 
        False
        break
df_holder38 = pd.concat(df_holder38)
df_holder38["date"] = replace_month_names(df_holder38["date"])
df_holder38.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_38.csv")


freq = "-1D"
final_date = df_holder38["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
df_holder39= []
while True:
    if len(df_holder39) < 3651: 
        try:
            date_list = pd.date_range(final_date, periods = 3650, freq = freq).strftime("%Y-%m-%d").tolist()
            #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
            for i in date_list: 
                out = scrape_dail_func(debate_date = i)
                df_holder39.append(out)
        except TypeError or ConnectionError or IndexError or AttributeError: 
            False
            break
    else:
        break
df_holder39 = pd.concat(df_holder39)
df_holder39["date"] = replace_month_names(df_holder39["date"])
df_holder39.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_39.csv")



freq = "-1D"
final_date = df_holder39["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
df_holder40= []
while True:
    if len(df_holder40) < 3651: 
        try:
            date_list = pd.date_range(final_date, periods = 3650, freq = freq).strftime("%Y-%m-%d").tolist()
            #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
            for i in date_list: 
                out = scrape_dail_func(debate_date = i)
                df_holder40.append(out)
        except TypeError or ConnectionError or IndexError or AttributeError: 
            False
            break
    else:
        break
df_holder40 = pd.concat(df_holder40)
df_holder40["date"] = replace_month_names(df_holder40["date"])
df_holder40.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_40.csv")



freq = "-1D"
final_date = df_holder40["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
df_holder41= []
date_list = pd.date_range(final_date, periods = 365*4, freq = freq).strftime("%Y-%m-%d").tolist()
while True: 
    try:
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder41.append(out)
    except TypeError or ConnectionError or IndexError or AttributeError: 
        False
        break
df_holder41 = pd.concat(df_holder41)
df_holder41["date"] = replace_month_names(df_holder41["date"])
df_holder41.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_41.csv")


freq = "-1D"
final_date = df_holder41["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
#need to re-scrape 2000-05-10
df_holder42= []
date_list = pd.date_range("2000-05-09", periods = 365*10, freq = freq).strftime("%Y-%m-%d").tolist()
while True: 
    try:
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder42.append(out)
    except TypeError or ConnectionError or IndexError or AttributeError: 
        False
        break
df_holder42 = pd.concat(df_holder42)
df_holder42["date"] = replace_month_names(df_holder42["date"])
df_holder42.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_42.csv")

df_holder42 = pd.read_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_42.csv")

freq = "-1D"
final_date = df_holder42["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
#need to re-scrape 2000-05-10
df_holder43= []
date_list = pd.date_range(final_date, periods = 365*10, freq = freq).strftime("%Y-%m-%d").tolist()
while True: 
    try:
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder43.append(out)
    except TypeError or ConnectionError or IndexError or AttributeError: 
        False
        break
df_holder43 = pd.concat(df_holder43)
df_holder43["date"] = replace_month_names(df_holder43["date"])
df_holder43.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_43.csv")

df_holder43 = pd.read_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_43.csv")


freq = "-1D"
final_date = df_holder43["date"].iloc[-1]
final_date = datetime.strptime(final_date, "%Y-%m-%d")
day_before_final = final_date - timedelta(1)
day_before_final = datetime.strftime(day_before_final, "%Y-%m-%d")
#need to re-scrape 2000-05-10
df_holder44= []
date_list = pd.date_range(final_date, periods = 365*10, freq = freq).strftime("%Y-%m-%d").tolist()
while True: 
    try:
        #date_list = ["2020-07-15", "2020-07-09","2020-07-08"]
        for i in date_list: 
            out = scrape_dail_func(debate_date = i)
            df_holder44.append(out)
    except TypeError or ConnectionError or IndexError or AttributeError: 
        False
        break
df_holder44 = pd.concat(df_holder44)
df_holder44["date"] = replace_month_names(df_holder44["date"])
df_holder44.to_csv("C:/Users/dapon/Dropbox/Smith-Daponte-Smith/dail_scrape/speeches_44.csv")