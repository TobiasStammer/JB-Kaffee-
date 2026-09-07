# Content- & Design-Vorlage: kaffeetechniker.de → new.kaffeetechniker.de

Quelle: https://www.kaffeetechniker.de (Firma Joachim Blöchle Elektro-Service GmbH),
ausgelesen am 2026-08-28. Ziel: new.kaffeetechniker.de (WordPress, Theme
"Extendable"/FSE-Blocktheme, WooCommerce aktiv) soll dieselbe Seitenstruktur,
denselben Inhalt und dasselbe Design/Farbschema bekommen.

## Design-Tokens (aus der Live-Seite ausgelesen)

| Element | Wert |
|---|---|
| Seitenhintergrund | `#eeeeee` |
| Fließtext-Farbe | `#000000` |
| Überschriften-Farbe | `#333333` |
| Navigation: Hintergrund | `#000000` |
| Navigation: Text | `#ffffff` |
| Buttons: Hintergrund | `#919191` |
| Buttons: Text | `#463939` |
| Schrift Überschriften/Navigation | Tahoma, Fallback: `"Tahoma Fallback", Arial, sans-serif` |
| Schrift Fließtext | "Source Sans Pro" (Google Font), Fallback: `sans-serif` |

Kein auffälliger Akzent-/Markenfarbton gefunden — die Seite ist bewusst
monochrom (Grau/Schwarz/Weiß) gehalten. Beim Nachbau in Gutenberg-Blöcken diese
Farben direkt als Block-Styles (Hintergrund-/Textfarbe) setzen, da der
claude-integration-Nutzer keinen Zugriff auf globale Theme-Einstellungen hat,
aber Farben pro Block im Seiteninhalt setzen kann.

## Logo & Favicon (Quell-URLs, zeitlich begrenzt gültig — zuerst herunterladen und in die WP-Mediathek hochladen, nicht verlinken)

- Logo: `https://le-cdn.website-editor.net/s/b2fc05ff53384b93b50c9852b3edd61a/dms3rep/multi/opt/Joachim-Bl%C3%B6chle-Elektro-Service-Logo-1920w.jpg?Expires=1790493006&Signature=YW5Ehgjq8UgxvuZ8hqwmeXaZG~1mwYCAKorsTU~VvkN4IUjWmdBGjo3l877rfi497gX9PrxShEyZQ5OsS2p4rI1sZQ~kaxN1DENFN5vPXiTm5wac49jQNfScHjSGTW77pFD~cDLn80WCbBsc5TthmUQaFbHQXVmltjoER1rxZDs8RYgN7TgjkJCeTmAVKd7X3XyfSpyeLKVbaKH~9EyiQYPHZ0YnihpJk0R5k8G669rQ9-Uqu0Ze5uM~yqQhuwfksYl0WnRtFuEQ86yXoHLlFirerS84cZWi1o5FgOIQVosMdaDTBLgcqSYoLkqogF~QCMrnrc0Zl8uwxfrUAi61Qw__&Key-Pair-Id=K2NXBXLF010TJW`
- Favicon/Logo grau: `https://cdn.website-editor.net/s/b2fc05ff53384b93b50c9852b3edd61a/dms3rep/multi/JB_Logo_grau_hoch.jpg?Expires=1790493006&Signature=h4X9d4BZzghJeoZY9634t4j8XEXfb3agmse1J8HeRvAxRXpzyU9eUo672Zzh9DuJkj5fqwXkKzkoXB9Y0vBGZ0MI6S9ishS-I2bsghHJCvjqtqH3E9UA3l3HLD~mRrUkM7ZyY7nC04F0E60UkqZXgDY-HC5KSk3FEf~b47MkbQE6rTpFIDUTMU9LhvKwkzfDsxJ9CgRtKTq~iKP-0tHh51Pj1XYimKv0UlHFm4pWR2oDVU4CSSaiqhpVJ8waNGqj2AmHUR2fcnTejrcG3C~GVFGZVTG~JHsLwZBNvAmL9JuHcRKtvBWmD7kjcJxgIfJU35z1NzG5CB6aADBeIxdpqw__&Key-Pair-Id=K2NXBXLF010TJW`

## Firmen-/Kontaktdaten (für Footer, Kontaktseite, Impressum-Hinweis)

