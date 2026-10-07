# Erzeugt pages-extra-kaffeegetraenke.json (Seite "Kaffeegetraenke im Vergleich") aus dem Entwurf
# scratchpad/entwurf-kaffeegetraenke.html. Die Zeichnungen werden per Node vorab zu statischem SVG gerendert
# (kein <script> im Seiteninhalt, siehe pitfall-wp-content-breaks-inline-scripts).
# Aufruf: python build-kaffeegetraenke-page.py   -> danach .\build-pages.ps1 -Only kaffeegetraenke
import json, re, subprocess, os, tempfile

root = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(root, 'scratchpad', 'kaffee-script-v2.js'), encoding='utf-8').read()
js = re.sub(r'^\s*<script>|</script>\s*$', '', src.strip())
runner = "const o={};global.document={getElementById:()=>o};\n" + js + "\nprocess.stdout.write(o.innerHTML);"
tmp = os.path.join(tempfile.gettempdir(), 'kg-render.js')
open(tmp, 'w', encoding='utf-8').write(runner)
cards = subprocess.run(['node', tmp], capture_output=True, text=True, encoding='utf-8', check=True).stdout
for c in ('card', 'body', 'tag', 'layers', 'facts', 'say'):
    cards = cards.replace('class="%s"' % c, 'class="kg-%s"' % c)
cards = re.sub(r'\s*\n\s*', '', cards)

css = """<style>
.kg-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(270px,1fr));gap:18px;margin:6px 0 0}
.kg-card{background:#fff;border:1px solid #e6ddd2;border-radius:12px;overflow:hidden;display:flex;flex-direction:column}
.kg-card svg{width:100%;height:210px;display:block}
.kg-body{padding:14px 16px 16px;display:flex;flex-direction:column;gap:7px}
.kg-tag{font-size:12px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;color:#8a4b1f}
.kg-card h3{margin:0;font-size:20px;line-height:1.25}
.kg-card p{margin:0;font-size:14.5px;line-height:1.55}
.kg-layers{list-style:none;margin:2px 0;padding:0;font-size:13.5px}
.kg-layers li{display:flex;align-items:center;gap:8px;padding:2px 0;margin:0}
.kg-layers i{width:13px;height:13px;border-radius:4px;border:1px solid #0003;flex:none}
.kg-facts{display:flex;gap:7px;flex-wrap:wrap}
.kg-facts span{background:#f3ece1;border-radius:99px;padding:3px 10px;font-size:12.5px}
.kg-say{font-size:13px;color:#6b5d52;border-top:1px dashed #e6ddd2;padding-top:8px}
.kg-vs{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:14px}
.kg-vs div{background:#faf7f2;border:1px solid #e6ddd2;border-radius:10px;padding:14px 16px;font-size:14.5px;line-height:1.55}
.kg-vs h3{margin:0 0 6px;font-size:18px}
.kg-tbl{width:100%;border-collapse:collapse;font-size:14px}
.kg-tbl th,.kg-tbl td{padding:9px 10px;border-bottom:1px solid #e6ddd2;text-align:left;vertical-align:top}
.kg-tbl th{background:#f3ece1}
.kg-tblw{overflow-x:auto}
</style>"""

