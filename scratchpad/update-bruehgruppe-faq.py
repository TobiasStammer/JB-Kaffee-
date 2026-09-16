# -*- coding: utf-8 -*-
import json

PC = r"C:\Homepage\Neue Seite 2026\faq-content.json"
f = json.load(open(PC, encoding="utf-8-sig"))
pages = {p["slug"]: p for p in f["pages"]}

# ---------- 1) stoerung-bruehgruppe ----------
p = pages["stoerung-bruehgruppe"]
p["excerpt"] = "Betrifft Ger\u00e4te mit herausnehmbarer Br\u00fchgruppe, z.\u00a0B. NIVONA \u2013 bei JURA (fest verbaut) kommt das nicht vor."
p["blocks"] = [
  {"t": "p", "x": "Betrifft Ger\u00e4te mit herausnehmbarer Br\u00fchgruppe, zum Beispiel NIVONA, Saeco, Philips, Melitta oder De\u2019Longhi. L\u00e4sst sie sich nicht einsetzen, steht das Getriebe im Ger\u00e4t nicht in der richtigen Position."},
  {"t": "callout", "title": "JURA betroffen?", "x": [
      "JURA-Kaffeevollautomaten haben eine fest verbaute Br\u00fchgruppe \u2013 sie l\u00e4sst sich nicht herausnehmen, und dieses Problem kommt bei JURA entsprechend nicht vor.",
      "Reagiert ein JURA trotzdem nicht mehr richtig, liegt eine andere Ursache vor \u2013 bringen Sie es zur Diagnose vorbei oder rufen Sie an: 06192\u00a02004363."
  ]},
  {"t": "h", "lvl": 2, "x": "So geht es meistens wieder"},
  {"t": "ul", "x": [
      "Satzschublade und Abtropfschale einsetzen, Servicet\u00fcr schlie\u00dfen",
      "Ger\u00e4t ohne eingesetzte Br\u00fchgruppe aus- und wieder einschalten",
      "Nach einem kurzen, h\u00f6rbaren Motorenger\u00e4usch steht das Getriebe in Grundstellung",
      "Jetzt l\u00e4sst sich die Br\u00fchgruppe einsetzen \u2013 auf \u00fcbereinstimmende Markierungen und ge\u00f6ffnete Verriegelungshaken achten"
  ]},
  {"t": "h", "lvl": 2, "x": "Br\u00fchgruppe reinigen"},
  {"t": "p", "x": "Nur unter warmem Wasser absp\u00fclen, kein Sp\u00fclmittel, nicht in die Sp\u00fclmaschine. Bewegliche Teile sparsam mit einem lebensmittelechten Fett schmieren (im Fachhandel als \u201eBr\u00fchgruppen-Fett\u201c)."},
  {"t": "h", "lvl": 2, "x": "Wann in die Werkstatt"},
  {"t": "p", "x": "Wenn sich das Getriebe nicht in Grundstellung bringen l\u00e4sst oder die Br\u00fchgruppe besch\u00e4digt ist. Ein festsitzendes Getriebe ist ein h\u00e4ufiger Reparaturfall."}
]