- Firma: Joachim Blöchle Elektro-Service GmbH (gegründet 1961)
- Adresse: Wallauer Str. 4, 65719 Hofheim-Langenhain
- Telefon: 06192 2004363
- E-Mail: info@kaffeetechniker.de
- Öffnungszeiten: Mo–Do 8:00–16:00 Uhr, Fr 8:00–13:00 Uhr, Sa geschlossen
- Lage: zwischen Wiesbaden, Mainz und Frankfurt, ca. 6 km vom Wiesbadener Kreuz, Ortsteil Langenhain

## Seitenstruktur

> **Update 2026-08-28:** Die 1:1-Übernahme unten ist überholt. Maßgeblich ist
> jetzt die neu geordnete Gliederung in **`SEITENSTRUKTUR-NEU.md`** (6 Haupt-
> kategorien, komplette Original-Struktur ausgewertet). Die Liste unten bleibt
> als Referenz für die Reihenfolge der bereits gebauten 10 Seiten stehen.

### (überholt) Navigation der Originalseite, ursprünglich 1:1 geplant

1. **Start** (`/`) — Startseite
2. **Reparatur** (`/reparatur`)
3. **Marken** (`/marken`)
4. **Reparaturablauf** (`/reparaturablauf`)
5. **Reparaturdauer** (`/reparaturdauer`)
6. **Reparaturkosten** (`/reparaturkosten`)
7. **Gewährleistung** (`/gewaehrleistung`)
8. **Service** (`/service`)
9. **Wartung** (`/wartung`)
10. **Mietgeräte** (`/leihgeraete`)

Alle als WordPress-**Seiten** (nicht Beiträge) anlegen, Navigationsmenü in
dieser Reihenfolge erstellen und dem Theme zuweisen. Startseite in den
Einstellungen als statische Startseite setzen.

---

## Seiteninhalte (Rohtext aus der Originalseite, für den Nachbau als Gutenberg-Blöcke aufbereiten)

### 1. Start (/)
Titel: "Wartung von Kaffeevollautomaten in der Taunus Region"
Meta-Beschreibung: "JURA Kaffeemaschinen | Reparatur aller Hersteller | Wartung | JB Kaffeemaschinen | Region Taunus | Rhein Main | Hofheim"

Hero: "Ihre Kaffeemaschine ist defekt oder muss gewartet werden? Wir reparieren
sie schnell und zuverlässig – damit Sie schon bald wieder Ihren
Lieblingskaffee genießen können." — Buttons: "Kontaktieren Sie uns",
"Auftragsschein Download"

Unterüberschrift: "Ihr Partner für Reparatur und Wartung von Kaffeemaschinen
in Hofheim und der Taunusregion"

Text: Wir bieten kompetente und schnelle Reparatur / Wartung für
Kaffeemaschinen der Marken Jura, Saeco, DeLonghi, Philips, Siemens, AEG,
Bosch, Nivona, Melitta und Miele sowie für Siebträger der Firmen La Pavoni und
ECM in unserer Fachwerkstatt an. Wir sind autorisierte Servicestelle von und
für ihren JURA Kaffeevollautomat. Eine genaue Hersteller- und
Modellübersicht der Geräte, die wir bearbeiten finden Sie unter dem
Menüpunkt Marken. Wir reparieren Ihre Geräte außerhalb der
Herstellergarantie. Als Autorisierte JURA Servicestelle können wir alle JURA
Geräte auch in der Gewährleistung reparieren.

Über uns: Die Joachim Blöchle Elektro-Service GmbH (Gründung 1961) ist ein
professioneller Fachbetrieb mit über 30-jähriger Erfahrung und hat sich
ausschließlich auf Kaffeevollautomaten und Espressomaschinen spezialisiert.
Unser Ziel ist es, jeden Auftrag sorgfältig, schnell und zu Ihrer vollsten
Zufriedenheit auszuführen. Dieses Ziel erreichen wir mit einem Team aus gut
ausgebildeten und motivierten Mitarbeitern, die mit Spaß und Liebe zum
Detail arbeiten.

Eine Reparatur und Wartung Ihres Kaffeevollautomaten lohnt sich in den
allermeisten Fällen im Vergleich zur Neuanschaffung. Auch die
Kaffeeprodukte haben wieder die gewohnte Qualität. Um die einwandfreie
Funktion ihres Kaffeevollautomaten zu erhalten, ist es wichtig, das Gerät
regelmäßig zu reinigen, zu pflegen und zu entkalken. Die hierzu passenden
Pflegeprodukte führen wir für Sie. Wir liefern Zubehör, Ersatzteile und
Kaffee.