rows = [
 ('Ristretto', 'Sehr kurz gezogener Espresso', 'ca. 15–20 ml', 'Intensiv, süßlich, wenig Bitterkeit'),
 ('Espresso', 'Espresso mit Crema', 'ca. 25–40 ml', 'Kräftig, aromatisch'),
 ('Lungo', 'Espresso, länger gezogen', 'ca. 60–100 ml', 'Milder, etwas herber'),
 ('Café Crème', 'Kaffee mit Crema, ohne Milch', 'ca. 120–180 ml', 'Mild, rund'),
 ('Americano', 'Espresso + heißes Wasser', 'ca. 150–200 ml', 'Wie Filterkaffee mit Espresso-Aroma'),
 ('Cortado', 'Espresso + gleiche Menge warme Milch', 'ca. 60–80 ml', 'Kräftig und weich'),
 ('Flat White', 'Doppelter Espresso + feine Milch', 'ca. 150–180 ml', 'Kräftiger Kaffee, samtige Milch'),
 ('Cappuccino', '⅓ Espresso, ⅓ Milch, ⅓ Milchschaum', 'ca. 150–180 ml', 'Ausgewogen, luftig'),
 ('Latte Macchiato', 'Viel Milch, Espresso, Schaum obenauf', 'ca. 250–300 ml', 'Mild, cremig'),
]
tbl = '<div class="kg-tblw"><table class="kg-tbl"><thead><tr><th>Getränk</th><th>Zusammensetzung</th><th>Menge</th><th>Geschmack</th></tr></thead><tbody>' + \
      ''.join('<tr><td><b>%s</b></td><td>%s</td><td>%s</td><td>%s</td></tr>' % r for r in rows) + '</tbody></table></div>'

page = {
  'slug': 'kaffeegetraenke',
  'menu': 'Kaffee: Getränke im Vergleich',
  'title': 'Espresso, Americano, Flat White & Co. – die Unterschiede',
  'excerpt': 'Was ist der Unterschied zwischen Espresso, Americano, Flat White, Cappuccino und Latte Macchiato? Mit Zeichnungen, Mengen und Geschmack im Überblick.',
  'blocks': [
    {'t': 'p', 'x': 'Fast jedes Kaffeegetränk besteht aus nur drei Dingen: Espresso, heißem Wasser und Milch. Entscheidend ist das Mengenverhältnis und wie die Milch aufgeschäumt wird. Hier sehen Sie, was in welche Tasse kommt.'},
    {'t': 'html', 'x': css + '<div class="kg-grid">' + cards + '</div>'},
    {'t': 'h', 'lvl': 2, 'x': 'Americano und Flat White – oft verwechselt?'},
    {'t': 'html', 'x': '<div class="kg-vs"><div><h3>Americano</h3>Ein Espresso, der mit heißem Wasser aufgefüllt wird. Es ist <b>keine Milch</b> im Spiel. Das Ergebnis erinnert an Filterkaffee, schmeckt aber nach Espresso. Tipp: erst das Wasser, dann den Espresso einlaufen lassen, so bleibt die Crema erhalten.</div><div><h3>Flat White</h3>Hier steht die <b>Milch</b> im Mittelpunkt: ein kräftiger doppelter Espresso und Milch, die so fein aufgeschäumt ist, dass sie fast flüssig wirkt. Im Unterschied zum Cappuccino gibt es nur eine dünne Schaumschicht. Der Kaffeegeschmack bleibt vorn.</div></div>'},
    {'t': 'h', 'lvl': 2, 'x': 'Alle Getränke im Überblick'},
    {'t': 'html', 'x': tbl},
    {'t': 'p', 'x': 'Die Mengen sind Richtwerte und variieren je nach Rezept und Land.'},
    {'t': 'h', 'lvl': 2, 'x': 'Und mein Kaffeevollautomat?'},
    {'t': 'p', 'x': 'Die meisten Vollautomaten bereiten Espresso, Café Crème, Cappuccino, Latte Macchiato und Flat White auf Knopfdruck zu. Welche Getränke Ihr Gerät kann und wie viel Milch und Wasser es dosiert, steht im Menü des Geräts. Die Mengen lassen sich meist einstellen.'},
    {'t': 'html', 'x': '<p><a href="/kaffee-quiz/">Kaffee-Quiz: Welcher Typ sind Sie?</a> · <a href="/kaffeemaschinen-kaufen/">Kaffeevollautomaten ansehen</a> · <a href="/kontakt/">Beratung im Laden</a></p>'},
  ]
}
out = os.path.join(root, 'pages-extra-kaffeegetraenke.json')
with open(out, 'w', encoding='utf-8-sig') as f:
    json.dump({'pages': [page]}, f, ensure_ascii=False, indent=2)
print('geschrieben:', out, len(cards), 'Zeichen Karten')
