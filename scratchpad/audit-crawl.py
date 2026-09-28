# Go-live-Audit: durchlaeuft alle veroeffentlichten Seiten/Produkte/Kategorien und prueft HTML, Links, Bilder, Platzhalter.
# Zugangsdaten werden aus der .env gelesen und NIE ausgegeben.
import re, json, sys, base64, urllib.request, urllib.error, concurrent.futures as cf
from html.parser import HTMLParser
from urllib.parse import urljoin, urlparse

ENV = {}
for line in open(r'C:\Homepage\Neue Seite 2026\kaffeetechniker-integration.env', encoding='utf-8-sig'):
    m = re.match(r'\s*([^#=]+?)\s*=\s*(.*)', line)
    if m: ENV[m.group(1)] = m.group(2).strip().strip('"')
BASE = ENV['WP_URL'].rstrip('/')
AUTH = 'Basic ' + base64.b64encode(f"{ENV['WP_APP_USER']}:{ENV['WP_APP_PASSWORD'].replace(' ','')}".encode()).decode()
UA = {'User-Agent': 'Mozilla/5.0 (audit)'}

def get(url, auth=False, timeout=30, method='GET'):
    h = dict(UA)
    if auth: h['Authorization'] = AUTH
    req = urllib.request.Request(url, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read(), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, b'', dict(e.headers or {})
    except Exception as e:
        return 0, str(e).encode(), {}

def rest_all(path, fields):
    out, page = [], 1
    while True:
        st, body, hd = get(f"{BASE}/wp-json/{path}{'&' if '?' in path else '?'}per_page=100&page={page}&_fields={fields}", auth=True)
        if st != 200: break
        data = json.loads(body)
        if isinstance(data, dict) and 'value' in data: data = data['value']
        out += data
        if len(data) < 100: break
        page += 1
    return out

urls = {BASE + '/': 'start'}
for p in rest_all('wp/v2/pages?status=publish', 'id,link,slug'): urls[p['link']] = 'page:' + p['slug']
for p in rest_all('wc/v3/products?status=publish', 'id,permalink,sku'): urls[p['permalink']] = 'product:' + str(p['sku'])
for c in rest_all('wc/v3/products/categories?', 'id,slug,count'):
    urls[f"{BASE}/product-category/{c['slug']}/"] = 'cat:' + c['slug']
urls[BASE + '/shop/'] = 'shop'; urls[BASE + '/cart/'] = 'cart'; urls[BASE + '/checkout/'] = 'checkout'; urls[BASE + '/my-account/'] = 'account'
urls[BASE + '/sitemap.xml'] = 'sitemap'; urls[BASE + '/robots.txt'] = 'robots'
print(f"{len(urls)} URLs im Umfang", file=sys.stderr)

class P(HTMLParser):
    def __init__(s): super().__init__(); s.links=[]; s.imgs=[]; s.h1=0; s.title=''; s.intitle=False; s.meta={}; s.canon=None; s.lang=None; s.viewport=None
    def handle_starttag(s, t, a):
        a = dict(a)
        if t == 'a' and a.get('href'): s.links.append(a['href'])
        elif t == 'img': s.imgs.append(a.get('src') or a.get('data-src') or '')
        elif t == 'h1': s.h1 += 1
        elif t == 'title': s.intitle = True
        elif t == 'html': s.lang = a.get('lang')
        elif t == 'meta':
            n = (a.get('name') or a.get('property') or '').lower()
            if n: s.meta[n] = a.get('content', '')
        elif t == 'link' and a.get('rel') == 'canonical' or (t == 'link' and 'canonical' in (a.get('rel') or '')): s.canon = a.get('href')
    def handle_data(s, d):
        if s.intitle: s.title += d
    def handle_endtag(s, t):
        if t == 'title': s.intitle = False

PLACEHOLDER = re.compile(r'\[TODO\]|TODO|Lorem ipsum|Platzhalter|XXX|Beispielstra|Musterstra|musterfirma|example\.com|hier einf', re.I)
ENGLISH = re.compile(r'\b(Add to cart|Read more|Order details|Shipping address|Billing address|Continue shopping|Proceed to|Your cart|Login|Lost your password|Sample Page|Hello world|Uncategorized|Just another WordPress)\b')

def audit(item):
    url, kind = item
    st, body, hd = get(url)
    r = dict(url=url, kind=kind, status=st, bytes=len(body), issues=[])
    if st != 200:
        r['issues'].append(f'HTTP {st}'); return r, [], []
    if kind in ('sitemap', 'robots'):
        r['text'] = body.decode('utf-8', 'ignore')[:600]; return r, [], []
    html = body.decode('utf-8', 'ignore')
    p = P(); p.feed(html)
    robots = p.meta.get('robots', '')
    r.update(title=p.title.strip()[:90], robots=robots, canonical=p.canon, lang=p.lang, viewport=bool(p.meta.get('viewport')), h1=p.h1, imgs=len(p.imgs), links=len(p.links), desc=bool(p.meta.get('description')))
    if 'noindex' in robots.lower(): r['issues'].append('noindex')
    if p.h1 == 0: r['issues'].append('kein H1')
    if p.h1 > 1: r['issues'].append(f'{p.h1}x H1')
    if not p.title.strip(): r['issues'].append('kein Title')
    if not p.meta.get('description'): r['issues'].append('keine Meta-Description')
    txt = re.sub(r'<script.*?</script>|<style.*?</style>', ' ', html, flags=re.S)
    txt = re.sub(r'<[^>]+>', ' ', txt)
    for m in PLACEHOLDER.finditer(txt): r['issues'].append('Platzhalter: ' + txt[max(0, m.start()-30):m.end()+30].strip().replace('\n', ' ')); break
    for m in ENGLISH.finditer(txt): r['issues'].append('Englisch: ' + m.group(0)); break
    r['abs_new'] = html.count('new.kaffeetechniker.de')
    r['http_res'] = len(re.findall(r'(?:src|href)=["\']http://(?!www\.w3\.org)', html))
    if r['http_res']: r['issues'].append(f"{r['http_res']}x http:// Ressourcen (Mixed Content)")
    imgs = [urljoin(url, i) for i in p.imgs if i and not i.startswith('data:')]
    links = [urljoin(url, l) for l in p.links if l and not l.startswith(('mailto:', 'tel:', 'javascript:', '#', 'sms:', 'whatsapp:'))]
    return r, imgs, links

results, allimgs, alllinks = [], {}, {}
with cf.ThreadPoolExecutor(8) as ex:
    for r, imgs, links in ex.map(audit, urls.items()):
        results.append(r)
        for i in imgs: allimgs.setdefault(i, set()).add(r['url'])
        for l in links: alllinks.setdefault(l.split('#')[0], set()).add(r['url'])

# interne Links + alle Bilder pruefen (HEAD, Fallback GET)
host = urlparse(BASE).netloc
internal = [l for l in alllinks if urlparse(l).netloc == host]
external = sorted({l for l in alllinks if urlparse(l).netloc != host})
def check(u):
    st, _, hd = get(u, method='HEAD', timeout=20)
    if st in (0, 403, 405, 400): st, _, hd = get(u, timeout=25)
    return u, st, hd.get('Location', '')
broken_links, redirect_links, broken_imgs = [], [], []
with cf.ThreadPoolExecutor(10) as ex:
    for u, st, loc in ex.map(check, internal):
        if st >= 400 or st == 0: broken_links.append((u, st, sorted(alllinks[u])[:3]))
    for u, st, loc in ex.map(check, list(allimgs)):
        if st >= 400 or st == 0: broken_imgs.append((u, st, sorted(allimgs[u])[:3]))
ext_status = []
with cf.ThreadPoolExecutor(8) as ex:
    for u, st, loc in ex.map(check, external):
        if st >= 400 or st == 0: ext_status.append((u, st, sorted(alllinks[u])[:2]))

out = dict(results=results, broken_links=broken_links, broken_imgs=broken_imgs, external_total=len(external), external_bad=ext_status, external_list=external)
json.dump(out, open(r'C:\Users\info\AppData\Local\Temp\claude\C--Homepage-Neue-Seite-2026\42d494fc-f1fc-4de4-9612-1a5647f9ea02\scratchpad\audit-result.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print("fertig", len(results))