Vorteile-Liste (z. B. als Icon-/Checklisten-Block):
- 30 Jahre Erfahrung bei der Reparatur von Kaffeevollautomaten der beworbenen Marken und Modelle
- Reparaturen in eigener Werkstatt
- Umfangreiches Ersatzteillager
- Keine Pauschalpreise: Reparaturkosten individuell nach Zeitaufwand und Ersatzteilen
- Wir berücksichtigen Ihre Wünsche bei der Reparatur
- Wir nehmen uns Zeit für Sie
- Regelmäßige Fort- und Weiterbildung unserer Mitarbeiter

Kontaktformular-Felder (Contact Form 7 / natives Formular nachbauen): Name*,
Email*, Telefon*, Hersteller (Dropdown: AEG, Bosch, De Longhi, ECM, Gaggia,
JURA, La Pavoni, Melitta, Miele, Nivona, Philips, Saeco, SAGE, Siemens),
Modell, Nachricht

Footer-Zeile: "Zwischen Wiesbaden, Mainz und Frankfurt am Main gelegen,
finden Sie uns gut angebunden in Hofheim-Langenhain."
CTA am Ende: "Haben Sie eine defekte Kaffeemaschine, die Sie reparieren
lassen möchten? Rufen Sie uns an!" — Button "Jetzt Kaffeemaschine
reparieren lassen"

### 2. Reparatur (/reparatur)
Titel: "REPARATUR VON KAFFEEMASCHINEN UND SIEBTRÄGERMASCHINEN IM
RHEIN-MAIN-GEBIET"

Intro: Wir reparieren Ihre Kaffeemaschine schnell und zuverlässig. Außerdem
beraten wir Sie, ob eine Reparatur für Ihr Gerät noch in Frage kommt oder ob
sich eine Neuanschaffung für Sie eher lohnt.

**Ihre Kaffeemaschine ist ein Athlet** — Kaffeevollautomaten sind technisch
aufwändige Geräte und erfüllen ihre Funktion durch ein Zusammenspiel von
vielen elektrischen und mechanischen Komponenten. Kein anderes Haushaltsgerät
wie Fernseher, Waschmaschine, Trockner oder Kühlschrank muss derart
verschiedene und hohe Belastungen aushalten. Bei der Kaffeeproduktion im
Vollautomaten entsteht eine brisante Kombination von Betriebsbedingungen:
enge Kombination von Wasser und stromführenden Teilen im Gehäuse,
Wasserdampf nach Brühen und Schäumen im Innenraum, hohe Temperaturen bis 160
Grad bei der Dampfproduktion, hohe Wasserdrücke beim Brühen (6–8 bar
Brühdruck laut einer Projektarbeit der Hochschule Regensburg), hohe
mechanische Belastung des Antriebs und der Brühgruppe, komplizierte
mechanische Bewegungen, Mahlen und Transport von Feststoffen — alles kompakt
in ein kleines Gehäuse eingebaut. So betrachtet ist Ihr Kaffeevollautomat
der Athlet im Haushalt, der viel mehr aushalten und leisten muss als der
Rest Ihrer Geräte.

**Ihre Kaffeemaschine ist defekt** — funktioniert nicht mehr, ist undicht,
macht laute Geräusche oder liefert schlechte Produkte? Wir unterstützen Sie
gerne bei der Entscheidung pro oder contra Reparatur. In den allermeisten
Fällen ist die Reparatur die bessere Alternative. Wir reparieren Geräte der
Marken Jura, Saeco, DeLonghi, Philips, Siemens, AEG, Bosch, Nivona, Melitta,
La Pavoni und Spidem. Details siehe Menüpunkt Marken. Wir reparieren nur
außerhalb der 2-jährigen Herstellergarantie.

**Lohnt sich eine Reparatur oder Wartung?** Individuelle Entscheidung
abhängig von Reparaturkosten, Alter, Zustand, Zufriedenheit.

Für eine Reparatur spricht: Sie kennen ihr Gerät bereits gut / wesentlich
billiger als Neuanschaffung / kein Elektroschrott / langlebiger Einsatz /
Grundtechnik seit Jahren kaum verändert / kein Energiesparpotenzial bei
Neugeräten.

Für eine Neuanschaffung spricht: 2 Jahre Herstellergarantie / hohe
Reparaturkosten am Altgerät / schlechter Gesamtzustand / fehlende Funktionen.

