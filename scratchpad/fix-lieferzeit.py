import re, json, base64, urllib.request, sys, collections
APPLY = '--apply' in sys.argv
ENV = {}
for line in open(r'C:\Homepage\Neue Seite 2026\kaffeetechniker-integration.env', encoding='utf-8-sig'):
    m = re.match(r'\s*([^#=]+?)\s*=\s*(.*)', line)
    if m: ENV[m.group(1)] = m.group(2).strip().strip('"')
BASE = ENV['WP_URL'].rstrip('/'); AUTH = 'Basic ' + base64.b64encode(f"{ENV['WP_APP_USER']}:{ENV['WP_APP_PASSWORD'].replace(' ','')}".encode()).decode()
def call(method, path, data=None):
    req = urllib.request.Request(f"{BASE}/wp-json/{path}", data=(json.dumps(data).encode() if data is not None else None), method=method, headers={'Authorization': AUTH, 'User-Agent': 'audit', 'Content-Type': 'application/json'})
    d = json.loads(urllib.request.urlopen(req, timeout=90).read().decode('utf-8', 'ignore')); return d['value'] if isinstance(d, dict) and 'value' in d and 'Count' in d else d
prods, pg = [], 1
while True:
    d = call('GET', f'wc/v3/products?status=any&per_page=100&page={pg}&_fields=id,name,status,stock_status,attributes'); prods += d
    if len(d) < 100: break
    pg += 1
want = {460: '5-7 Tage', 458: '5-7 Tage', 444: '5-7 Tage', 442: '5-7 Tage', 456: '1-3 Tage', 454: '1-3 Tage'}
dist = collections.Counter(); todo = []
for p in prods:
    la = next((a for a in p['attributes'] if a.get('id') == 1), None)
    cur = la['options'] if la else None
    dist[str(cur)] += 1
    new = None
    if p['id'] in want: new = [want[p['id']]]
    elif la and len(cur) == 2 and cur[1] == 'Tage': new = [f"{cur[0]} Tage"]
    if new and (new != cur or (p['id'] in want and p['stock_status'] != 'instock')): todo.append((p, new))
print("Lieferzeit-Werte (Verteilung):", dict(dist))
print("Zu aendern:", len(todo), "| davon Bestand->instock:", sum(1 for p, _ in todo if p['id'] in want))
for p, n in todo[:6]: print(f"   {p['id']} {p['name'][:34]:34} {[a['options'] for a in p['attributes'] if a.get('id')==1]} -> {n}")
if APPLY:
    ok = 0
    for p, new in todo:
        attrs = []
        for a in p['attributes']:
            o = {'position': a['position'], 'visible': a['visible'], 'variation': a['variation'], 'options': (new if a.get('id') == 1 else a['options'])}
            if a.get('id'): o['id'] = a['id']
            else: o['name'] = a['name']
            attrs.append(o)
        body = {'attributes': attrs}
        if p['id'] in want: body['stock_status'] = 'instock'
        call('PUT', f"wc/v3/products/{p['id']}", body); ok += 1
    print("angewendet:", ok)