# ---------- 2) pflege-bruehgruppe ----------
p = pages["pflege-bruehgruppe"]
p["excerpt"] = "JURA (fest verbaut) und NIVONA (herausnehmbar) im Vergleich \u2013 Reinigungsprogramm und der Restwasserkanal."
p["blocks"] = [
  {"t": "p", "x": "Kaffeefett und Pulverreste setzen sich mit der Zeit in der Br\u00fchgruppe und im Kaffeeweg ab. Das kostet Aroma und Durchfluss. Wie Sie pflegen, h\u00e4ngt vom Hersteller ab: JURA hat eine fest verbaute Br\u00fchgruppe, NIVONA eine herausnehmbare."},
  {"t": "callout", "title": "JURA oder NIVONA \u2013 fest oder herausnehmbar?", "x": [
      "JURA: Br\u00fchgruppe fest verbaut, keine Servicet\u00fcr zum Herausnehmen \u2013 Pflege ausschlie\u00dflich \u00fcber das Reinigungsprogramm.",
      "NIVONA: Br\u00fchgruppe herausnehmbar hinter der Servicet\u00fcr \u2013 zus\u00e4tzlich von Hand absp\u00fclbar."
  ]},
  {"t": "h", "lvl": 2, "x": "Reinigungsprogramm (JURA und NIVONA)"},
  {"t": "p", "x": "F\u00fchren Sie das ger\u00e4teeigene Reinigungsprogramm mit einer Reinigungstablette durch, sobald das Ger\u00e4t dazu auffordert \u2013 bei Vielnutzung eher \u00f6fter. Das l\u00f6st Kaffeefett im gesamten Br\u00fchweg, bei beiden Bauarten."},
  {"t": "h", "lvl": 2, "x": "JURA \u2013 fest verbaute Br\u00fchgruppe"},
  {"t": "p", "x": "Bei JURA l\u00e4sst sich die Br\u00fchgruppe nicht entnehmen \u2013 es gibt keine Servicet\u00fcr daf\u00fcr. Die Reinigung \u00fcbernimmt das Ger\u00e4t selbst: Beim Ein- und Ausschalten sp\u00fclt es automatisch, dazu kommt regelm\u00e4\u00dfig das Reinigungsprogramm."},
  {"t": "ul", "x": [
      "Kein \u00d6ffnen oder Ausbauen n\u00f6tig \u2013 und bei aktuellen JURA-Modellen auch nicht m\u00f6glich",
      "Reinigungsprogramm regelm\u00e4\u00dfig durchf\u00fchren, bei Vielnutzung \u00f6fter als vom Ger\u00e4t vorgeschlagen",
      "Die gr\u00fcndliche Innenreinigung \u00fcbernehmen wir im Rahmen der Wartung"
  ]},
  {"t": "h", "lvl": 2, "x": "NIVONA \u2013 herausnehmbare Br\u00fchgruppe"},
  {"t": "ul", "x": [
      "\u00dcber die Servicet\u00fcr entnehmen und unter warmem Wasser absp\u00fclen \u2013 ohne Sp\u00fclmittel, nicht in die Sp\u00fclmaschine",
      "Gut trocknen lassen, bewegliche Teile sparsam mit lebensmittelechtem Fett schmieren",
      "Etwa alle ein bis zwei Wochen, bei t\u00e4glicher Nutzung auch \u00f6fter"
  ]},
  {"t": "h", "lvl": 2, "x": "Kaffeeauslauf und Restwasserkanal"},
  {"t": "p", "x": "Den Auslauf regelm\u00e4\u00dfig abnehmen und reinigen. Bei einigen Ger\u00e4ten mit herausnehmbarer Br\u00fchgruppe verstopft der Ablauf-/Restwasserkanal \u2013 hier hilft nur Zerlegen. Bei JURA \u00fcbernimmt die gr\u00fcndliche Innenreinigung des Kaffeewegs die Werkstatt im Zuge der Wartung."}
]

# ---------- 3) stoerung-kaffee-langsam: bullet praezisieren ----------
p = pages["stoerung-kaffee-langsam"]
for b in p["blocks"]:
    if b.get("t") == "ul":
        b["x"] = [
            "Ger\u00e4t gr\u00fcndlich entkalken (mit korrekt eingestelltem Wasserh\u00e4rtegrad)" if x.startswith("Ger\u00e4t gr\u00fcndlich")
            else "Reinigungsprogramm mit einer Reinigungstablette durchf\u00fchren" if x.startswith("Reinigungsprogramm")
            else "Br\u00fchgruppe reinigen: bei NIVONA herausnehmen und unter warmem Wasser absp\u00fclen (ohne Sp\u00fclmittel, nicht in die Sp\u00fclmaschine); bei JURA (fest verbaut) stattdessen das Reinigungsprogramm durchf\u00fchren" if "Herausnehmbare Br\u00fchgruppe" in x
            else x
            for x in b["x"]
        ]

# ---------- 4) stoerung-kaffeesatz-nass: bullet praezisieren ----------
p = pages["stoerung-kaffeesatz-nass"]
for b in p["blocks"]:
    if b.get("t") == "ul":
        b["x"] = [
            "Br\u00fchgruppe verschmutzt oder verklebt \u2013 reinigen (bei NIVONA herausnehmbar, bei JURA \u00fcber das Reinigungsprogramm; siehe \u201eBr\u00fchgruppe & Kaffeeweg reinigen\u201c)" if x.startswith("Br\u00fchgruppe verschmutzt")
            else x
            for x in b["x"]
        ]

# ---------- 5) stoerung-abtropfschale: bullet praezisieren ----------
p = pages["stoerung-abtropfschale"]
for b in p["blocks"]:
    if b.get("t") == "ul":
        b["x"] = [
            "Bei Ger\u00e4ten mit herausnehmbarer Br\u00fchgruppe (z.\u00a0B. NIVONA): sitzt diese korrekt in Grundstellung?" if x.startswith("Bei Ger\u00e4ten mit Br\u00fchgruppe")
            else x
            for x in b["x"]
        ]

json.dump(f, open(PC, "w", encoding="utf-8-sig"), ensure_ascii=False, indent=2)
print("done")
