import re, json, base64, urllib.request, time
ENV = {}
for line in open(r'C:\Homepage\Neue Seite 2026\kaffeetechniker-integration.env', encoding='utf-8-sig'):
    m = re.match(r'\s*([^#=]+?)\s*=\s*(.*)', line)
    if m: ENV[m.group(1)] = m.group(2).strip().strip('"')
BASE = ENV['WP_URL'].rstrip('/'); AUTH = 'Basic ' + base64.b64encode(f"{ENV['WP_APP_USER']}:{ENV['WP_APP_PASSWORD'].replace(' ','')}".encode()).decode()
def get(p):
    for i in range(5):
        try:
            d = json.loads(urllib.request.urlopen(urllib.request.Request(f"{BASE}/wp-json/{p}", headers={'Authorization': AUTH, 'User-Agent': 'a'}), timeout=60).read().decode('utf-8','ignore'))
            return d['value'] if isinstance(d, dict) and 'value' in d and 'Count' in d else d
        except Exception as e: time.sleep(25)
    raise SystemExit("weiter 503")
print("Bewertungen:", next(x['value'] for x in get('wc/v3/settings/products') if x['id'] == 'woocommerce_enable_reviews'))
for st in ('draft', 'pending', 'private'):
    for p in get(f'wc/v3/products?status={st}&per_page=50&_fields=id,name,status,sku,date_created'): print(st, p['id'], p['sku'], p['name'].encode('ascii','replace').decode(), p['date_created'])
print("Papierkorb:", [(p['id'], p['name'][:30].encode('ascii','replace').decode()) for p in get('wc/v3/products?status=trash&per_page=50&_fields=id,name')])
