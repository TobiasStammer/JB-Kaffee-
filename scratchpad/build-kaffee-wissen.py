# -*- coding: utf-8 -*-
import json

PC = r"C:\Homepage\Neue Seite 2026\pages-content.json"
d = json.load(open(PC, encoding="utf-8-sig"))
pages = {p["slug"]: p for p in d["pages"] if isinstance(p, dict) and p.get("slug")}
p = pages["unser-kaffee-wissen"]

p["title"] = "Unser Kaffee \u2013 Herkunft, R\u00f6stung und eigene Sorten"
p["excerpt"] = ("Von Arabica und Robusta \u00fcber Aufbereitung und R\u00f6stgrade bis zur richtigen "
                "Lagerung \u2013 plus unsere zwei eigenen Trommelr\u00f6stungen f\u00fcr den Kaffeevollautomaten.")
p["facts"] = [
    {"k": "R\u00f6stung", "v": "Trommelr\u00f6stung, schonend, kleine Chargen"},
    {"k": "Sorten", "v": "Caff\u00e8 Crema &middot; Espresso"},
    {"k": "Gebinde", "v": "1000\u2009g mit Aromaventil"},
    {"k": "Frische", "v": "am besten binnen 2\u20134 Wochen nach R\u00f6stung"},
    {"k": "Bezug", "v": "Gesch\u00e4ft, Online-Shop, regionale Partner"},
]

IC = {
 "sun": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/></svg>',
 "cherry": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="8" cy="16" r="4"/><circle cx="16" cy="16" r="4"/><path d="M8 12c0-5 4-7 9-7"/></svg>',
 "drop": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3s6 6.7 6 11a6 6 0 0 1-12 0C6 9.7 12 3 12 3z"/></svg>',
 "box": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><path d="M3.27 6.96L12 12.01l8.73-5.05M12 22.08V12"/></svg>',
 "flame": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22a7 7 0 0 0 7-7c0-3-2-5-3.5-7C14 6 12 2 12 2S10 6 8.5 8C7 10 5 12 5 15a7 7 0 0 0 7 7z"/></svg>',
 "cup": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8h1a4 4 0 0 1 0 8h-1"/><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"/><line x1="6" y1="1" x2="6" y2="4"/><line x1="10" y1="1" x2="10" y2="4"/><line x1="14" y1="1" x2="14" y2="4"/></svg>',
 "shop": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.3 4.6a1 1 0 0 0 .9 1.4H19"/><circle cx="9" cy="20" r="1"/><circle cx="17" cy="20" r="1"/></svg>',
 "pin": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>',
}

