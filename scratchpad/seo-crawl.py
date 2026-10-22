import re, json, time, urllib.request, urllib.parse, concurrent.futures as cf, html, csv, sys
BASE = 'https://kaffeetechniker.de'
UA = {'User-Agent': 'Mozilla/5.0 (seo-audit)'}

def get(url, timeout=30):
    t = time.time()
    req = urllib.request.Request(url, headers=UA)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            b = r.read(); return r.status, b.decode('utf-8', 'replace'), time.time() - t, r.headers, r.geturl()
    except urllib.error.HTTPError as e:
        return e.code, '', time.time() - t, e.headers, url
    except Exception as e:
        return 0, str(e), time.time() - t, {}, url

def locs(u):
    s, h, *_ = get(u)
    return re.findall(r'<loc>([^<]+)</loc>', h)

urls = []
for sm in locs(BASE + '/wp-sitemap.xml'):
    urls += locs(sm)
urls = sorted(set(urls))
print('URLs in Sitemap:', len(urls))

def audit(u):
    s, h, dt, hd, final = get(u)
    r = {'url': u, 'status': s, 'secs': round(dt, 2), 'final': final if final != u else ''}
    if s != 200: return r
    g = lambda p: (re.search(p, h, re.S | re.I) or [None, ''])[1]
    r['title'] = html.unescape(g(r'<title[^>]*>(.*?)</title>')).strip()
    r['desc'] = html.unescape(g(r'<meta name=["\']description["\'][^>]*content=["\']([^"\']*)'))
    r['canon'] = g(r'<link rel=["\']canonical["\'] href=["\']([^"\']*)')
    r['robots'] = g(r'<meta name=["\']robots["\'] content=["\']([^"\']*)')
    r['h1'] = len(re.findall(r'<h1[\s>]', h))
    r['h1txt'] = html.unescape(re.sub('<[^>]+>', '', g(r'<h1[^>]*>(.*?)</h1>'))).strip()[:80]
    body = re.sub(r'<(script|style)[\s\S]*?</\1>', ' ', h)
    r['words'] = len(re.sub('<[^>]+>', ' ', body).split())
    imgs = re.findall(r'<img\b[^>]*>', h)
    r['imgs'] = len(imgs)
    r['noalt'] = sum(1 for i in imgs if not re.search(r'\balt=["\'][^"\']+', i))
    r['schema'] = ','.join(sorted(set(re.findall(r'"@type"\s*:\s*"([A-Za-z]+)"', h))))
    r['og'] = 1 if 'og:title' in h else 0
    r['kb'] = round(len(h.encode()) / 1024)
    return r

with cf.ThreadPoolExecutor(6) as ex:
    rows = list(ex.map(audit, urls))
json.dump(rows, open(r'C:\Homepage\Neue Seite 2026\scratchpad\seo-crawl.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)

ok = [r for r in rows if r['status'] == 200]
print('Status != 200:', [(r['url'], r['status']) for r in rows if r['status'] != 200])
print('Weiterleitungen:', [(r['url'], r['final']) for r in rows if r.get('final')][:10])
def lst(name, cond, n=40):
    x = [r for r in ok if cond(r)]
    print(f'\n## {name}: {len(x)}')
    for r in x[:n]: print('  ', r['url'].replace(BASE, ''), '|', r.get('title', '')[:70] if 'Titel' in name else '')
lst('Titel fehlt/zu kurz (<20) oder zu lang (>65) [Titel]', lambda r: len(r['title']) < 20 or len(r['title']) > 65)
lst('Meta-Beschreibung fehlt', lambda r: not r['desc'])
lst('Meta-Beschreibung zu lang (>165)', lambda r: len(r['desc']) > 165)
lst('Doppelte Titel', lambda r: sum(1 for q in ok if q['title'] == r['title']) > 1)
lst('Doppelte Meta-Beschreibung', lambda r: r['desc'] and sum(1 for q in ok if q['desc'] == r['desc']) > 1)
lst('H1 fehlt oder mehrfach', lambda r: r['h1'] != 1)
lst('Canonical fehlt oder abweichend', lambda r: not r['canon'] or r['canon'].rstrip('/') != r['url'].rstrip('/'))
lst('noindex', lambda r: 'noindex' in r['robots'])
lst('dünn (<150 Wörter)', lambda r: r['words'] < 150)
lst('Bilder ohne Alt-Text', lambda r: r['noalt'] > 0, 15)
lst('Langsam (>1,5 s Server)', lambda r: r['secs'] > 1.5)
lst('Ohne strukturierte Daten', lambda r: not r['schema'])
print('\nØ Serverzeit: %.2f s, Ø HTML: %d KB' % (sum(r['secs'] for r in ok) / len(ok), sum(r['kb'] for r in ok) / len(ok)))
