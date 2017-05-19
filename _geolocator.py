import pandas as pd
import numpy as np
import os, googlemaps, pickle, re
import argparse

argparser = argparse.ArgumentParser(description='Geolocate entities in NIC Organization Hierarchies.')
argparser.add_argument('-r', '--rssd', nargs='+', help='list of rssds to geolocate')
args = argparser.parse_args()

abspath = os.path.abspath(__file__)
dname = os.path.dirname(abspath)
os.chdir(dname)

api_key = open('GOOGLEMAPS_API_KEY').read()

gmaps = googlemaps.Client(key=api_key)

# LocationMaster -- dictionary used to store geodata; if an entity's location has
# already been geolocated, just pull the information from here; if it hasn't,
# then add the geodata retrieved from Google Maps
if os.path.isfile('app/LocationMaster'):
	master = pickle.load(open('app/LocationMaster', 'rb+'))
else:
	master = dict()

readfiles = [os.path.join('txt',f) for f in os.listdir('txt')]
if args.rssd:
  readfiles = filter(lambda x: re.search('\\d+', x).group() in args.rssd, readfiles)


for readfile in readfiles:
  print('Reading  ', readfile)
  
  # http://stackoverflow.com/questions/17092671
  df = pd.read_csv(readfile, dtype={'Parent': object})
  
  df['label'] = np.nan
  df['lat'] = np.nan
  df['lng'] = np.nan
  
  uniqLoc = df['Loc'].unique()
  
  for u in uniqLoc:
    if u not in master:
      print('Requesting  ' + u)
      result = gmaps.geocode(u)
      
      if result:
        coord = result[0]['geometry']['location']
        addr = result[0]['formatted_address']
        
        addr = addr.replace(', USA', '')
        addr = re.sub('([^,]*,).*, (.*)', '\\1 \\2', addr)
        addr = re.sub('[0-9]', '', addr).strip()
        
        master[u] = dict()
        master[u]['label'] = addr
        master[u]['lat'] = float(np.round(coord['lat'], 7))
        master[u]['lng'] = float(np.round(coord['lng'], 7))
        
      else:
        print(u + '  returned result of length zero')
        continue
        
    df.loc[df.Loc == u,'label'] = master[u]['label']
    df.loc[df.Loc == u,'lat'] = master[u]['lat']
    df.loc[df.Loc == u,'lng'] = master[u]['lng']

  # Save
  df.to_csv(readfile, index=False, encoding='utf-8')
  #df.to_json(readfile.replace('txt','json'), orient='records')

pickle.dump(master, open('app/LocationMaster', 'wb+'))


