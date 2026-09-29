import re, json, base64, urllib.request, html, collections
ENV = {}
for line in open(r'C:\Homepage\Neue Seite 2026\kaffeetechniker-integration.env', encoding='utf-8-sig'):
    m = re.match(r'\s*([^#=]+?)\s*=\s*(.*)', line)
    if m: ENV[m.group(1)] = m.group(2).strip().strip('"')
BASE = ENV['WP_URL'].rstrip('/')
def get(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1)'})
    return urllib.request.urlopen(req, timeout=30).read().decode('utf-8', 'ignore')

def check(url):
    h = get(url)
    title = re.search(r'<title>(.*?)</title>', h, re.S)
    desc = re.search(r'<meta name="description" content="([^"]*)"', h)
    h1s = re.findall(r'<h1[^>]*>(.*?)</h1>', h, re.S)
    canon = re.search(r'<link rel="canonical" href="([^"]*)"', h)
    robots = re.search(r'<meta name="robots" content="([^"]*)"', h)
    jsonld = re.findall(r'<script type="application/ld\+json">(.*?)</script>', h, re.S)
    types = []
    for j in jsonld:
        try:
            d = json.loads(j)
            items = d if isinstance(d, list) else [d]
            for it in items:
                if isinstance(it, dict):
                    t = it.get('@type')
                    if isinstance(t, list): types += t
                    elif t: types.append(t)
                    if '@graph' in it:
                        for g in it['@graph']:
                            gt = g.get('@type') if isinstance(g, dict) else None
                            if isinstance(gt, list): types += gt
                            elif gt: types.append(gt)
        except Exception: pass
    return dict(
        title=html.unescape(title.group(1)).strip() if title else None,
        title_len=len(html.unescape(title.group(1)).strip()) if title else 0,
        desc=html.unescape(desc.group(1)).strip() if desc else None,
        desc_len=len(html.unescape(desc.group(1)).strip()) if desc else 0,
        h1_count=len(h1s), h1=[html.unescape(re.sub('<[^>]+>','',x)).strip() for x in h1s],
        canonical=canon.group(1) if canon else None, robots=robots.group(1) if robots else None,
        schema_types=types,
    )

pages = ['/', '/reparatur/', '/wartung/', '/marken/', '/ueber-uns/', '/kontakt/', '/anfahrt/', '/jura/', '/my-account/', '/product/jura-glacette/']
for p in pages:
    d = check(BASE + p)
    print(f"=== {p} ===")
    print(f"  Title ({d['title_len']}): {d['title']}")
    print(f"  Desc  ({d['desc_len']}): {d['desc']}")
    print(f"  H1 ({d['h1_count']}): {d['h1']}")
    print(f"  Canonical: {d['canonical']} | robots: {d['robots']}")
    print(f"  Schema: {d['schema_types']}")