CSS = """<style>
.kw{font-family:'Source Sans 3','Source Sans Pro',system-ui,sans-serif}
.kw-tx{font-size:14px;line-height:1.62;color:#40372f;margin:0}
.kw-tx+.kw-tx{margin-top:8px}
.kw-journey{position:relative;margin:4px 0 2px}
.kw-journey::before{content:"";position:absolute;left:21px;top:24px;bottom:38px;width:2px;background:#e7ddd0}
.kw-st{display:grid;grid-template-columns:44px 1fr;gap:16px;padding:15px 0;border-top:1px solid #efe9e0}
.kw-st:first-child{border-top:0;padding-top:2px}
.kw-st-ic{width:44px;height:44px;border-radius:50%;background:#f3ece3;color:#6f4e37;display:flex;align-items:center;justify-content:center;position:relative;z-index:1}
.kw-st-ic svg{width:21px;height:21px}
.kw-st-h{display:flex;align-items:center;gap:9px;font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:14.5px;color:#2b2b2b;margin:9px 0 5px}
.kw-st-n{flex:0 0 auto;width:20px;height:20px;border-radius:50%;background:#6f4e37;color:#fff;font-size:11px;font-weight:700;display:inline-flex;align-items:center;justify-content:center}
.kw-vs{margin:6px 0 2px}
.kw-vs-head{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:4px}
.kw-vs-head div{background:#6f4e37;color:#fff;font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:13px;text-align:center;padding:8px 6px;border-radius:6px}
.kw-vs-row{display:grid;grid-template-columns:1fr 1fr;gap:3px 10px;padding:10px 0;border-top:1px solid #efe9e0}
.kw-vs-k{grid-column:1 / -1;font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:11px;letter-spacing:.05em;text-transform:uppercase;color:#9a8a78}
.kw-vs-v{font-size:13.5px;line-height:1.5;color:#3a3a3a}
.kw-roast{margin:6px 0 2px}
.kw-roast-bar{height:14px;border-radius:7px;background:linear-gradient(90deg,#cda67d 0%,#a5733f 50%,#552f1c 100%)}
.kw-roast-marks{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:12px 0 4px}
.kw-roast-m b{display:block;font-family:Tahoma,Arial,sans-serif;font-size:13px;color:#2b2b2b;margin-bottom:2px}
.kw-roast-m span{display:block;font-size:12px;line-height:1.45;color:#6b6257}
.kw-sorts{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin:4px 0 2px}
.kw-sort{border:1px solid #e7ddd0;border-radius:10px;padding:16px 18px;background:#fcfaf6}
.kw-sort-h{font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:16px;color:#2b2b2b;margin-bottom:11px}
.kw-blendrow{display:flex;justify-content:space-between;font-family:Tahoma,Arial,sans-serif;font-size:11px;font-weight:700;margin-bottom:5px}
.kw-blendrow .a{color:#8b5e3c}
.kw-blendrow .r{color:#a9793f}
.kw-blend{display:flex;height:12px;border-radius:6px;overflow:hidden}
.kw-blend i{display:block;font-style:normal}
.kw-blend .a{background:#8b5e3c}
.kw-blend .r{background:#c8a27a;flex:1}
.kw-tags{display:flex;flex-wrap:wrap;gap:6px;margin:12px 0 10px}
.kw-tags span{font-size:11.5px;background:#f0e7dc;color:#6f4e37;border-radius:999px;padding:4px 10px}
.kw-sort-for{font-size:12.5px;color:#6b6257}
.kw-buy{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin:4px 0 2px}
.kw-buy-c{border:1px solid #e6e6e6;border-radius:10px;padding:15px 17px}
.kw-buy-h{display:flex;align-items:center;gap:8px;font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:13.5px;color:#2b2b2b;margin-bottom:9px}
.kw-buy-h svg{width:16px;height:16px;color:#6f4e37;flex:0 0 auto}
.kw-buy ul{margin:0;padding:0;list-style:none}
.kw-buy li{position:relative;padding:4px 0 4px 15px;font-size:13px;line-height:1.5;color:#40372f}
.kw-buy li::before{content:"";position:absolute;left:0;top:11px;width:5px;height:5px;border-radius:50%;background:#c8a27a}
.kw-buy-feat{background:#f3ece3;border:1px solid #e3d7c6;border-radius:8px;padding:10px 12px 8px;margin-bottom:9px}
.kw-buy-feat-h{font-family:Tahoma,Arial,sans-serif;font-weight:700;font-size:12.5px;color:#6f4e37;margin-bottom:4px}
.kw-buy-feat-h span{font-weight:400;color:#8a7a68}
.kw-buy-feat li::before{background:#8b5e3c}
.kw-buy-note{display:block;font-size:11.5px;line-height:1.45;color:#6b6257;margin-top:2px;padding-right:4px}
@media(max-width:560px){
  .kw-sorts,.kw-buy{grid-template-columns:1fr}
  .kw-roast-marks{grid-template-columns:1fr;gap:8px}
}
</style>"""

