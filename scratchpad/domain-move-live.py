import re, json, base64, urllib.request, urllib.error, sys, time
ENV = {}
for line in open(r'C:\Homepage\Neue Seite 2026\kaffeetechniker-integration.env', encoding='utf-8-sig'):
    m = re.match(r'\s*([^#=]+?)\s*=\s*(.*)', line)
    if m: ENV[m.group(1)] = m.group(2).strip().strip('"')
BASE = 'https://kaffeetechniker.de'
AUTH = 'Basic ' + base64.b64encode(f"{ENV['WP_APP_USER']}:{ENV['WP_APP_PASSWORD'].replace(' ','')}".encode()).decode()
def call(method, path, data=None, timeout=120):
    req = urllib.request.Request(f"{BASE}/wp-json/{path}", data=(json.dumps(data).encode() if data is not None else None), method=method, headers={'Authorization': AUTH, 'User-Agent': 'Mozilla/5.0', 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        d = json.loads(r.read().decode('utf-8', 'ignore')); return d['value'] if isinstance(d, dict) and 'value' in d and 'Count' in d else d

# 0) Erreichbarkeit / Stand pruefen
me = call('GET', 'wp/v2/users/me?_fields=id,slug,roles')
print("API erreichbar als:", me.get('slug'), me.get('roles'))
s = call('GET', 'wp/v2/settings?_fields=url,blog_public') if False else None

# 1) Umzugswerkzeug aktivieren
r = call('PUT', 'code-snippets/v1/snippets/25', {'active': True})
print("Snippet 25 aktiv:", r.get('active'), r.get('code_error'))

# 2) Ausfuehren
d = call('POST', 'kt/v1/domainmove', {'from': 'new.kaffeetechniker.de', 'to': 'kaffeetechniker.de', 'execute': True, 'confirm': 'JA-UMZIEHEN', 'finish': True}, timeout=280)
print("Modus:", d['modus'])
print("Vorher: siteurl=%s home=%s blog_public=%s" % (d['aktuell']['siteurl'], d['aktuell']['home'], d['aktuell']['blog_public']))
for row in d['bericht']:
    print(f"  {row['table'].split('.')[-1]:22} {row['column']:16} Zeilen={row['rows']:5} Vorkommen={row['occurrences']:6} geaendert={row['changed']}")
print("SUMME geaendert:", d['summe'])
print("Abschluss:", d.get('abschluss'))

# 3) Werkzeug wieder abschalten
r = call('PUT', 'code-snippets/v1/snippets/25', {'active': False})
print("Snippet 25 jetzt aktiv:", r.get('active'))
