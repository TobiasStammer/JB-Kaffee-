# -*- coding: utf-8 -*-
import json

PATH = 'pages-content.json'

with open(PATH, encoding='utf-8-sig') as f:
    data = json.load(f)

IMG = 'https://new.kaffeetechniker.de/wp-content/uploads/2026/09'

journey_html = """<style>
.tw{font-family:'Source Sans 3','Source Sans Pro',system-ui,sans-serif}
.tw-tx{font-size:14px;line-height:1.62;color:#40372f;margin:0}
.tw-tx+.tw-tx{margin-top:8px}
.tw-journey{position:relative;margin:4px 0 2px}
.tw-journey::before{content:"";position:absolute;left:21px;top:24px;bottom:38px;width:2px;background:#e7ddd0}
.tw-st{display:grid;grid-template-columns:44px 1fr;gap:16px;padding:15px 0;border-top:1px solid #efe9e0}
.tw-st:first-child{border-top:0;padding-top:2px}
.tw-st-ic{width:44px;height:44px;border-radius:50%;background:#f3ece3;color:#6f4e37;display:flex;align-items:center;justify-content:center;position:relative;z-index:1}
.tw-st-ic svg{width:21px;height:21px}
.tw-st-h{display:flex;align-items:center;gap:9px;font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:14.5px;color:#2b2b2b;margin:9px 0 5px}
.tw-st-n{flex:0 0 auto;width:20px;height:20px;border-radius:50%;background:#6f4e37;color:#fff;font-size:11px;font-weight:700;display:inline-flex;align-items:center;justify-content:center}
</style>
<div class="tw tw-journey">
<div class="tw-st"><div class="tw-st-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M11 20A7 7 0 0 1 4 13c0-6 9-12 16-12 0 7-6 16-12 16a7 7 0 0 1-1 3z"/><path d="M4 13c4 0 7-3 7-7"/></svg></div><div><div class="tw-st-h"><span class="tw-st-n">1</span>Pfl&uuml;cken</div><div class="tw-tx">Von Hand oder maschinell werden die obersten zwei Bl&auml;tter und die Knospe gepfl&uuml;ckt ("two leaves and a bud") &ndash; sie enthalten die meisten Aromastoffe. Je feiner die Pfl&uuml;ckung, desto hochwertiger der Tee.</div></div></div>
<div class="tw-st"><div class="tw-st-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8h11a3 3 0 1 0-3-3"/><path d="M3 16h15a3 3 0 1 1-3 3"/></svg></div><div><div class="tw-st-h"><span class="tw-st-n">2</span>Welken</div><div class="tw-tx">Die frischen Bl&auml;tter verlieren an der Luft einen Gro&szlig;teil ihrer Feuchtigkeit und werden weich und biegsam &ndash; die Voraussetzung f&uuml;r den n&auml;chsten Schritt.</div></div></div>
<div class="tw-st"><div class="tw-st-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2a10 10 0 1 0 7 3"/><path d="M12 7a5 5 0 1 0 3.5 1.5"/></svg></div><div><div class="tw-st-h"><span class="tw-st-n">3</span>Rollen</div><div class="tw-tx">Die Zellw&auml;nde werden aufgebrochen, &auml;therische &Ouml;le und Pflanzensaft treten aus &ndash; das ist die Grundlage f&uuml;r Aroma und Farbe der sp&auml;teren Tasse.</div></div></div>
<div class="tw-st"><div class="tw-st-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2.7s6 6.8 6 11.3a6 6 0 0 1-12 0C6 9.5 12 2.7 12 2.7z"/></svg></div><div><div class="tw-st-h"><span class="tw-st-n">4</span>Oxidation</div><div class="tw-tx">An der Luft verf&auml;rben sich die Blattstoffe &ndash; &auml;hnlich wie ein aufgeschnittener Apfel wird braun. Volle Oxidation ergibt Schwarztee, keine Oxidation Gr&uuml;ntee. Dieser Schritt entscheidet, welche Teeart entsteht.</div></div></div>
<div class="tw-st"><div class="tw-st-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22a7 7 0 0 0 7-7c0-3-2-5-3.5-7C14 6 12 2 12 2S10 6 8.5 8C7 10 5 12 5 15a7 7 0 0 0 7 7z"/></svg></div><div><div class="tw-st-h"><span class="tw-st-n">5</span>Trocknen</div><div class="tw-tx">Hei&szlig;luft stoppt die Oxidation im gew&uuml;nschten Moment und senkt die Restfeuchte auf rund 3&nbsp;% &ndash; erst dadurch wird der Tee lagerf&auml;hig.</div></div></div>
<div class="tw-st"><div class="tw-st-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/></svg></div><div><div class="tw-st-h"><span class="tw-st-n">6</span>Sortieren &amp; Mischen</div><div class="tw-tx">Nach Blattgr&ouml;&szlig;e sortiert und zu gleichbleibenden Mischungen kombiniert &ndash; damit jede Tasse einer Sorte gleich schmeckt, ob heute oder in einem halben Jahr.</div></div></div>
</div>"""

