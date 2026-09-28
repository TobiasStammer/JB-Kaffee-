# Go-live-Audit: WooCommerce/WordPress-Einstellungen, Produkte, Steuern, Versand, Zahlarten. Zugangsdaten werden nie ausgegeben.
import re, json, base64, urllib.request, urllib.error, collections
ENV = {}
for line in open(r'C:\Homepage\Neue Seite 2026\kaffeetechniker-integration.env', encoding='utf-8-sig'):
    m = re.match(r'\s*([^#=]+?)\s*=\s*(.*)', line)
    if m: ENV[m.group(1)] = m.group(2).strip().strip('"')
BASE = ENV['WP_URL'].rstrip('/'); pw = ENV['WP_APP_PASSWORD'].replace(' ', '')
AUTH = 'Basic ' + base64.b64encode(f"{ENV['WP_APP_USER']}:{pw}".encode()).decode()
def get(path):
    req = urllib.request.Request(f"{BASE}/wp-json/{path}", headers={'Authorization': AUTH, 'User-Agent': 'audit'})
    try:
        with urllib.request.urlopen(req, timeout=60) as r: d = json.loads(r.read().decode('utf-8', 'ignore'))
    except urllib.error.HTTPError as e: return {'_error': e.code}
    except Exception as e: return {'_error': str(e)[:80]}
    return d['value'] if isinstance(d, dict) and 'value' in d and 'Count' in d else d
def allp(path, fields):
    out, pg = [], 1
    while True:
        d = get(f"{path}{'&' if '?' in path else '?'}per_page=100&page={pg}&_fields={fields}")
        if not isinstance(d, list): break
        out += d
        if len(d) < 100: break
        pg += 1
    return out
S = {}
print("=== WordPress ===")
s = get('wp/v2/settings'); print({k: s.get(k) for k in ('title','description','url','email','timezone','language','date_format','default_comment_status','default_ping_status','show_on_front','page_on_front')})
print("\n=== System (WooCommerce system_status) ===")
ss = get('wc/v3/system_status')
env = ss.get('environment', {}); print({k: env.get(k) for k in ('site_url','home_url','wp_version','php_version','mysql_version','wp_memory_limit','secure_connection','hide_errors','language','default_timezone')})
print("Theme:", {k: ss.get('theme', {}).get(k) for k in ('name','version','is_child_theme','has_woocommerce_support')})
print("\nPlugins (aktiv) mit Update-Hinweis:")
for p in ss.get('active_plugins', []):
    up = p.get('version_latest'); flag = '  <-- UPDATE ' + str(up) if up and up != p.get('version') else ''
    print(f"  {p['name'][:42]:42} {p.get('version')}{flag}")
print("Inaktive Plugins:", [ (p.get('name'), p.get('version')) for p in ss.get('inactive_plugins', [])])
print("Seiten-Status:", {k: (v.get('page_set'), v.get('shortcode_present') or v.get('block_present')) for k, v in ss.get('pages', {}).items()} if isinstance(ss.get('pages'), dict) else [ (p.get('page_name'), p.get('page_set'), p.get('shortcode_present') or p.get('block_present')) for p in ss.get('pages', [])])
print("\n=== Shop-Grundeinstellungen ===")
gen = {x['id']: x.get('value') for x in get('wc/v3/settings/general') if isinstance(x, dict)}
for k in ('woocommerce_store_address','woocommerce_store_postcode','woocommerce_store_city','woocommerce_default_country','woocommerce_allowed_countries','woocommerce_specific_allowed_countries','woocommerce_ship_to_countries','woocommerce_calc_taxes','woocommerce_currency','woocommerce_currency_pos','woocommerce_price_num_decimals','woocommerce_coming_soon','woocommerce_enable_coupons'):
    print(f"  {k}: {gen.get(k)}")
tax = {x['id']: x.get('value') for x in get('wc/v3/settings/tax') if isinstance(x, dict)}
for k in ('woocommerce_prices_include_tax','woocommerce_tax_based_on','woocommerce_tax_display_shop','woocommerce_tax_display_cart','woocommerce_tax_total_display','woocommerce_price_display_suffix'):
    print(f"  {k}: {tax.get(k)}")
print("Steuerklassen:", [(c['slug'], c['name']) for c in get('wc/v3/taxes/classes')])
print("Steuersaetze:", [(t['class'], t['rate'], t['country'], t['name']) for t in get('wc/v3/taxes?per_page=50')])
print("\n=== Zahlarten ===")
for g in get('wc/v3/payment_gateways'):
    st = g.get('settings', {}) or {}
    test = {k: (v.get('value') if isinstance(v, dict) else v) for k, v in st.items() if re.search(r'test|sandbox|dev_?mode|live', k, re.I)}
    print(f"  {'AN ' if g.get('enabled') else 'aus'} {g['id']:28} {(g.get('title') or '')[:34]:34} {test if test else ''}")
