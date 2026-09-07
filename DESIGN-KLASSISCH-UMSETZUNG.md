# Design "Klassisch" → Umsetzung in WordPress (new.kaffeetechniker.de)

Ausgewählte Richtung aus den 3 Design-Vorlagen: **"Klassisch"** (nah am Original
www.kaffeetechniker.de). Diese Datei beschreibt die konkrete visuelle Umsetzung
als Gutenberg-Block-Struktur für die WordPress-Seiten — als Ergänzung zu
SITE-CONTENT-BRIEF.md (dort steht der Text-Inhalt aller 10 Seiten).

## Farben (exakt, überall verwenden) — Update: Anthrazit statt Schwarz, weniger Bänder

> **Update 31.08.2026 – Design-Ausbau** (Referenz: staging.feuerwehr-langenhain.de):
> Akzentfarbe **Espresso `#7a4a2e`** für Eyebrows (kleine Großbuchstaben-Label
> über Überschriften), Links, Primär-Button, Häkchen. Sektionen wechseln
> **weiß `#ffffff` / warmgrau `#f0efec`**. Startseite: Kaffeetassen-Grafik im
> Hero, Stat-Kacheln, Leistungs-Karten, „Besuchen Sie uns"-Block mit Foto +
> Adresse + Öffnungszeiten. Hersteller-Logos farbig, Kachel dunkelt beim
> Überfahren. Nummerierung der Abschnitts-Karten wieder entfernt.