vs_html = """<div class="tw tw-vs">
<style>
.tw-vs-head{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-bottom:4px}
.tw-vs-head div{background:#6f4e37;color:#fff;font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:12px;text-align:center;padding:8px 4px;border-radius:6px}
.tw-vs-row{display:grid;grid-template-columns:repeat(4,1fr);gap:3px 8px;padding:10px 0;border-top:1px solid #efe9e0}
.tw-vs-k{grid-column:1 / -1;font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:11px;letter-spacing:.05em;text-transform:uppercase;color:#9a8a78}
.tw-vs-v{font-size:12.5px;line-height:1.45;color:#3a3a3a}
@media(max-width:560px){.tw-vs-head,.tw-vs-row{grid-template-columns:1fr 1fr}.tw-vs-row .tw-vs-v:nth-child(4),.tw-vs-row .tw-vs-v:nth-child(5){border-top:1px dashed #efe9e0;padding-top:6px}}
</style>
<div class="tw-vs-head"><div>Schwarzer Tee</div><div>Gr&uuml;ner Tee</div><div>Fr&uuml;chte- &amp; Kr&auml;utertee</div><div>Rooibos-Tee</div></div>
<div class="tw-vs-row"><span class="tw-vs-k">Herkunft</span><span class="tw-vs-v">Teestrauch, voll oxidiert</span><span class="tw-vs-v">Teestrauch, nicht oxidiert</span><span class="tw-vs-v">Fr&uuml;chte, Bl&uuml;ten, Kr&auml;uter &ndash; botanisch kein Tee</span><span class="tw-vs-v">Rooibosstrauch aus S&uuml;dafrika</span></div>
<div class="tw-vs-row"><span class="tw-vs-k">Koffein</span><span class="tw-vs-v">ja, mittel bis hoch</span><span class="tw-vs-v">ja, meist etwas weniger</span><span class="tw-vs-v">nein</span><span class="tw-vs-v">nein</span></div>
<div class="tw-vs-row"><span class="tw-vs-k">Geschmack</span><span class="tw-vs-v">kr&auml;ftig, malzig, w&auml;rmend</span><span class="tw-vs-v">frisch, herb, leicht gr&uuml;n</span><span class="tw-vs-v">vielf&auml;ltig, oft fruchtig-s&uuml;&szlig;</span><span class="tw-vs-v">mild, leicht s&uuml;&szlig;lich, nussig</span></div>
</div>"""