print("\n=== Versand ===")
for z in get('wc/v3/shipping/zones'):
    ms = get(f"wc/v3/shipping/zones/{z['id']}/methods"); locs = [l['code'] for l in get(f"wc/v3/shipping/zones/{z['id']}/locations")][:6]
    print(f"  Zone {z['id']} '{z['name']}' Orte={locs}")
    for m in ms if isinstance(ms, list) else []:
        cost = m.get('settings', {}).get('cost', {}).get('value') if isinstance(m.get('settings', {}).get('cost'), dict) else ''
        print(f"     {'AN ' if m.get('enabled') else 'aus'} {m['method_id']:14} {m.get('title')} cost='{cost}'")
print("Versandklassen:", [(c['slug'], c['count']) for c in get('wc/v3/products/shipping_classes')])
print("\n=== Produkte ===")
prods = allp('wc/v3/products?status=any', 'id,name,sku,status,type,regular_price,sale_price,stock_status,manage_stock,stock_quantity,tax_class,tax_status,shipping_class,weight,images,categories,catalog_visibility,purchasable,backorders,short_description')
print("gesamt:", len(prods), "| Status:", dict(collections.Counter(p['status'] for p in prods)), "| Typ:", dict(collections.Counter(p['type'] for p in prods)))
pub = [p for p in prods if p['status'] == 'publish']
def row(p): return f"{p['id']} {p['name'][:44]}"
chk = {
 'Preis 0/leer (nicht extern)': [p for p in pub if p['type'] != 'external' and not (p['regular_price'] and float(p['regular_price']) > 0)],
 'nicht vorraetig (outofstock)': [p for p in pub if p['stock_status'] == 'outofstock'],
 'auf Bestellung (onbackorder)': [p for p in pub if p['stock_status'] == 'onbackorder'],
 'ohne Bild': [p for p in pub if not p['images']],
 'ohne SKU': [p for p in pub if not p['sku']],
 'ohne Versandklasse (nicht extern)': [p for p in pub if p['type'] != 'external' and not p['shipping_class']],
 'ohne Gewicht (nicht extern)': [p for p in pub if p['type'] != 'external' and not p['weight']],
 'ohne Kurzbeschreibung': [p for p in pub if not (p.get('short_description') or '').strip()],
 'Sonderpreis gesetzt': [p for p in pub if p.get('sale_price')],
 'Katalog unsichtbar': [p for p in pub if p['catalog_visibility'] != 'visible'],
 'Lager verwaltet': [p for p in pub if p['manage_stock']],
}
for k, v in chk.items():
    print(f"  {k}: {len(v)}" + (f"   z.B. {[row(p) for p in v[:4]]}" if v and len(v) <= 40 else ''))
print("Steuerklassen der Produkte:", dict(collections.Counter((p['tax_class'] or 'standard') for p in pub)))
for p in pub:
    if (p['tax_class'] or '') != '' or any(c['slug'] in ('kaffee', 'tee') for c in p['categories']):
        print(f"    Steuer: {row(p)} | Klasse '{p['tax_class']}' | Kat {[c['slug'] for c in p['categories']]}")
print("Nicht veroeffentlicht:", [(row(p), p['status']) for p in prods if p['status'] != 'publish'][:20])
print("\n=== Mails ===")
for gid in ('email','email_new_order','email_customer_processing_order','email_customer_completed_order','email_customer_on_hold_order','email_customer_new_account','email_customer_reset_password','email_customer_refunded_order','email_customer_invoice','email_customer_note','email_failed_order','email_cancelled_order'):
    items = get(f'wc/v3/settings/{gid}')
    if isinstance(items, list):
        d = {x['id']: x.get('value') for x in items if isinstance(x, dict)}
        keep = {k: v for k, v in d.items() if k in ('enabled','recipient','woocommerce_email_from_name','woocommerce_email_from_address','woocommerce_email_footer_text','subject')}
        print(f"  {gid}: {keep}")
print("\n=== Konto/Datenschutz ===")
for x in get('wc/v3/settings/account'):
    if x['id'] in ('woocommerce_enable_guest_checkout','woocommerce_enable_myaccount_registration','woocommerce_enable_signup_and_login_from_checkout','woocommerce_registration_generate_password'): print(f"  {x['id']}: {x.get('value')}")
print("Seiten: AGB-Seite (Terms)=", s.get('woocommerce_terms_page_id') if isinstance(s, dict) else None)