Auf Wunsch des Nutzers wurde Schwarz durch **Anthrazit** ersetzt, und die
Anzahl der abwechselnden hell/dunkel-Streifen wurde reduziert (vorher zu
unruhig: weiß/hellgrau/schwarz/weiß/schwarz/weiß/hellgrau — jetzt nur noch
**3 große Zonen**: dunkel oben (Kopfbereich), hell in der Mitte (durchgehend,
ohne Farbwechsel), dunkel unten (Abschluss/Footer).

- Seitenhintergrund (durchgehend von Hero bis Vorteile, keine Zwischenbänder mehr): `#f5f5f5` (aufgehellt, vorher `#eeeeee`)
- Fließtext: `#000000`
- Überschriften: `#333333`
- **Grau/Anthrazit** dunkle Zonen: Kopf (Top-Leiste + Marke + Navigation) = `#333333` (Ton wie www.kaffeetechniker.de), Dropdown-Panel `#2b2b2b`; CTA-Band + Footer = `#2b2b2b`. Text darauf `#ffffff` bzw. `#cccccc` für sekundären Text
- Buttons (primär): Hintergrund `#919191`, Text `#463939`
- Buttons (outline/sekundär): transparent, Rahmen `#333333`, Text `#333333`
- Subheading ("Ihr Partner für...") ist jetzt **kein eigenes farbiges Band mehr**, sondern Teil des Hero-Bereichs (dünne Trennlinie `#d8d8d8` statt Hintergrundwechsel)
- Brands-Sektion: **kein eigener grauer Hintergrund mehr** — bleibt beim Seitenhintergrund `#eeeeee`, nur oben/unten eine dünne Linie `#d8d8d8` zur Abgrenzung; Marken-Kacheln weiß mit grauem Rahmen `#bbbbbb`
- CTA-Band + Footer: **zu einem durchgehenden Anthrazit-Block verschmolzen** (kein Farbsprung/keine Naht mehr dazwischen) — Hintergrund `#2b2b2b`, Text `#cccccc`, Überschriften weiß

## Schriften

- Überschriften/Navigation: Tahoma (Systemschrift, Fallback: Arial, sans-serif)
- Fließtext: "Source Sans Pro" (Google Font) bzw. "Source Sans 3" als moderner Ersatz

## Seitenaufbau (Reihenfolge, für "Start" und sinngemäß für die Unterseiten)

**Nur noch 3 große Farbzonen von oben nach unten: Anthrazit → Hell (durchgehend) → Anthrazit.**

1. **Weißer Logo-Balken** `#ffffff` (wie www.kaffeetechniker.de): links Telefonnummer, **mittig das Logo** (WP-Medien-ID 149, `Logo mit text.png` – JB + „Kaffeemaschinen Service & Verkauf", schwarz), rechts Warenkorb- und Konto-Icon (Inline-SVG, dunkel). E-Mail/Öffnungszeiten hier nicht – stehen im Footer. Unter 720px: Logo zuerst/mittig, Telefon + Icons darunter.
2. **Navigation**: direkt darunter, grau `#333333`, **mittig zentriertes, aufklappbares Menüband wie auf www.kaffeetechniker.de**:
   - **Start** → `/start/`
   - **Reparatur** → `/reparatur/` mit Untermenü: Marken, Reparaturablauf, Reparaturdauer, Reparaturkosten, Gewährleistung
   - **Service** → `/service/` mit Untermenü: Wartung, Mietgeräte
   - **Shop** → `/shop/` mit Untermenü: Shop, Warenkorb (`/cart/`), Mein Konto (`/my-account/`)
   Umsetzung CSS-only (`<style>`-Block in der Header-Zone): Dropdown-Panel `#2b2b2b`, öffnet bei
   `:hover` / `:focus-within`; unter 860px Breite klappen die Untermenüs dauerhaft (zentriert) auf.
   Menü-Baum = `$NAVTREE` in `build-pages.ps1` (Knoten `{slug=}` oder `{label=;url=}`).
   Aktiver Ast: `.is-active` auf Top-Punkt und aktivem Unterpunkt (weiß/fett).
3. **Hero**: zentriert, große Überschrift (Klasse "Überschrift", `#333333`), Fließtext darunter, zwei Buttons nebeneinander ("Kontaktieren Sie uns" primär, "Auftragsschein Download" outline), darunter der Satz "Ihr Partner für Reparatur und Wartung..." mit dünner Trennlinie statt eigenem Farbband — **ab hier bis Punkt 7 durchgehend derselbe helle Hintergrund `#eeeeee`, keine weiteren Farbwechsel**
4. **Intro zweispaltig**: links Fließtext (Marken/Service-Beschreibung), rechts graue Box mit "30 Jahre Erfahrung seit 1961"
5. **Marken-Sektion**: kein eigener Hintergrund mehr, nur dünne Trennlinien oben/unten; weiße Kacheln/Pills mit den Markennamen
6. **Vorteile**: zweispaltige Liste mit Häkchen-Icons (7 Punkte aus SITE-CONTENT-BRIEF.md)
7. **CTA + Footer**: **ein durchgehender Anthrazit-Block `#2b2b2b`**, oben zentrierter Aufruf + Button, direkt darunter (ohne Farbwechsel) der dreispaltige Footer (Firma/Adresse, Öffnungszeiten, Navigation-Kurzlinks), ganz unten schmale Zeile mit Lagehinweis

## Buttons (Stil)

- Primär: Hintergrund `#919191`, Text `#463939`, fett, kein Rundung (eckig oder max. 2px), Padding ca. 14px/28px
- Outline: transparent, 1px Rahmen `#333333`, Text `#333333`

## Hinweise

- Auf den Unterseiten (Reparatur, Marken, …) dieselbe Kopfzeile (Top-Leiste +
  Navigation) und denselben Footer verwenden — das ist der wiederkehrende
  Rahmen. Der mittlere Inhalt kommt aus SITE-CONTENT-BRIEF.md.
- **Unterseiten-Typografie (Update 31.08.):** kompakt und linksbündig. H1 22 px,
  H3 11,5 px Versalien-Label, Fließtext 15,5 px, Spalte max. 680 px. Seiten mit
  mehreren Abschnitten bekommen links eine schmale Spalte mit Sprungmarken
  (Auto-TOC aus den H2) und optional eine „Auf einen Blick"-Fakten-Box
  (`facts` in `pages-content.json`).
- **Abschnitte als Karten (Update 31.08.):** jede H2 startet eine weiße Karte
  (`.kt-sec`, 1 px Rahmen `#e6e6e6`, Nummern-Kreis). Intro-Absatz / Bild /
  Marken-Raster vor der ersten H2 stehen lose darüber. Seiten ohne H2
  (Reparaturablauf) behalten ihre Schritt-Karten. Ohne Sprungmarken-Spalte
  wird die Textspalte mittig gesetzt.
- Alles über Block-Styles (Inline-Farben auf Gruppen/Buttons/Spalten) im
  Seiteninhalt setzen, da kein Zugriff auf globale Theme-Einstellungen besteht
  (siehe CLAUDE.md).
- Die vollständige Referenz-Vorlage (interaktiv, alle 3 Varianten) liegt hier:
  https://claude.ai/code/artifact/886dd7e0-08b8-40f7-908f-78b164d1a3fb —
  Variante "Klassisch" ist die maßgebliche Vorlage für Layout/Abstände/Look,
  falls Details in diesem Dokument nicht ausreichen.
