import urllib.request,urllib.parse,json,time,sys
def sug(q):
    u='https://suggestqueries.google.com/complete/search?client=firefox&hl=de&gl=de&q='+urllib.parse.quote(q)
    try: return json.loads(urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=15).read().decode('utf-8','replace'))[1]
    except Exception as e: return []
seeds={
 'Fragen':[f'{w} kaffeevollautomat' for w in ['wie','was','warum','wann','wo','kann','lohnt sich','welcher']]+['kaffeevollautomat macht','kaffeevollautomat zeigt','kaffeevollautomat defekt','kaffeevollautomat tropft','kaffeevollautomat kein'],
 'Reparatur lokal':['kaffeevollautomat reparatur','kaffeemaschine reparatur','kaffeevollautomat reparatur hofheim','kaffeevollautomat reparatur wiesbaden','kaffeevollautomat reparatur frankfurt','kaffeevollautomat reparatur mainz','kaffeevollautomat reparatur kosten','kaffeevollautomat reparatur in der nähe','kaffeevollautomat werkstatt'],
 'Marken Reparatur':[f'{b} reparatur' for b in ['jura','siemens kaffeevollautomat','delonghi','philips kaffeevollautomat','saeco','nivona','melitta kaffeevollautomat','krups kaffeevollautomat','bosch kaffeevollautomat']],
 'Jura':['jura fehlermeldung','jura entkalken','jura service','jura wartung','jura e8','jura z10','jura reinigen','jura brühgruppe','jura milchsystem reinigen'],
 'Pflege':['kaffeevollautomat entkalken','kaffeevollautomat reinigen','kaffeevollautomat brühgruppe','kaffeevollautomat wasserfilter','kaffeevollautomat milchschaum'],
}
for g,qs in seeds.items():
    print('\n##',g)
    seen=set()
    for q in qs:
        r=[x for x in sug(q) if x not in seen][:8]; seen.update(r)
        if r: print(f' {q}: '+' | '.join(r))
        time.sleep(.4)
