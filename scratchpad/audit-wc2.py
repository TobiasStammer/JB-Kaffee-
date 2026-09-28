import re, json, base64, urllib.request, urllib.error, html
ENV = {}
for line in open(r'C:\Homepage\Neue Seite 2026\kaffeetechniker-integration.env', encoding='utf-8-sig'):
    m = re.match(r'\s*([^#=]+?)\s*=\s*(.*)', line)
    if m: ENV[m.group(1)] = m.group(2).strip().strip('"')
BASE = ENV['WP_URL'].rstrip('/'); pw = ENV['WP_APP_PASSWORD'].replace(' ', '')
AUTH = 'Basic ' + base64.b64encode(f"{ENV['WP_APP_USER']}:{pw}".encode()).decode()
def get(path, raw=False):
    req = urllib.request.Request(path if path.startswith('http') else f"{BASE}/wp-json/{path}", headers={'Authorization': AUTH, 'User-Agent': 'audit'})
    with urllib.request.urlopen(req, timeout=60) as r: b = r.read().decode('utf-8', 'ignore')
    if raw: return b
    d = json.loads(b); return d['value'] if isinstance(d, dict) and 'value' in d and 'Count' in d else d
print("=== Nicht vorraetig (veroeffentlicht) ===")
for p in get('wc/v3/products?status=publish&stock_status=outofstock&per_page=100&_fields=id,name,sku,regular_price,categories'):
    print(f"  {p['id']} | {p['sku']:18} | {p['regular_price']:>8} | {html.unescape(p['name'])}")
print("\n=== Versandkosten Zone DE (flat_rate) ===")
for m in get('wc/v3/shipping/zones/1/methods'):
    if m['method_id'] in ('flat_rate', 'free_shipping'):
        st = {k: (v.get('value') if isinstance(v, dict) else v) for k, v in m['settings'].items()}
        print(f"  {m['method_id']}: " + json.dumps({k: v for k, v in st.items() if v not in ('', None)}, ensure_ascii=False))
print("\n=== Kommentare/Bewertungen ===")
s = get('wp/v2/settings'); print("  default_comment_status:", s.get('default_comment_status'), "| ping:", s.get('default_ping_status'))
pr = {x['id']: x.get('value') for x in get('wc/v3/settings/products') if isinstance(x, dict)}
print("  Produktbewertungen:", pr.get('woocommerce_enable_reviews'), "| nur verifizierte Kaeufer:", pr.get('woocommerce_review_rating_verification_required'))
print("  Kommentare auf Seiten offen:", sum(1 for p in get('wp/v2/pages?per_page=100&_fields=id,comment_status') if p.get('comment_status') == 'open'), "von", len(get('wp/v2/pages?per_page=100&_fields=id')))
print("  Beitraege:", len(get('wp/v2/posts?per_page=20&status=any&_fields=id,title,status,slug')), [ (p['slug'], p['status']) for p in get('wp/v2/posts?per_page=20&status=any&_fields=id,slug,status')])
print("\n=== Impressum-Angaben (live) ===")
imp = get('wp/v2/pages?slug=impressum&_fields=content')[0]['content']['rendered']
t = html.unescape(re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', re.sub(r'<style.*?</style>', ' ', imp, flags=re.S))))
for k in ('HRB', 'Amtsgericht', 'Gesch', 'USt', 'Steuernummer', 'Handwerkskammer', 'Verbraucherstreit', 'OS-Plattform', 'ec.europa.eu', 'E-Mail', 'Telefon'):
    for m in re.finditer(k, t):
        print(f"  [{k}] ...{t[max(0, m.start()-40):m.start()+130]}..."); break
