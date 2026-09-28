import re, json, base64, urllib.request, sys, time
APPLY = '--apply' in sys.argv
ENV = {}
for line in open(r'C:\Homepage\Neue Seite 2026\kaffeetechniker-integration.env', encoding='utf-8-sig'):
    m = re.match(r'\s*([^#=]+?)\s*=\s*(.*)', line)
    if m: ENV[m.group(1)] = m.group(2).strip().strip('"')
BASE = ENV['WP_URL'].rstrip('/'); AUTH = 'Basic ' + base64.b64encode(f"{ENV['WP_APP_USER']}:{ENV['WP_APP_PASSWORD'].replace(' ','')}".encode()).decode()
def call(method, path, data=None):
    for i in range(5):
        try:
            req = urllib.request.Request(f"{BASE}/wp-json/{path}", data=(json.dumps(data).encode() if data is not None else None), method=method, headers={'Authorization': AUTH, 'User-Agent': 'Mozilla/5.0', 'Content-Type': 'application/json'})
            d = json.loads(urllib.request.urlopen(req, timeout=90).read().decode('utf-8', 'ignore')); return d['value'] if isinstance(d, dict) and 'value' in d and 'Count' in d else d
        except Exception as e:
            if i == 4: raise
            time.sleep(20)
backup = {}
# 1) Produkte
prods = call('GET', 'wc/v3/products?status=any&per_page=100&_fields=id,name,short_description,description')
n = 0
for p in prods:
    s, d = p['short_description'], p['description']
    if 'Preis auf Anfrage' not in s + d: continue
    s2 = re.sub(r'\s*Preis auf Anfrage\s*(?:&ndash;|–|-)\s*', ' ', s)
    d2 = re.sub(r'(<h2[^>]*>)\s*Preis auf Anfrage\s*(</h2>)', r'\1Beratung und Angebot\2', d)
    if (s2, d2) != (s, d):
        backup[f"product:{p['id']}"] = {'short_description': s, 'description': d}
        n += 1
        if APPLY: call('PUT', f"wc/v3/products/{p['id']}", {'short_description': s2, 'description': d2})
    rest = 'Preis auf Anfrage' in s2 + d2
    if rest: print("   Rest in Produkt", p['id'], p['name'][:30].encode('ascii','replace').decode())
print("Produkte geaendert:", n)
# 2) Seiten
pages = call('GET', 'wp/v2/pages?per_page=100&status=any&context=edit&_fields=id,slug,content')
for p in pages:
    c = p['content']['raw']; c2 = c
    if 'Preis auf Anfrage' in c:
        c2 = re.sub(r'\s*Preis auf Anfrage\.', '', c2)                       # "... am Tag. Preis auf Anfrage." -> "... am Tag."
        c2 = re.sub(r'Preis auf Anfrage:\s*Wir konfigurieren', 'Wir konfigurieren', c2)   # "Tag. Preis auf Anfrage: Wir ..." -> "Tag. Wir ..."
        print(f"Seite {p['slug']}: 'Preis auf Anfrage' {c.count('Preis auf Anfrage')}x -> {c2.count('Preis auf Anfrage')}x")
    if p['slug'] == 'impressum':
        c2 = re.sub(r'Die Europ.{1,8}ische Kommission stellt eine Plattform zur Online-Streitbeilegung \(OS\) bereit: <a href="https://ec\.europa\.eu/consumers/odr/?">[^<]*</a>\.\s*Unsere E-Mail-Adresse finden Sie oben\.\s*', '', c2)
        print("Impressum: OS-Satz entfernt:", 'consumers/odr' not in c2, "| Rest:", re.search(r'<h2[^>]*>Streitbeilegung</h2>\s*<p>(.{0,120})', c2, re.S).group(1))
    if c2 != c:
        backup[f"page:{p['id']}"] = {'content': c}
        if APPLY: call('PUT', f"wp/v2/pages/{p['id']}", {'content': c2})
    if 'consumers/odr' in c2 and p['slug'] != 'impressum': print("   Hinweis: OS-Link noch in Seite", p['slug'])
json.dump(backup, open('fix-texte-backup.json', 'w', encoding='utf-8'), ensure_ascii=False)
print("Backup-Eintraege:", len(backup), "| angewendet:", APPLY)