sorts_html = r"""<div class="tw tw-sorts">
<style>
.tw-sorts{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:4px 0 2px}
.tw-sort{border:1px solid #e7ddd0;border-radius:10px;overflow:hidden;background:#fcfaf6}
.tw-sort img{display:block;width:100%;height:96px;object-fit:cover;object-position:top center}
.tw-sort-b{padding:10px 12px 12px}
.tw-sort-h{font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:13.5px;color:#2b2b2b;margin-bottom:3px}
.tw-sort-a{font-size:11px;color:#8b5e3c;font-weight:700;text-transform:uppercase;letter-spacing:.03em;margin-bottom:6px}
.tw-sort-x{font-size:12px;line-height:1.45;color:#5a5248}
@media(max-width:620px){.tw-sorts{grid-template-columns:1fr 1fr}}
@media(max-width:420px){.tw-sorts{grid-template-columns:1fr}}
</style>
<div class="tw-sort"><img src="{{IMG}}/kt-tee-earl-grey.jpg" alt="JB Unser Tee Earl Grey"><div class="tw-sort-b"><div class="tw-sort-h">Earl Grey</div><div class="tw-sort-a">Schwarzer Tee</div><div class="tw-sort-x">Kr&auml;ftig, mit Bergamotte-Aroma.</div></div></div>
<div class="tw-sort"><img src="{{IMG}}/kt-tee-bluetenzeit.jpg" alt="JB Unser Tee Bl&uuml;tenzeit"><div class="tw-sort-b"><div class="tw-sort-h">Bl&uuml;tenzeit</div><div class="tw-sort-a">Gr&uuml;ner Tee</div><div class="tw-sort-x">Fein, mit einer Fruchtkomposition aromatisiert.</div></div></div>
<div class="tw-sort"><img src="{{IMG}}/kt-tee-beerenzauber.jpg" alt="JB Unser Tee Beerenzauber"><div class="tw-sort-b"><div class="tw-sort-h">Beerenzauber</div><div class="tw-sort-a">Fr&uuml;chtetee</div><div class="tw-sort-x">Kirsch-, Erdbeer-, Brombeer- und Johannisbeer-Geschmack.</div></div></div>
<div class="tw-sort"><img src="{{IMG}}/kt-tee-rote-liebe.jpg" alt="JB Unser Tee Rote Liebe"><div class="tw-sort-b"><div class="tw-sort-h">Rote Liebe</div><div class="tw-sort-a">Fr&uuml;chtetee</div><div class="tw-sort-x">Reife Erdbeeren mit Vanilleso&szlig;e.</div></div></div>
<div class="tw-sort"><img src="{{IMG}}/kt-tee-frische-kraft.jpg" alt="JB Unser Tee Frische Kraft"><div class="tw-sort-b"><div class="tw-sort-h">Frische Kraft</div><div class="tw-sort-a">Kr&auml;utertee</div><div class="tw-sort-x">Belebend, mit Limonen-Grapefruit-Geschmack.</div></div></div>
<div class="tw-sort"><img src="{{IMG}}/kt-tee-erdbeer-sahne.jpg" alt="JB Unser Tee Erdbeer-Sahne"><div class="tw-sort-b"><div class="tw-sort-h">Erdbeer-Sahne</div><div class="tw-sort-a">Rooibos-Tee</div><div class="tw-sort-x">Koffeinfrei, mit Erdbeer-Sahne-Geschmack.</div></div></div>
</div>""".replace('{{IMG}}', IMG)

zeremonie_html = """<div class="tw tw-journey">
<style>
.tw-st{display:grid;grid-template-columns:44px 1fr;gap:16px;padding:15px 0;border-top:1px solid #efe9e0}
.tw-st:first-child{border-top:0;padding-top:2px}
</style>
<div class="tw-st"><div class="tw-st-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3h12l4 6-10 12L2 9z"/><path d="M2 9h20M9 3l3 6-3 12M15 3l-3 6 3 12"/></svg></div><div><div class="tw-st-h"><span class="tw-st-n">1</span>Kluntje in die Tasse</div><div class="tw-tx">Ein St&uuml;ck Kluntje &ndash; wei&szlig;er oder brauner Kandis &ndash; kommt zuerst in die Tasse. Erst danach wird der hei&szlig;e Tee aufgegossen: Der Kandis knistert h&ouml;rbar und schmilzt nur langsam an.</div></div></div>
<div class="tw-st"><div class="tw-st-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M17.5 19H8a4.5 4.5 0 0 1-1-8.9A5.5 5.5 0 0 1 17 9a4 4 0 0 1 .5 10z"/></svg></div><div><div class="tw-st-h"><span class="tw-st-n">2</span>Sahne &ndash; das "Wulkje"</div><div class="tw-tx">Ein Sahnel&ouml;ffel Rahm wird vorsichtig &uuml;ber den R&uuml;cken eines L&ouml;ffels am Tassenrand zugegeben, nicht einger&uuml;hrt. Die Sahne steigt als kleine wei&szlig;e Wolke &ndash; das Wulkje &ndash; von unten auf.</div></div></div>
<div class="tw-st"><div class="tw-st-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg></div><div><div class="tw-st-h"><span class="tw-st-n">3</span>Genie&szlig;en, nicht r&uuml;hren</div><div class="tw-tx">Getrunken wird ungeer&uuml;hrt: erst mild und sahnig obenauf, zum Schluss kr&auml;ftig und s&uuml;&szlig; vom Kluntje am Tassenboden. Traditionell werden mindestens drei Tassen getrunken.</div></div></div>
</div>"""