**Kurzinfo zur Reparatur** (Liste): genaue Fehlerbeschreibung hilft; keine
telefonischen Kostenvoranschläge ohne Untersuchung; gründliche Prüfung in
der Werkstatt; keine Pauschalpreise, individuelle Kalkulation; empfohlen:
Reparaturbetrag freigeben; alternativ Fehlerdiagnose + Kostenvoranschlag;
Kostenpauschale 60 € falls Reparatur laut Kostenvoranschlag nicht
ausgeführt wird; Wartung/Reinigung im Zuge der Reparatur inklusive;
Abschlusstest nach Reparatur; detaillierte Rechnung; 12 Monate
Gewährleistung auf eingebaute Ersatzteile.

CTA: "Möchten Sie wissen, wie wir Ihren Kaffeevollautomaten wieder zum
Laufen bringen können? Rufen Sie uns einfach an." — Button "Jetzt beraten
lassen"

### 3. Marken (/marken)
Titel: "MARKEN" — "Diese Kaffeemaschinen reparieren wir für Sie"

Intro: Wir bearbeiten gängige Hersteller und Modelle von Kaffeevollautomaten
und Siebträgermodellen außerhalb der Herstellergarantie. Im Zweifelsfall
bitte kontaktieren.

**Kaffeevollautomaten** (je Marke als eigener Abschnitt/Akkordeon):
- **Jura**: Home-Serien A, Classic, C, D, E, F, J, S, Z, Scala, Ultra, ENA, ENA Micro, Impressa, Ono; Gastro: WE, XS, XF, XJ, X, Giga
- **DeLonghi**: EAM-, ESAM-, ECAM-, EPAM-, ETAM-Serien (Intensa, Magnifica, Perfecta, Prima Donna, Eletta, Autentica, Dinamica); Einbaugeräte auf Anfrage
- **Philips**: Exprelia, Syntia, Minuto, Moltio, Xelsis, Incanto, Intelia, Gran Baristo, Pico Baristo, HDxxxx, EPxxxx, SMxxxx, Serien 2000–5000
- **Siemens**: Surpresso, CT-, TK-, EQ-Serie (außer EQ 3/300er, EQ5/500er); Einbaugeräte auf Anfrage
- **AEG**: Caffe Silenzio, Caffe Grande, CaFamosa
- **Bosch**: TCA, TCC, TKN, CTL, TES, Benvenuto, VeroCafe, VeroCafeLatte, VeroAroma, VeroBar, VeroProfessional, VeroSelection, VeroCup; Einbaugeräte auf Anfrage
- **Spidem**: Villa, Trevi, My Coffee, Divina
- **Gaggia**: Accademia, Titanum, Syncrony, Platinum, Baby Twin, Classic
- **Saeco**: Syntia, Xelsis, Exprelia, Minuto, Moltio, Incanto, Intelia, Magic, Royal, Stratos, Odea, Talea, Primea, Vienna, Caffee Nova, XSmall, Gran Baristo, Lyrika, Pico Baristo
- **Nivona**: Crema, Master, Palazzo, CafeRomantica, NICR
- **Miele**: CM5xxx, CM6xxx, CM7xxx; CVA Einbaugeräte auf Anfrage
- **Melitta**: Caffeo Bistro, Solo, Lounge, Lattea, Gourmet, CI, Barista, Varianza, Barista TS/T, Passione, Purista

**Siebträgermaschinen**:
- **ECM**: Casa, Classica, Mechanika, Technika, Elektronika, Synchronika, Compact, Barista, Controvento, Espressomühlen
- **La Pavoni**: Europiccola, Professional, Gran Caffee (Handhebel- und Siebträgermodelle)

Hinweis: nicht gelistete Hersteller/Modelle werden nicht repariert; bei
Unsicherheit bitte kontaktieren.

Begründung für Beschränkung auf gelistete Modelle: Erfahrung aus vielen
Reparaturen, Lagerbestand an Verschleiß-/Ersatzteilen, schnelle
Ersatzteilbestellung, vorhandene Reparaturanleitungen/Schaltpläne/
Explosionszeichnungen/Teilelisten.

CTA: "Reparatur in Auftrag geben" — Auftragsschein-Download-Button; "Jetzt
anrufen"-Button.

### 4. Reparaturablauf (/reparaturablauf)
Titel: "REPARATURABLAUF"
Intro: Geben Sie Ihre defekte Kaffeemaschine in professionelle Hände und
profitieren Sie von unserer einjährigen Gewährleistung auf von uns
durchgeführte Reparaturen.

