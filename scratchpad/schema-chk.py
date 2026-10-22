import re,json,urllib.request,html
def jl(u):
    h=urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=30).read().decode('utf-8','replace')
    out=[]
    for m in re.findall(r'<script[^>]*application/ld\+json[^>]*>(.*?)</script>',h,re.S):
        try:
            d=json.loads(m)
        except Exception as e:
            out.append(('PARSEFEHLER',str(e)));continue
        items=d.get('@graph',[d]) if isinstance(d,dict) else d
        out+= [(i.get('@type'),i) for i in items]
    return out
def need(i,keys): return [k for k in keys if not i.get(k)]
for u in ['https://kaffeetechniker.de/','https://kaffeetechniker.de/product/jura-e8-ed-piano-black/','https://kaffeetechniker.de/product/jura-care-kit/','https://kaffeetechniker.de/hilfe-stoerungen/','https://kaffeetechniker.de/stoerung-kein-wasser/','https://kaffeetechniker.de/anfahrt/']:
    print('\n==',u)
    for t,i in jl(u):
        if t=='PARSEFEHLER': print('  JSON-Fehler',i);continue
        tt=t if isinstance(t,str) else ','.join(t)
        extra=''
        if 'Product' in tt:
            o=i.get('offers'); o=o[0] if isinstance(o,list) else (o or {})
            extra=f" fehlt:{need(i,['name','image','description','sku','brand'])} offers:{need(o,['price','priceCurrency','availability'])} rating={'ja' if i.get('aggregateRating') else 'nein'} returnPolicy={'ja' if o.get('hasMerchantReturnPolicy') else 'nein'} shipping={'ja' if o.get('shippingDetails') else 'nein'}"
        if 'LocalBusiness' in tt or 'Store' in tt or 'Repair' in tt:
            extra=f" fehlt:{need(i,['name','address','telephone','openingHoursSpecification','geo','image','url','priceRange','sameAs'])}"
        if tt=='FAQPage': extra=f" fragen={len(i.get('mainEntity',[]))}"
        print('  ',tt,extra)