buy_html = """<div class="tw tw-buy">
<style>
.tw-buy{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin:4px 0 2px}
.tw-buy-c{border:1px solid #e6e6e6;border-radius:10px;padding:15px 17px}
.tw-buy-h{display:flex;align-items:center;gap:8px;font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:13.5px;color:#2b2b2b;margin-bottom:9px}
.tw-buy-h svg{width:16px;height:16px;color:#6f4e37;flex:0 0 auto}
.tw-buy ul{margin:0;padding:0;list-style:none}
.tw-buy li{position:relative;padding:4px 0 4px 15px;font-size:13px;line-height:1.5;color:#40372f}
.tw-buy li::before{content:"";position:absolute;left:0;top:11px;width:5px;height:5px;border-radius:50%;background:#c8a27a}
@media(max-width:560px){.tw-buy{grid-template-columns:1fr}}
</style>
<div class="tw-buy-c"><div class="tw-buy-h"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.3 4.6a1 1 0 0 0 .9 1.4H19"/><circle cx="9" cy="20" r="1"/><circle cx="17" cy="20" r="1"/></svg> Direkt bei uns</div><ul><li>Im Gesch&auml;ft in Hofheim-Langenhain &ndash; zum Probieren und Riechen</li><li>Im Online-Shop &ndash; deutschlandweit</li></ul></div>
<div class="tw-buy-c"><div class="tw-buy-h"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg> Gut zu wissen</div><ul><li>Alle sechs Sorten lose im 100&ndash;150-g-Beutel, 6,90&nbsp;&euro; je Sorte</li><li>Unsicher, welche Sorte passt? Wir beraten Sie gern &ndash; telefonisch oder im Gesch&auml;ft</li></ul></div>
</div>"""

new_page = {
    "slug": "unser-tee-wissen",
    "menu": "Tee: Teekultur &amp; Sorten",
    "title": "Unser Tee – Teekultur, Sorten und die richtige Zubereitung",
    "excerpt": "Vom Teestrauch bis zur Tasse: Verarbeitung, Teearten im Vergleich, die ostfriesische Teezeremonie mit Kluntje und Wulkje – plus unsere sechs eigenen Teesorten und Brau-Tipps.",
    "blocks": [
        {
            "t": "p",
            "x": "Guter Tee entsteht lange vor der Kanne – bei der Pflanze, der Ernte und der Verarbeitung. Kaum eine Region trinkt so viel und so bewusst Tee wie der Nordwesten Deutschlands: Dort ist daraus eine eigene Teekultur mit fester Zeremonie gewachsen. Unsere sechs Teesorten werden nach diesem Handwerk gemischt und für uns abgefüllt."
        },
        {
            "t": "image",
            "src": f"{IMG}/kt-tee-sortierung.jpg",
            "alt": "Sortierte schwarze Teeblätter nach Blattgröße",
            "max": "620px"
        },
        {
            "t": "h", "lvl": 2, "icon": "map",
            "x": "Herkunft: eine Pflanze, viele Teesorten"
        },
        {
            "t": "p",
            "x": "Schwarzer, grüner, weißer und Oolong-Tee stammen alle von derselben Pflanze, Camellia sinensis – angebaut unter anderem in Assam, Darjeeling, auf Ceylon, in China und Japan. Was aus dem Blatt wird, entscheidet allein die Verarbeitung nach der Ernte. Früchte-, Kräuter- und Rooibostee sind botanisch dagegen gar kein „Tee“, sondern Aufgüsse aus anderen Pflanzen – deshalb auch ohne Koffein."
        },
        {
            "t": "html",
            "x": journey_html
        },
        {
            "t": "h", "lvl": 2, "icon": "compare",
            "x": "Schwarz, Grün, Früchte &amp; Rooibos im Vergleich"
        },
        {
            "t": "p",
            "x": "Der Oxidationsgrad beim Schwarztee bringt Körper und Kraft, beim Grüntee bleibt er ganz aus – daher die frische, herbe Note. Früchte-, Kräuter- und Rooibostee eignen sich dagegen auch für den Abend, weil sie koffeinfrei sind."
        },
        {
            "t": "html",
            "x": vs_html
        },
        {
            "t": "h", "lvl": 2, "icon": "cup",
            "x": "Die ostfriesische Teezeremonie"
        },
        {
            "t": "p",
            "x": "In Ostfriesland wird Tee nicht nebenbei getrunken, sondern zelebriert – mehrmals täglich, mit einem festen Ablauf. Grundlage ist die „echte ostfriesische Mischung“: eine kräftige Schwarzteemischung mit hohem Assam-Anteil, die nur dann „echt“ heißen darf, wenn sie tatsächlich in Ostfriesland gemischt wurde. Kein Wunder, dass die Region beim Pro-Kopf-Teeverbrauch weltweit ganz vorne liegt."
        },
        {
            "t": "image",
            "src": f"{IMG}/kt-tee-zeremonie.jpg",
            "alt": "Teekanne, Tassen und Sahnekännchen im ostfriesischen Blaudekor",
            "max": "460px"
        },
        {
            "t": "html",
            "x": zeremonie_html
        },
        {
            "t": "h", "lvl": 2, "icon": "box",
            "x": "Unsere sechs Teesorten"
        },
        {
            "t": "p",
            "x": "Sechs lose Mischungen, je 6,90&nbsp;€ – von kräftigem Schwarztee bis zu koffeinfreiem Rooibos:"
        },
        {
            "t": "html",
            "x": sorts_html
        },
        {
            "t": "h", "lvl": 2, "icon": "check",
            "x": "So gelingt die perfekte Tasse"
        },
        {
            "t": "ul",
            "x": [
                "Schwarzer Tee (z. B. Earl Grey): sprudelnd heißes Wasser, 3–4 Minuten ziehen lassen – länger wird er schnell bitter.",
                "Grüner Tee (z. B. Blütenzeit): nur 70–80&nbsp;°C und 2–3 Minuten, sonst dominieren Bitterstoffe statt Frische.",
                "Früchte- und Kräutertee (Beerenzauber, Rote Liebe, Frische Kraft): kochendes Wasser, ruhig 8–10 Minuten – je länger, desto intensiver das Aroma.",
                "Rooibos-Tee (Erdbeer-Sahne): kochendes Wasser, 6–8 Minuten, koffeinfrei und daher auch abends geeignet.",
                "Teemenge: rund 1 gehäufter Teelöffel bzw. 2–3&nbsp;g lose Ware pro Tasse."
            ]
        },
        {
            "t": "callout",
            "variant": "ok",
            "title": "Tee richtig lagern",
            "intro": "Lose Ware verliert Aroma vor allem durch Licht, Wärme, Feuchtigkeit und fremde Gerüche.",
            "x": [
                "trocken, dunkel und luftdicht lagern – der verschlossene Aromabeutel genügt",
                "nicht direkt neben Gewürzen, Kaffee oder anderen stark riechenden Lebensmitteln aufbewahren – Tee nimmt Fremdaromen leicht an",
                "aromatisierte Früchte- und Kräutertees zügig verbrauchen, klassische Schwarztees halten deutlich länger"
            ]
        },
        {
            "t": "callout",
            "variant": "warn",
            "title": "Typische Fehler",
            "x": [
                "grünen Tee mit kochendem Wasser aufgießen – er wird bitter statt frisch",
                "den Beutel oder das Sieb stundenlang in der Tasse lassen – Gerbstoffe machen den Tee schwer und bitter",
                "Kluntje umrühren, statt ihn langsam am Tassenboden schmelzen zu lassen – damit geht die typische Geschmacksschichtung verloren"
            ]
        },
        {
            "t": "h", "lvl": 2, "icon": "shop",
            "x": "Wo Sie unseren Tee bekommen"
        },
        {
            "t": "html",
            "x": buy_html
        },
        {
            "t": "btns",
            "keep": True,
            "x": [
                {"label": "Unser Kaffee &amp; Tee", "url": "/unser-kaffee/"},
                {"label": "Im Geschäft vorbeikommen", "url": "/anfahrt/"}
            ]
        }
    ]
}