**1. Abgabe in der Werkstatt** — Gerät komplett mit Zubehör (Abtropfschale,
Abtropfgitter, Satzbehälter, Wassertank, Aufschäumer) innerhalb der
Öffnungszeiten abgeben. Fehlerbeschreibung, Reparaturwünsche, fehlende/
defekte Teile werden protokolliert.

**2. Reparaturkostenermittlung, Kostenfreigabe und Kostenvoranschlag** —
Empfehlung: Kostenrahmen freigeben, innerhalb dessen ohne Rücksprache
repariert wird. Bei Überschreitung: Kostenvoranschlag, Freigabe durch Kunde
nötig.

**3. Reparaturablauf** — defekte Teile austauschen, Funktionstest,
anschließend Wartung: Zerlegen/Reinigen/Schmieren der Brühgruppe, Austausch
Dichtungen, Fetten von Lagern/Dichtungen, Entkalkung, Zerlegen/Reinigung/
Justage Mahlwerk, Reinigung Kaffeeauslauf/Restwasserkanal, Justage
Elektronik, Reinigung Innenraum/Abtropfschale/Gehäuse, Test aller
Funktionen.

**4. Abholung** — Benachrichtigung per Telefon/Mail/WhatsApp mit
Abholnummer.

CTA: Auftragsschein-Download.

### 5. Reparaturdauer (/reparaturdauer)
Titel: "REPARATURDAUER"
Text: In der Regel 3–8 Arbeitstage. Bearbeitung in Eingangsreihenfolge. Bei
seltenen Ersatzteilen ggf. längere Lieferzeit. Kleine Probleme (wenige
Minuten, Gerät muss nicht geöffnet werden) werden nach Ermessen sofort
behoben.
CTA: Auftragsschein-Download, "Jetzt anrufen".

### 6. Reparaturkosten (/reparaturkosten)
Titel: "REPARATURKOSTEN" — "Was kostet eine Reparatur?"
Text: Keine Pauschalpreise, individuelle Kalkulation je Modell/Defekt/
Ersatzteile/Zeitaufwand. Kein telefonischer Kostenvoranschlag ohne
Untersuchung. Üblicher Rahmen: ca. 160 € (inkl. Verschleißteile und
Grundwartung), höher bei weiteren Teilen. Nach Kostenvoranschlag
entscheidet der Kunde. Wird die Reparatur nicht ausgeführt: Kostenpauschale
80 € (Kaffeevollautomaten) bzw. 100 € (Siebträgermaschinen) für den
Kostenvoranschlag. Empfehlung: Kostenrahmen vorab freigeben.

### 7. Gewährleistung (/gewaehrleistung)
Titel: "GEWÄHRLEISTUNG"
**Gewährleistung auf Reparaturen**: 12 Monate auf eingebaute Ersatzteile und
korrekten Einbau (privat), 6 Monate bei gewerblichem Gebrauch. Beginn ab
Abholung, gilt nur für die tatsächlich durchgeführte Reparatur/verbaute
Teile. Andere Komponenten/Verschleiß ausgeschlossen.
**Kulanz**: Bei unvollständiger Fehlerbehebung oder Fehlern bitte umgehend
melden — kulante Lösung wird gesucht. Manche Fehler zeigen sich erst nach
mehrtägigem Test.

### 8. Service (/service)
Titel: "IHRE EXPERTEN IN HOFHEIM AM TAUNUS FÜR DIE REPARATUR IHRER
KAFFEEMASCHINE"
Enthält kombiniert: "Ihre Kaffeemaschine ist ein Athlet"-Text (wie
Reparatur-Seite), vollständigen "Wartung von Kaffeevollautomaten"-Abschnitt
(siehe Punkt 9), Kurzfassung "Was kostet eine Reparatur?" (siehe Punkt 6),
sowie einen ausführlichen **Anfahrts-/Standort-Block**:

Adresse: Joachim Blöchle Elektro-Service GmbH, Wallauer Strasse 4, 65719
Hofheim-Langenhain, Tel. 06192 2004363, E-Mail info@kaffeetechniker.de

Parkplatz: Kundenparkplatz direkt am Gebäude nahe Eingang vorhanden; Geräte
werden auf Wunsch vom Auto in die Werkstatt getragen.

Öffnungszeiten: Mo–Do 8:00–16:00 Uhr, Fr 8:00–13:00 Uhr, Sa geschlossen.

