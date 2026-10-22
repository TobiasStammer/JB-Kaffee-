import re,json,urllib.request,concurrent.futures as cf,html
rows=json.load(open('seo-crawl.json',encoding='utf-8'))
urls=[r['url'] for r in rows if '/product/' not in r['url']]
def tx(u):
    h=urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=30).read().decode('utf-8','replace')
    h=re.sub(r'<(script|style)[\s\S]*?</\1>',' ',h); return u,html.unescape(re.sub('<[^>]+>',' ',h)).lower()
with cf.ThreadPoolExecutor(6) as ex: T=dict(ex.map(tx,urls))
terms=['essig','zitronensäure','siemens','delonghi','de\'longhi','philips','saeco','melitta','krups','bosch','nivona','miele','wmf','festpreis','pauschal','reinigen lassen','in der nähe','wiesbaden','frankfurt','mainz','bohnen füllen','tropft','crema','geräusch','laut','grundstellung','milchschaum','fehlermeldung','system wird gefüllt','kakao','kosten','kaufberatung','wasserhärte','cold brew','e8','z10','siebträger']
print('Begriff -> Seiten (Anzahl) / wichtigste')
for t in terms:
    hits=[(u.replace('https://kaffeetechniker.de',''),x.count(t)) for u,x in T.items() if t in x]
    hits.sort(key=lambda a:-a[1])
    print(f'{t:20} {len(hits):3}  ',', '.join(f'{u}({n})' for u,n in hits[:3]))