def st(icn, n, title, body):
    return ('<div class="kw-st"><div class="kw-st-ic">' + IC[icn] + '</div><div>'
            '<div class="kw-st-h"><span class="kw-st-n">' + str(n) + '</span>' + title + '</div>'
            '<div class="kw-tx">' + body + '</div></div></div>')

journey = CSS + '\n<div class="kw kw-journey">\n' + '\n'.join([
 st("sun", 1, "Anbau",
    "Kaffee w&auml;chst im &bdquo;Bohneng&uuml;rtel&ldquo; rund um den &Auml;quator. Arabica braucht "
    "H&ouml;henlagen von 900 bis 2000&nbsp;Metern &ndash; k&uuml;hler, langsamere Reifung, mehr Aroma. "
    "Robusta gedeiht tiefer, w&auml;rmer und ist widerstandsf&auml;higer gegen Krankheiten."),
 st("cherry", 2, "Ernte",
    "Reife, rote Kirschen werden von Hand gepfl&uuml;ckt oder maschinell abgestreift. Nur vollreife "
    "Fr&uuml;chte geben einen sauberen, s&uuml;&szlig;en Geschmack."),
 st("drop", 3, "Aufbereitung",
    "Fruchtfleisch und Schleim m&uuml;ssen weg. &bdquo;Gewaschen&ldquo; wird die Tasse klar und "
    "s&auml;urebetont, &bdquo;natural&ldquo; (in der Kirsche getrocknet) fruchtig und vollmundig, "
    "&bdquo;honey&ldquo; liegt dazwischen. Danach trocknet der Rohkaffee auf rund 11&nbsp;% Restfeuchte."),
 st("box", 4, "Rohkaffee &amp; Transport",
    "Der gr&uuml;ne Rohkaffee wird verlesen, nach Gr&ouml;&szlig;e sortiert und in S&auml;cken "
    "verschifft. Er h&auml;lt Monate &ndash; das Aroma entsteht erst beim R&ouml;sten."),
 st("flame", 5, "Trommelr&ouml;stung",
    "12 bis 20&nbsp;Minuten bei 180 bis 220&nbsp;&deg;C dreht sich die Trommel. Zucker karamellisiert, "
    "S&auml;uren bauen sich ab, &Ouml;le treten aus. Beim &bdquo;First Crack&ldquo; knackt die Bohne "
    "h&ouml;rbar &ndash; ab hier entscheidet sich der R&ouml;stgrad."),
 st("cup", 6, "Mahlen &amp; Br&uuml;hen",
    "Erst kurz vor dem Bezug mahlen. Im Vollautomaten presst die Pumpe hei&szlig;es Wasser mit rund "
    "9&nbsp;bar in 25 bis 30&nbsp;Sekunden durch das Kaffeemehl. Mahlgrad, Menge und Wasser bestimmen, "
    "was in der Tasse ankommt."),
]) + '\n</div>'

def vrow(k, a, r):
    return ('<div class="kw-vs-row"><span class="kw-vs-k">' + k + '</span>'
            '<span class="kw-vs-v">' + a + '</span><span class="kw-vs-v">' + r + '</span></div>')

vs = ('<div class="kw kw-vs">\n<div class="kw-vs-head"><div>Arabica</div><div>Robusta</div></div>\n'
      + vrow("Geschmack", "fein, aromatisch, oft fruchtig oder blumig", "kr&auml;ftig, erdig, nussig, mehr Bitterkeit")
      + vrow("Koffein", "ca. 1,2&nbsp;%", "ca. 2,2&nbsp;%")
      + vrow("Anbauh&ouml;he", "900&ndash;2000&nbsp;m", "200&ndash;800&nbsp;m")
      + vrow("S&auml;ure", "h&ouml;her, lebendiger", "niedrig, mild")
      + vrow("Crema", "fein, hell", "dicht, stabil, dunkler")
      + vrow("Anteil Weltmarkt", "rund 60&nbsp;%", "rund 40&nbsp;%")
      + vrow("Preis", "h&ouml;her", "g&uuml;nstiger")
      + '\n</div>')