Anfahrt: ca. 6 km vom Wiesbadener Kreuz, Ortsteil Langenhain. Aus Wiesbaden/
Mainz: A66 Abfahrt Wallau (IKEA), an IKEA vorbei auf L3017 Richtung
Wiesbaden-Breckenheim, durch Gewerbegebiet Wallau geradeaus über Ampel, am
Ende rechts auf L3368 Richtung Langenhain, in Langenhain geradeaus in die
Wallauer Straße Nr. 4. Aus Frankfurt: A66 Abfahrt Hattersheim Richtung
Eppstein, nach ca. 2 km links Richtung Langenhain, an der abknickenden
Vorfahrt halblinks in die Oranienstraße, nach 200 m links in die Wallauer
Straße.

(Am besten als eigener "Anfahrt/Standort"-Abschnitt mit eingebetteter
Google-Maps-Karte umsetzen.)

### 9. Wartung (/wartung)
Titel: "WARTUNG"
Intro: wie Startseite/Reparatur — kurze Einleitung zur Reparatur/Beratung.

**Ihre Kaffeemaschine ist ein Athlet** (gekürzt) + Hinweis: auch bei
regelmäßiger Nutzerpflege empfiehlt sich professionelle Wartung.

**Wann ist eine Wartung zu empfehlen?**
- Gerät tut sich schwer bei der Kaffeeproduktion
- Kaffee kommt zu langsam
- Crema nicht mehr schön
- Milchschaum nicht mehr gut
- gründliche Innenreinigung gewünscht
- nach mehrjähriger Benutzung

Nutzen: verlängert Lebensdauer, beugt Defekten vor, verbessert
Produktqualität, hygienische Gründe (Kalk-, Fett-, Milch-, Kaffeepulverreste,
Schimmelbildung). Früherkennung von Defekten spart Aufwand.

**Wie oft?** nach 2, spätestens 3 Jahren; nach 3000–5000 Tassen; bei
wiederkehrenden Fehlermeldungen; wenn Kaffeetrester nicht richtig absetzt/
zu nass ist; bei Problemen der Brüheinheit; bei Wunsch nach Innenreinigung;
wenn der Kaffee nicht mehr schmeckt.

**Was wird gemacht?** Überprüfung auf Fehler/Defekte/Undichtigkeiten/
Verschleiß, Austausch fehlerhafter Teile, gründliches Entkalken, Zerlegen/
Reinigen/Justage Mahlwerk, Zerlegen/Reinigen/Fetten Brüheinheit, Schmierung
Getriebe, Reinigung Kaffeeauslauf, Austausch Verschleißteile/Dichtungen,
Einstellungen laut Hersteller, Reinigung Satzbehälter/Abtropfschale/
Gehäuse/Wassertank, Messung/Einstellung Kaffeetemperatur, Test aller
Funktionen.

### 10. Mietgeräte (/leihgeraete)
Titel: "MIETGERÄTE" — "Mietgerät während der Reparatur"
Text: Damit auch während der Reparatur nicht auf Kaffee verzichtet werden
muss, wird auf Wunsch ein passendes Mietgerät zur Verfügung gestellt.
Bereits ab 40,00 € für die Reparaturdauer mietbar. Begrenzte Anzahl
verfügbar — Reservierung vor der Reparatur empfohlen.

---

## Hinweise für die Umsetzung

- Alle Seiten über die REST API (`wp-lib.ps1`, Funktion `wp POST /wp/v2/pages`)
  anlegen, `content` als Gutenberg-Block-Markup (`<!-- wp:group -->` etc.)
  mit den Design-Tokens oben als Inline-Styles.
- Logo/Favicon zuerst per `Invoke-WebRequest` von den Quell-URLs
  herunterladen, dann per `POST /wp/v2/media` in die WordPress-Mediathek
  hochladen (nicht extern verlinken, da die Signatur zeitlich begrenzt ist).
- Navigationsmenü passend zur Original-Reihenfolge anlegen (`/wp/v2/menus`
  bzw. `/wp/v2/menu-items`, falls mit den vorhandenen Rechten zugänglich —
  sonst manuell in Design → Navigation nachbauen).
- Rechtliche Seiten (Impressum, Datenschutz) waren auf der Originalseite
  nicht Teil der Hauptnavigation und wurden hier nicht erfasst — falls
  vorhanden, separat prüfen und übernehmen.
- Alle Texte sind Eigentum von Joachim Blöchle Elektro-Service GmbH /
  Tobias — für die eigene neue Version der eigenen Firmenseite gedacht,
  keine Fremdinhalte.
