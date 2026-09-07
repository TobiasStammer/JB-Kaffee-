# Seitenstruktur neu geordnet – kaffeetechniker.de

Stand: 2026-08-28, **umgesetzt am 2026-08-31**. Auswertung der **kompletten**
Original-Struktur von www.kaffeetechniker.de (aus `sitemap.xml`) und Neuordnung
in Hauptkategorien.

- Begründung/Auswertung: Artefakt „Navigation neu geordnet“
  <https://claude.ai/code/artifact/18c3b9a5-59df-414b-801c-82be3d60afe4>
- Durchklickbare Vorschau aller Entwurfsseiten:
  <https://claude.ai/code/artifact/2d22dd34-b396-49e2-bd9f-f28219e48c1f>

Ersetzt die 1:1-Übernahme aus `SITE-CONTENT-BRIEF.md` (Abschnitt „Seitenstruktur“).

## Umsetzungsstand (2026-08-31)

- `$NAVTREE` in `build-pages.ps1` auf **Start + 6 Hauptkategorien** umgestellt
  (Top-Label der 3. Kategorie ist **„Kaufen“**, nicht „Kaufen & Shop“).
- **24 Seiten** als Entwurf gebaut (`build-pages.ps1` + `pages-content.json`),
  IDs: start 19, reparatur 20, marken 21, reparaturablauf 22, reparaturdauer 23,
  reparaturkosten 24, gewaehrleistung 25, wartung 27, leihgeraete 28,
  wertgarantie 110, kaffeemaschinen-kaufen 111, kaffeemaschine-mieten 112,
  kaffeemaschine-leasen 113, pflegemittel 114, unser-kaffee 115, hilfethemen 116,
  ueber-uns 117, anfahrt 118, jobs 119, kontakt 120, impressum 121,
  datenschutz 122, agb 123, widerruf 124.
- Alte `service`-Seite (ID 26) → **Papierkorb** (Anfahrt herausgelöst nach /anfahrt/).
- `leihgeraete`: Menü/Titel „Mietgeräte“ → **„Ersatzgerät für die Reparaturzeit“**
  (Slug bleibt `leihgeraete`).
- Hilfethemen: 1 Seite mit 9 Anker-IDs (`erste-hilfe`, `reparieren-lohnt-sich`,
  `entkalken`, `wasserfilter`, `milchschaum`, `systeme-vergleich`, `kaufberatung`,
  `siebtraeger`, `design-funktion`); Untermenü verlinkt darauf. Inhalt = kompakte
  Zusammenfassungen, der ausführliche Originaltext ist noch zu migrieren.
- Footer: Impressum · Datenschutz · AGB · Widerruf als eigene Zeile.
- **Rechtstexte** (impressum unvollständig, datenschutz/agb/widerruf nur `[TODO]`)
  müssen von Tobias / einem Anwalt eingesetzt werden, bevor veröffentlicht wird.
- Helfer `_make-preview.ps1` erzeugt die Vorschau-HTML aus allen Entwürfen.
- **Kopf umgebaut (31.08.):** weißer Logo-Balken (Logo = `Logo mit text.png`,
  WP-Medien-ID 149, `chrome.brand.logoUrl` in `pages-content.json`) + darunter das
  dunkle Menüband. Seitenhintergrund aufgehellt `#eeeeee` → `#f5f5f5`.

- **Theme-Chrome entfernt (31.08.):** alle Seiten laufen jetzt mit
  `template = 'blank'` (Extendable – ohne Theme-Header, -Footer, -Seitentitel),
  gesetzt per REST im Build. `Wrap-Page()` fasst die Farbzonen in eine
  `alignfull`-Gruppe mit `blockGap:0` – sonst 32px weiße Streifen dazwischen.
  An `/wartung/` verifiziert.

Noch offen: Seiten inhaltlich prüfen + veröffentlichen; „Start“ als statische
Startseite (Admin/`/wp/v2/settings` 403); ausführliche Hilfethemen-Texte;
echte Rechtstexte.

## Was an der alten Gliederung hakt

- **Produkte ↔ Shop doppeln sich** – „Unser Kaffee“ und „Pflegemittel“ je zweimal.
- **„Mietgeräte“ ≠ „Kaffeemaschinen mieten“** – Leihgerät für die Reparaturzeit
  (ab 40 €) vs. Langzeit-Miete ab 12 Monaten. Gleicher Name, anderes Angebot.
- **„Service“** ist keine eigene Seite, sondern wiederholt Reparatur + Wartung +
  Kosten und hängt die Anfahrt an.
- **Leihgerät** steht unter „Service“ statt bei der **Reparatur**, wo es hingehört.
- **Impressum/Datenschutz** im Hauptmenü statt im Footer.
- **Hilfethemen** = 9 gute Themen auf einer langen Seite, nur Ankerlinks.
- **„Über uns“** existiert (`/über-uns`), ist aber leer und unverlinkt.

