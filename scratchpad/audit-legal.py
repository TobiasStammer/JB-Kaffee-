import re, json, html, urllib.request, collections
from urllib.parse import urlparse
BASE = 'https://new.kaffeetechniker.de'
def page(path):
    req = urllib.request.Request(BASE + path, headers={'User-Agent': 'Mozilla/5.0 (audit)'})
    return urllib.request.urlopen(req, timeout=60).read().decode('utf-8', 'ignore')
def text(h):
    h = re.sub(r'<script.*?</script>|<style.*?</style>', ' ', h, flags=re.S)
    return html.unescape(re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', h)))
print("=== Rechtstexte: Stichworte ===")
checks = {
 '/datenschutz/': ['PayPal','WooPayments','Stripe','Amazon Pay','Apple Pay','Google Pay','IONOS','Cookie','SSL','Kontaktformular','Google Maps','YouTube','WhatsApp','Wertgarantie','Aufsichtsbeh','Widerspruch','Speicherdauer','Auskunft','Drittland','FluentSMTP','Newsletter'],
 '/agb/': ['Vertragsschluss','Lieferung','Versandkosten','Zahlung','Eigentumsvorbehalt','Gewährleistung','Abholung','Preise','Vorkasse','PayPal','Widerruf','Datenschutz','Salvatorische','Inseln','Stand'],
 '/widerruf/': ['Widerrufsrecht','14 Tage','Muster-Widerrufsformular','Folgen des Widerrufs','Rücksendung','Kosten','Ausnahmen','Wertersatz'],
 '/impressum/': ['Streitbeilegung','odr','Handwerkskammer','Berufsbezeichnung','Umsatzsteuer'],
}
for p, kws in checks.items():
    t = text(page(p)); low = t.lower()
    miss = [k for k in kws if k.lower() not in low]
    print(f"  {p}: {len(t)} Zeichen | fehlt: {miss if miss else '-'}")
print("\n=== Produktseiten: Pflichtangaben (GPSR / Grundpreis) ===")
for path, label in (('/product/jura-z10-diamond-black/','Jura Maschine'), ('/product/nivona-nicr-5-50-schwarz/','Nivona Maschine'), ('/product/jura-glacette/','Zubehoer'), ('/product/jb-kaffee-caffe-crema-1000/','Kaffee'), ('/product/jb-tee-earl-grey/','Tee')):
    try: t = text(page(path))
    except Exception as e: print(f"  {label}: {path} -> {e}"); continue
    keys = {'Hersteller': 'hersteller' in t.lower(), 'Sicherheitshinweis': 'sicherheit' in t.lower(), 'Grundpreis (pro kg/100g)': bool(re.search(r'(pro|/|je)\s*(kg|100\s*g|1\s*kg)|Grundpreis', t, re.I)), 'Lieferzeit': 'lieferzeit' in t.lower(), 'inkl. MwSt': 'mwst' in t.lower(), 'zzgl. Versand': 'versand' in t.lower(), 'Zutaten/Allergene': bool(re.search(r'Zutaten|Allergen|Mindesthalt', t, re.I))}
    print(f"  {label:16} " + ', '.join(f"{k}={'ja' if v else 'NEIN'}" for k, v in keys.items()))
print("\n=== Drittanbieter-Verbindungen (Ressourcen ausserhalb der eigenen Domain) ===")
own = urlparse(BASE).netloc
pages = ['/','/reparatur/','/kaufen/' if False else '/kaffeemaschinen-kaufen/','/jura/','/product/jura-z10-diamond-black/','/cart/','/kontakt/','/anfahrt/','/wartung/','/wertgarantie/','/my-account/','/hilfethemen/']
dom = collections.defaultdict(set)
for p in pages:
    try: h = page(p)
    except Exception: continue
    for m in re.finditer(r'<(script|iframe|link|img|source|video|audio|form)\b[^>]*?(?:src|href|action|data-src)=["\']([^"\']+)', h, re.I):
        u = m.group(2)
        if u.startswith('//'): u = 'https:' + u
        n = urlparse(u).netloc
        if n and n != own and not u.startswith(('mailto:', 'tel:')): dom[n].add((m.group(1).lower(), p))
    for m in re.finditer(r'url\((["\']?)(https?://[^)"\']+)', h):
        n = urlparse(m.group(2)).netloc
        if n and n != own: dom[n].add(('css-url', p))
for d, s in sorted(dom.items()):
    kinds = sorted({k for k, _ in s}); pgs = sorted({p for _, p in s})
    print(f"  {d:40} {','.join(kinds):24} auf {len(pgs)} Seite(n): {pgs[:3]}")