roast = ('<div class="kw kw-roast">\n<div class="kw-roast-bar"></div>\n<div class="kw-roast-marks">'
 '<div class="kw-roast-m"><b>Hell</b><span>Zimt- bis Filterr&ouml;stung: viel S&auml;ure, floral-fruchtig, '
 'kaum Bitterstoffe, trockene Oberfl&auml;che.</span></div>'
 '<div class="kw-roast-m"><b>Mittel</b><span>z.&nbsp;B. unser Caff&egrave; Crema: ausgewogen, Karamell und Nuss, '
 'moderate S&auml;ure.</span></div>'
 '<div class="kw-roast-m"><b>Dunkel</b><span>Espresso- bis italienische R&ouml;stung: kr&auml;ftige '
 'R&ouml;staromen, Bitterschokolade, sichtbare &Ouml;le.</span></div>'
 '</div>\n<div class="kw-tx">Unsere beiden R&ouml;stungen liegen im Bereich mittel bis mittel-dunkel &ndash; '
 'abgestimmt auf den Bezug aus dem Vollautomaten.</div>\n</div>')

def sort_card(name, ap, rp, tags, forx):
    tg = ''.join('<span>' + t + '</span>' for t in tags)
    return ('<div class="kw-sort"><div class="kw-sort-h">' + name + '</div>'
            '<div class="kw-blendrow"><span class="a">' + str(ap) + '&nbsp;% Arabica</span>'
            '<span class="r">' + str(rp) + '&nbsp;% Robusta</span></div>'
            '<div class="kw-blend"><i class="a" style="width:' + str(ap) + '%"></i><i class="r"></i></div>'
            '<div class="kw-tags">' + tg + '</div>'
            '<div class="kw-sort-for">' + forx + '</div></div>')

sorts = ('<div class="kw kw-sorts">\n'
 + sort_card("Caff&egrave; Crema", 60, 40, ["nussig", "schokoladig", "mild bis kr&auml;ftig"], "Ideal f&uuml;r Kaffeevollautomaten")
 + '\n'
 + sort_card("Espresso", 80, 20, ["nussig", "r&ouml;stig", "kr&auml;ftig"], "Ideal f&uuml;r Vollautomaten &amp; Siebtr&auml;germaschinen")
 + '\n</div>')

buy = ('<div class="kw kw-buy">\n'
 '<div class="kw-buy-c"><div class="kw-buy-h">' + IC["shop"] + ' Direkt bei uns</div><ul>'
 '<li>Im Gesch&auml;ft in Hofheim-Langenhain</li>'
 '<li>Im Online-Shop &ndash; deutschlandweit</li></ul></div>\n'
 '<div class="kw-buy-c"><div class="kw-buy-h">' + IC["pin"] + ' Regionale Partner</div>'
 '<div class="kw-buy-feat"><div class="kw-buy-feat-h">In enger Kooperation: Paolo <span>Nahkauf &amp; Nahkauf&nbsp;Box</span></div><ul>'
 '<li>Nahkauf Paolo &ndash; Diedenbergen</li>'
 '<li>Nahkauf&nbsp;Box Paolo, rund um die Uhr &ndash; Langenhain</li>'
 '<li>Nahkauf&nbsp;Box Paolo, rund um die Uhr &ndash; Lorsbach'
 '<span class="kw-buy-note">Hier gibt es rund um die Uhr auch frisch gebr&uuml;hten Kaffee aus einem JURA-Standautomaten.</span></li>'
 '</ul></div>'
 '<ul><li>Sonnenhof R&uuml;bsamen &ndash; Langenhain</li></ul></div>\n</div>')

