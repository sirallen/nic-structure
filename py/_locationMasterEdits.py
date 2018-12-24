import os, pickle
import pandas as pd

abspath = os.path.abspath(__file__)
dname = os.path.dirname(abspath)
os.chdir(dname)

master = pickle.load(open('../app/LocationMaster', 'rb+'))


master['AMSTERDAM NETHERLAN DS ANTILLES'] = {'label': 'Amsterdam, Netherlands', 'lat': 52.3702157, 'lng': 4.8951679}
master['ATLANTA DE'] = {'label': 'Newark, DE', 'lat': 39.6837226, 'lng': -75.7496572}
master['BAYONNE MA'] = {'label': 'Bayonne, NJ', 'lat': 40.6687141, 'lng': -74.1143091}
master['CENTRAL HONG KONG CHINA, PEOPLES REPUBLIC OF'] = {'label': 'Central, Hong Kong', 'lat': 22.2821181, 'lng': 114.1510632}
# State Street Corporation -- 2004q1 - 2005q1
master['CURACO ANTILLES CURACAO, BONAIRE, SABA, ST. MARTIN & ST.'] = {'label': 'Curaçao', 'lat': 12.1695700, 'lng': -68.9900200}
master['DOUALA CAMEROON, UNITED REPUBLIC OF'] = {'label': 'Douala, Cameroon', 'lat': 4.0510564, 'lng': 9.7678687}
master['DUBAI UNITED ARAB EMIRATES']['label'] = 'Dubai, United Arab Emirates'
master['EDINBURGH CAYMAN ISLANDS'] = {'label': 'Edinburgh, UK', 'lat': 55.9532520, 'lng': -3.1882670}
master['EDINBURGH ENGLAND'] = {'label': 'Edinburgh, UK', 'lat': 55.9532520, 'lng': -3.1882670}
master['EXTENDED RIPLEY MS'] = {'label': 'Ripley, MS', 'lat': 34.733526, 'lng': -89.0187606}
master['GEORGE TOWN UNITED KINGDOM'] = {'label': 'George Town, Cayman Islands', 'lat': 19.2869323, 'lng': -81.3674389}
master['HALIFAX CANADA']['label'] = 'Halifax, Canada'
master['HONG KONG CAYMAN ISLANDS'] = {'label': 'Hong Kong', 'lat': 22.3964280, 'lng': 114.1094970}
master['LONDON UNITED ARAB EMIRATES'] = {'label': 'London, UK', 'lat': 51.5073509, 'lng': -0.1277583}
master['LONDON WALES'] = {'label': 'London, UK', 'lat': 51.5073510, 'lng': -0.1277583}
master['LUXEMBOURG ENGLAND'] = {'label': 'Luxembourg City, Luxembourg', 'lat': 49.6116210, 'lng': 6.1319346}
master['LUXEMBOURG GERMANY'] = {'label': 'Luxembourg City, Luxembourg', 'lat': 49.6116210, 'lng': 6.1319346}
master['LUXEMBOURG LITHUANIA'] = {'label': 'Luxembourg City, Luxembourg', 'lat': 49.6116210, 'lng': 6.1319346}
# Bank of America -- ? - 2002q3 https://www.ceginfo.hu/ceg-adatlap/hc-invest-szallitmanyozasi-kft-0109666219.html
master['MAGYKROSI HUNGARY'] = {'label': 'Budapest, Hungary', 'lat': 47.4808722, 'lng': 18.8501225}
master['MIAMI CA'] = {'label': 'Miami, FL', 'lat': 25.7616798, 'lng': -80.1917902}
# J.P. Morgan idrssd 3723887 2008-06-30; Middlesex is historic county in England that no longer exists; see http://www.gov.ky/portal/pls/portal/docs/1/11524723.PDF
master['MIDDLESEX ENGLAND'] = {'label': 'George Town, Cayman Islands', 'lat': 19.2869323, 'lng': -81.3674389}
master['MOLOKAI HI']['label'] = 'Molokai, HI'
# J.P. Morgan ? - 2001Q2
master['PHILIPSBURG CURACAO, BONAIRE, SABA, ST. MARTIN & ST.'] = {'label': 'Philipsburg, Sint Maarten', 'lat': 18.0289033, 'lng': -63.0561859}
# PNC idrssd 4479538 2012-12-31 -- present; see https://en.datocapital.com/ky/companies/Spartan-Iv-Divpep-Iv-Offshore-Holdings-%28Cayman%29-Lp.html
master['PLAINSBORO CAYMAN ISLANDS'] = {'label': 'George Town, Cayman Islands', 'lat': 19.2869323, 'lng': -81.3674389}
master['RIYADH SAUDI ARABIA']['label'] = 'Riyadh, Saudi Arabia'
master['SINGAPORE JAPAN'] = {'label': 'Singapore', 'lat': 1.3520830, 'lng': 103.8198360}
master['ST. HELIER ENGLAND'] = {'label': 'St Helier, Jersey', 'lat': 49.1805019, 'lng': -2.1032330}
master['TAIPEI HSIEN TAIWAN'] = {'label': 'Taipei, Taiwan', 'lat': 25.0329694, 'lng': 121.5654177}
master['TOKYO SINGAPORE'] = {'label': 'Tokyo, Japan', 'lat': 35.6894875, 'lng': 139.6917064}
master['VAIDEN MO'] = {'label': 'Vaiden, MS', 'lat': 33.3297337, 'lng': -89.7931781}
master['WANCHAI CHINA, PEOPLES REPUBLIC OF'] = {'label': 'Wan Chai, Hong Kong', 'lat': 22.2760220, 'lng': 114.1751471}
# Citigroup idrssd 1951350 ? - 2001q2
master['ZOETERMEER NETHERLAN DS ANTILLES'] = {'label': 'Zoetermeer, Netherlands', 'lat': 52.0621451, 'lng': 4.4165747}

pickle.dump(master, open('../app/LocationMaster', 'wb+'))

pd.DataFrame.from_dict(master, orient='index').to_csv('../data/LocationMaster.csv')