pages = data['pages']
idx = next(i for i, p in enumerate(pages) if p.get('slug') == 'unser-kaffee-wissen')
pages.insert(idx + 1, new_page)

# Cross-link the tea wissen page from the combined shop page's note
note = data['jura']['kaffeeTee']['note']
old = 'Mehr über Herkunft und Röstung: <a href="/unser-kaffee-wissen/">Unser Kaffee – Wissenswertes</a>. Welche Teesorte zu Ihnen passt, probieren Sie am besten bei uns – oder rufen Sie an: 06192 2004363.'
newnote = 'Mehr über Herkunft und Röstung: <a href="/unser-kaffee-wissen/">Unser Kaffee – Wissenswertes</a>. Mehr über Teekultur und Sorten: <a href="/unser-tee-wissen/">Unser Tee – Wissenswertes</a>. Welche Sorte zu Ihnen passt, probieren Sie am besten bei uns – oder rufen Sie an: 06192 2004363.'
assert data['jura']['kaffeeTee']['note'] == old, "note text changed unexpectedly, aborting"
data['jura']['kaffeeTee']['note'] = newnote

with open(PATH, 'w', encoding='utf-8-sig') as f:
    f.write(json.dumps(data, indent=2, ensure_ascii=False) + "\n")

print("OK, inserted at index", idx + 1, "total pages now", len(data['pages']))