p["blocks"] = [
 {"t": "p", "x": "Ein Kaffeevollautomat kann aus einer Bohne nur herausholen, was in ihr steckt. Deshalb lohnt der Blick auf Herkunft, Aufbereitung und R\u00f6stung \u2013 und darauf, wie Sie den Kaffee zu Hause behandeln. Wir r\u00f6sten selbst: in kleinen Mengen, schonend in der Trommel, damit immer frische Ware im Regal steht."},
 {"t": "image", "src": "https://new.kaffeetechniker.de/wp-content/uploads/2026/09/kt-unser-kaffee-beutel.jpg", "alt": "Unser Kaffee \u2013 eigene R\u00f6stung im 1000-g-Beutel mit Aromaventil", "max": "620px"},

 {"t": "h", "lvl": 2, "icon": "coffee", "x": "Warum die Bohne \u00fcber den Kaffee entscheidet"},
 {"t": "p", "x": "Guter Kaffee ist das Ergebnis einer langen Kette: Anbaubedingungen, Kaffeesorte, Mischung, R\u00f6stung, eine kurze Lagerzeit, die passende Mahlung und ein gutes Br\u00fchsystem. Jedes Glied kann das Ergebnis heben oder dr\u00fccken."},
 {"t": "p", "x": "Die ersten Glieder beeinflussen wir mit Auswahl und R\u00f6stung. Die letzten liegen bei Ihnen zu Hause \u2013 frische Bohnen, richtige Lagerung, passender Mahlgrad und eine saubere, entkalkte Maschine."},

 {"t": "h", "lvl": 2, "icon": "map", "x": "Von der Kirsche in die Tasse"},
 {"t": "p", "x": "Kaffee ist die Frucht eines Strauchs. Was zwischen Bl\u00fcte und R\u00f6stung passiert, legt S\u00fc\u00dfe, S\u00e4ure und K\u00f6rper im fertigen Getr\u00e4nk fest \u2013 lange bevor die Maschine ins Spiel kommt."},
 {"t": "html", "x": journey},

 {"t": "h", "lvl": 2, "icon": "compare", "x": "Arabica und Robusta \u2013 zwei Bohnen, zwei Charaktere"},
 {"t": "p", "x": "Fast der gesamte Welthandel besteht aus diesen zwei Arten. Sie unterscheiden sich in Geschmack, Koffein und Anbau deutlich."},
 {"t": "html", "x": vs},
 {"t": "p", "x": "Die meisten R\u00f6stungen \u2013 auch unsere \u2013 sind Mischungen. Mehr Robusta bringt K\u00f6rper, eine dichtere Crema und einen kr\u00e4ftigen, r\u00f6stigen Ton. Mehr Arabica macht die Tasse feiner, s\u00fc\u00dfer und aromatischer."},

 {"t": "h", "lvl": 2, "icon": "coffee", "x": "R\u00f6stung: warum wir langsam in der Trommel r\u00f6sten"},
 {"t": "p", "x": "In der Trommel wird die Bohne \u00fcber Kontakt- und Umluftw\u00e4rme gleichm\u00e4\u00dfig durchger\u00f6stet \u2013 anders als bei industrieller Hei\u00dfluftr\u00f6stung, die in rund 90&nbsp;Sekunden durch ist und au\u00dfen dunkel, innen unfertig bleiben kann. Wir r\u00f6sten 12 bis 20&nbsp;Minuten und in kleinen Chargen, damit immer frisch ger\u00f6steter Kaffee ins Regal kommt."},
 {"t": "html", "x": roast},
 {"t": "p", "x": "Frisch aus der Trommel braucht Kaffee ein paar Tage Ruhe, um R\u00f6stgase abzugeben. Sein Aroma-Optimum h\u00e4lt dann etwa zwei bis vier Wochen \u2013 danach wird die Tasse flacher."},

 {"t": "h", "lvl": 2, "icon": "coffee", "x": "Unsere zwei Sorten"},
 {"t": "html", "x": sorts},
 {"t": "p", "x": "Beide gibt es frisch ger\u00f6stet im 1000-g-Beutel mit Aromaventil. Das Ventil l\u00e4sst R\u00f6stgase entweichen, ohne Sauerstoff hereinzulassen."},

 {"t": "h", "lvl": 2, "icon": "check", "x": "So schmeckt Ihr Kaffee zu Hause am besten"},
 {"t": "p", "x": "Die letzten Schritte entscheiden mit. Ein paar Punkte, die im Vollautomaten den gr\u00f6\u00dften Unterschied machen:"},
 {"t": "ul", "x": [
   "Mahlgrad: schmeckt der Kaffee d\u00fcnn und sauer, feiner mahlen. Wird er bitter und die Ausgabe stockt, gr\u00f6ber stellen \u2013 in kleinen Schritten und erst nach ein, zwei Bez\u00fcgen bewerten.",
   "Kaffeemenge: 7 bis 11&nbsp;Gramm pro Tasse. Mehr Pulver bringt K\u00f6rper und Crema, weniger macht die Tasse leichter.",
   "Wasser: die Tasse besteht zu \u00fcber 98&nbsp;% aus Wasser. Weiches oder gefiltertes Wasser schmeckt sauberer und sch\u00fctzt die Maschine vor Kalk.",
   "Temperatur: 90 bis 96&nbsp;\u00b0C. Zu hei\u00df wird bitter, zu k\u00fchl bleibt es sauer und d\u00fcnn.",
   "Frische: Bohnen innerhalb von zwei bis vier Wochen nach der R\u00f6stung verbrauchen, offene Beutel z\u00fcgig leeren.",
 ]},
 {"t": "callout", "variant": "ok", "title": "Bohnen richtig lagern", "intro": "Aroma verliert Kaffee vor allem durch Sauerstoff, W\u00e4rme, Licht und Feuchtigkeit.", "x": [
   "k\u00fchl, dunkel und luftdicht lagern \u2013 die Originalt\u00fcte mit Aromaventil und Clip gen\u00fcgt",
   "nicht in den K\u00fchlschrank oder das Gefrierfach: Kondenswasser und fremde Ger\u00fcche schaden mehr, als die K\u00fchle n\u00fctzt",
   "nur so viel kaufen, wie in zwei bis vier Wochen getrunken wird",
   "den Bohnenbeh\u00e4lter der Maschine nicht auf Vorrat randvoll f\u00fcllen",
 ]},
 {"t": "callout", "variant": "warn", "title": "Typische Fehler \u2013 was Aroma und Maschine kostet", "x": [
   "Kaffee auf Monate im Voraus kaufen \u2013 das Aroma ist dann l\u00e4ngst verflogen",
   "Bohnen im K\u00fchl- oder Gefrierschrank lagern",
   "stark ge\u00f6lte, sehr dunkle Espressobohnen im Vollautomaten \u2013 sie verkleben Mahlwerk und Br\u00fchgruppe",
   "die Maschine nicht regelm\u00e4\u00dfig entkalken und reinigen \u2013 Kalk und altes Kaffeefett dr\u00fccken den Geschmack sp\u00fcrbar",
   "das Mahlwerk extrem fein stellen \u2013 die Ausgabe stockt und der Antrieb arbeitet dauerhaft gegen den Widerstand",
 ]},

 {"t": "h", "lvl": 2, "icon": "shop", "x": "Wo Sie unseren Kaffee bekommen"},
 {"t": "html", "x": buy},
 {"t": "btns", "keep": True, "x": [
   {"label": "Unser Kaffee &amp; Tee", "url": "/unser-kaffee/"},
   {"label": "Im Gesch\u00e4ft vorbeikommen", "url": "/anfahrt/"},
 ]},
]

json.dump(d, open(PC, "w", encoding="utf-8-sig"), ensure_ascii=False, indent=2)
print("blocks:", len(p["blocks"]), "| h2s:", sum(1 for b in p["blocks"] if b["t"] == "h"))
