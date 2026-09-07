# -*- coding: utf-8 -*-
import json

def load(p, bom=False):
    return json.load(open(p, encoding='utf-8-sig' if bom else 'utf-8'))
def save(p, obj, bom=False):
    s = json.dumps(obj, ensure_ascii=False, indent=2)
    open(p, 'w', encoding=('utf-8-sig' if bom else 'utf-8'), newline='\n').write(s + '\n')

DASH = '–'

# ---------- jura-products.json ----------
prod = load('jura-products.json')
skus = {e['sku'] for e in prod['haushalt']}
A8 = {
  "sku": "15736", "name": "JURA A8 (Piano Black)", "price": "999.00", "line": "A",
  "url": "https://de.jura.com/de/produkte-haushalt/kaffeevollautomaten/a8-piano-black-ea-15736",
  "img": "https://api.jura.com/media/global/images/home-products/a-line-2026/A8-EA/A8-Piano-Black-EA/a8_ea_sa_pb_packshot_front.jpg"
}
S10 = {
  "sku": "15775", "name": "JURA S10 (Obsidian Black)", "price": "", "line": "S",
  "url": "https://de.jura.com/de/produkte-haushalt/kaffeevollautomaten/s10-obsidian-black-ea-15775",
  "img": "https://api.jura.com/media/global/images/home-products/s-line-2026/S10-Obsidian-Black-EA-SA-15775/s10_ob_ea_packshot.jpg"
}
for e in (A8, S10):
    if e['sku'] not in skus:
        prod['haushalt'].append(e)
save('jura-products.json', prod)
print('products ->', [e['sku'] for e in prod['haushalt']])

# ---------- jura-specs.json ----------
specs = load('jura-specs.json')
specs['15736'] = {
  "spez": "18 Kaffeespezialitäten",
  "vorzuege": [
    "18 Kaffeespezialitäten " + DASH + " von Espresso bis Flat White, klassisch (Hot Brew) und mild-fruchtig (Light Brew)",
    "Mit nur 19 cm Breite der schmalste Full-Size-Kaffeevollautomat von JURA",
    "Professionelles Präzisionsmahlwerk P.A.G.3 mit werkzeugloser Mahlgradverstellung",
    "Variable Full-Size-Brüheinheit für 5 bis 16 g Kaffee mit Puls-Extraktionsprozess (P.E.P.)",
    "One-Touch-Milchsystem mit automatischer Reinigung auf Knopfdruck",
    "2,8\"-Tasten-Farbdisplay, Coffee Timer und Steuerung per App J.O.E. (WLAN)"
  ],
  "techdaten": [
    {"k": "Spezialitäten", "v": "18"},
    {"k": "Mahlwerk", "v": "Professional Aroma Grinder 3 (P.A.G.3)"},
    {"k": "Brüheinheit", "v": "variabel, 5 " + DASH + " 16 g"},
    {"k": "Bohnenbehälter", "v": "140 g"},
    {"k": "Wassertank", "v": "0,8 l"},
    {"k": "Kaffeesatzbehälter", "v": "max. 8 Portionen"},
    {"k": "Display", "v": "2,8\" Tasten-Farbdisplay"},
    {"k": "Milchsystem", "v": "HP4 / CX4, auswechselbarer Milchauslauf"},
    {"k": "Pumpendruck", "v": "15 bar"},
    {"k": "Breite", "v": "19 cm"},
    {"k": "Gewicht", "v": "8,9 kg"},
    {"k": "Leistung", "v": "1450 W"},
    {"k": "Spannung", "v": "230 V ~"},
    {"k": "Wasserfilter", "v": "CLARIS Smart+"},
    {"k": "Konnektivität", "v": "WLAN, App J.O.E."},
    {"k": "Artikelnummer", "v": "15736"},
    {"k": "EAN", "v": "7610917157365"}
  ]
}
specs['15775'] = {
  "spez": "Kaffeespezialitäten aus vier Genusswelten",
  "vorzuege": [
    "Neue S-Linie von JURA mit vier Genusswelten: Hot, Light, Cold und Sweet",
    "Premium-Design mit großem Farbdisplay",
    "Derzeit als Vorbestellung " + DASH + " Preis und Liefertermin auf Anfrage",
    "Beratung und Vorführung in unserem Geschäft in Hofheim-Langenhain"
  ],
  "techdaten": [
    {"k": "Baureihe", "v": "S-Linie (2026)"},
    {"k": "Artikelnummer", "v": "15775"},
    {"k": "Verfügbarkeit", "v": "Vorbestellung " + DASH + " sprechen Sie uns an"}
  ]
}
save('jura-specs.json', specs)
print('specs -> +15736 +15775')

# ---------- jura-images.json (BOM) ----------
imgs = load('jura-images.json', bom=True)
a8b = "https://api.jura.com/media/global/images/home-products/a-line-2026/A8-EA/A8-Piano-Black-EA/"
imgs['15736'] = [
  a8b + "a8_ea_sa_pb_packshot_front.jpg",
  a8b + "image-gallery/a8_ea_sa_pb_image2.jpg",
  a8b + "image-gallery/a8_ea_sa_pb_image3.jpg",
  a8b + "image-gallery/a8_ea_sa_pb_image4.jpg",
  a8b + "image-gallery/a8_ea_sa_pb_image5.jpg",
]
imgs['15775'] = [
  "https://api.jura.com/media/global/images/home-products/s-line-2026/S10-Obsidian-Black-EA-SA-15775/s10_ob_ea_packshot.jpg",
]
save('jura-images.json', imgs, bom=True)
print('images -> +15736 +15775')