## Neue Gliederung (6 Hauptkategorien)

| # | Hauptpunkt | URL | Untermenü |
|---|---|---|---|
| 1 | **Reparatur** | `/reparatur/` | Marken & Modelle `/marken/` · Reparaturablauf `/reparaturablauf/` · Reparaturdauer `/reparaturdauer/` · Reparaturkosten `/reparaturkosten/` · Gewährleistung `/gewaehrleistung/` · **Ersatzgerät für die Reparaturzeit** `/leihgeraete/` (umbenennen, war „Mietgeräte“) · **WERTGARANTIE – Reparaturschutz** `/wertgarantie/` (neu) |
| 2 | **Wartung** | `/wartung/` | – (Einzelseite) |
| 3 | **Kaufen & Shop** | `/shop/` | Neue Kaffeemaschinen `/kaffeemaschinen-kaufen/` (neu, war `/neugeraete`) · Kaffeemaschine mieten `/kaffeemaschine-mieten/` (neu) · Kaffeemaschine leasen `/kaffeemaschine-leasen/` (neu) · Pflegemittel & Zubehör `/pflegemittel/` (neu) · Unser Kaffee `/unser-kaffee/` (neu) · **Zum Online-Shop →** `/shop/` (WooCommerce) |
| 4 | **Hilfe & Wissen** | `/hilfethemen/` | Erste Hilfe bei Störungen · Reparieren lohnt sich · Richtig entkalken · Wasserfilter verwenden · Perfekter Milchschaum · Kaffeemaschinen-Systeme im Vergleich · Kaufberatung Kaffeevollautomat · Siebträger & Espresso · Design & Funktion — zunächst Anker auf `/hilfethemen/`, später Einzelartikel |
| 5 | **Über uns** | `/ueber-uns/` | Das Unternehmen (seit 1961) `/ueber-uns/` (neu, Text vom Start-Absatz) · Anfahrt & Standort `/anfahrt/` (aus alter `/service`-Seite herauslösen) · Jobs & Karriere `/jobs/` (neu) |
| 6 | **Kontakt** | `/kontakt/` | – (Einzelseite, neu; heute nur Formular auf Start) |

**Obere Leiste** unverändert: Telefon links, Warenkorb- + Konto-Icon rechts.
**Footer** (nicht Hauptnavi): Kontakt · Impressum · Datenschutz · **AGB** · **Widerrufsbelehrung**
(AGB/Widerruf für den WooCommerce-Shop neu – echter Rechtstext nötig).

## Vorher → Nachher (Kurzform)

- Service › Mietgeräte → **Reparatur › Ersatzgerät für die Reparaturzeit**
- Service › Versicherung → **Reparatur › WERTGARANTIE**
- Service › Wartung → **Wartung** (eigener Hauptpunkt)
- Service (Landingpage) → aufgelöst: Anfahrt → „Über uns“, Rest war doppelt
- Produkte › (alle 5) → **Kaufen & Shop** (Kaffee/Pflege nur noch einmal)
- Produkte (Verteilerseite) → entfällt
- Shop (JURA-Fremdsystem) → **Kaufen & Shop › Zum Online-Shop** (WooCommerce)
- Hilfethemen (1 Seite) → **Hilfe & Wissen** (9 Menüpunkte)
- Kontakt › Jobs → **Über uns › Jobs**
- Kontakt › Impressum/Datenschutz → **Footer**
- Über uns (leer) → **Über uns › Das Unternehmen** (neu mit Inhalt)

## Umsetzungsschritte

1. `$NAVTREE` in `build-pages.ps1` auf die 6 Kategorien umstellen (Reparatur +
   Wartung sofort möglich; Knoten können Slug oder `{label;url}` sein).
2. 7 Inhaltsseiten neu als Entwurf: WERTGARANTIE, Neue Kaffeemaschinen,
   Kaffeemaschine mieten, Kaffeemaschine leasen, Pflegemittel & Zubehör,
   Unser Kaffee, Das Unternehmen. Texte 1:1 von der Live-Seite → `pages-content.json`.
3. 2 Seiten umbauen: „Mietgeräte“ → „Ersatzgerät für die Reparaturzeit“ (Slug
   bleibt `leihgeraete`); Anfahrtsblock aus alter `/service`-Seite → neue
   `/anfahrt/`, Rest von `/service` stilllegen.
4. `/hilfethemen/` mit 9 sauberen Anker-IDs, Untermenü darauf verlinken.
5. Kontakt- und Jobs-Seite anlegen.
6. Footer um Impressum/Datenschutz/AGB/Widerruf ergänzen (AGB/Widerruf: Rechtstext
   von Tobias/Anwalt).
7. Alles prüfen + veröffentlichen, „Start“ als statische Startseite, Theme-Nav aus.
