# Setup-Notizen – kaffeetechniker.de Integration

Stand: 2026-08-28

## 1. WordPress REST API – funktioniert ✅

- Verbindung getestet gegen `https://new.kaffeetechniker.de/wp-json/wp/v2/users/me`
- Authentifiziert als **Claude** (`claude-integration`, User-ID 3) über Application Password
- Schreibtest bestanden: Entwurf angelegt (`POST /wp/v2/posts`) und wieder gelöscht
  (`DELETE ...?force=true`), Gegenprüfung 404 → sauber entfernt.

### Rechte des `claude-integration`-Users
| Bereich | Lesen | Schreiben |
|---|---|---|
| `/wp/v2/posts` | ✅ | ✅ |
| `/wp/v2/pages` | ✅ | ✅ (vermutlich, wie posts) |
| `/wp/v2/media` | ✅ | noch nicht getestet |
| `/wp/v2/users` | ✅ | – |
| `/wp/v2/settings` | ❌ 403 | ❌ |
| `/wp/v2/plugins` | ❌ 403 | ❌ |
| `/wp/v2/themes` | ❌ 403 | ❌ |
| `/wc/v3/*` (WooCommerce) | ❌ 403 | ❌ |

→ Der User hat **Editor-ähnliche Rechte** (Inhalte), aber **keine Admin-Rechte**
(keine Einstellungen, Plugins, Themes, WooCommerce-Daten). Für Shop-/Plugin-/
Theme-Einstellungen bräuchte es entweder erweiterte Rechte für diesen User oder
einen WooCommerce-API-Key.

### Bestandsaufnahme der Site
- Site-Name: „Neue Seite 2026“, WordPress mit **WooCommerce** + **Jetpack** +
  IONOS-Essentials + rankingcoach
- Seiten: Sample Page (2), Shop (6), Cart (7), Checkout (8), My account (9)
- Beiträge: „Hello world!“ (1)
- Also faktisch eine frische WooCommerce-Installation.

### Arbeiten mit der REST API
`wp-lib.ps1` dot-sourcen:
```powershell
. .\wp-lib.ps1
Test-KtWpConnection
wp GET  /wp/v2/posts?per_page=5
wp POST /wp/v2/pages @{ title='Neue Seite'; status='draft'; content='<p>…</p>' }
wp DELETE /wp/v2/posts/123?force=true
```

## 2. Theme-/Plugin-Dateien via SFTP/SSH – eingeschränkt ⚠️

- SSH-Login gegen `home16460309.1and1-data.host:22` als `p6659061` **funktioniert**.
- Passwort-Auth läuft ohne Terminal-Prompt über `SSH_ASKPASS` (siehe `ssh-lib.ps1`).
- **ABER:** Dieser Webspace ist praktisch leer. `~/htdocs` enthält nur leere Ordner
  (`wordpress/`, `Test/`, `clickandbuilds/`) plus `logs/`. Es gibt **keine
  `wp-config.php`, kein `wp-content`, keine Theme-/Plugin-Dateien** irgendwo im
  erreichbaren Verzeichnisbaum (`/kunden/homepages/16/d16460309`).
- Die eigentliche WordPress-Installation von `new.kaffeetechniker.de` liegt
  offenbar in einem **separaten IONOS-ClickAndBuilds-Paket mit eigenen
  SSH-Zugangsdaten**, die (noch) nicht in der `.env` stehen.

### Was fehlt für Theme-/Plugin-Dateiänderungen
Eines davon besorgen:
1. Die **SSH/SFTP-Zugangsdaten des ClickAndBuilds-Pakets**, in dem WordPress
   installiert ist (IONOS-Kundenkonto → Hosting → das betreffende Paket →
   SFTP-Zugang). Dann `.env` um einen zweiten Host ergänzen.
2. Alternativ Datei-Edits über ein Plugin (z. B. „Code Editor“) bzw. den
   Theme-/Plugin-Editor in wp-admin – setzt aber Admin-Rechte voraus.

### Arbeiten per SSH (sobald der richtige Host vorliegt)
`ssh-lib.ps1` dot-sourcen:
```powershell
. .\ssh-lib.ps1
kt-ssh "ls -la ~/htdocs"
kt-sftp-get "wp-content/themes/<theme>/functions.php" ".\functions.php"
kt-sftp-put ".\functions.php" "wp-content/themes/<theme>/functions.php"
```

## 2a. IONOS-MCP-Endpunkt / wp-abilities – vorhanden, aber gesperrt

Namespace `ionos/essentials/mcp` (aus `GET /wp-json`):

| Pfad | Methoden | Zweck | mit App-Passwort |
|---|---|---|---|
| `/ionos/essentials/mcp` | GET | nur Namespace-Index (Selbstbeschreibung) | 200 ✅ |
| `/ionos/essentials/mcp/action` | POST | eigentlicher MCP-Endpunkt (JSON-RPC) | **403 „Invalid nonce"** |

`/action` verlangt eine eingeloggte WP-Session + `X-WP-Nonce` (wp-admin-Kontext).
Application Password / Basic Auth wird **nicht** akzeptiert (ohne Auth: 401).
→ Der IONOS-MCP-Server ist mit den vorhandenen Zugangsdaten nicht nutzbar; er
ist für die Nutzung aus dem eingeloggten IONOS-/wp-admin-Backend gedacht
(bzw. per OAuth-MCP-Client, nicht per API-Token).

Verwandt: Namespace `wp-abilities/v1` (die „Abilities", die der MCP-Server als
Tools kapselt). Liste ist mit App-Passwort **lesbar**
(`GET /wp-json/wp-abilities/v1/abilities`):
`core/get-site-info`, `core/get-user-info`, `core/get-environment-info`,
`woocommerce/orders-query`, `woocommerce/order-add-note`,
`woocommerce/order-update-status`, `woocommerce/products-query`,
`woocommerce/product-create`, `woocommerce/product-delete`,
`woocommerce/product-update`.
Ausführen (`.../abilities/<name>/run`, POST) scheitert hier mit **405**, weil die
Ability-Namen einen `/` enthalten und der Server kodierte Slashes ablehnt
(`%2F` → 400 „Malformed URI"). Also auch dieser Weg zu den WooCommerce-Daten
ist mit den aktuellen Credentials zu.

## 2b. Seiten-Aufbau – Design „Klassisch" (Stand 2026-08-28, Fassung 2: Anthrazit / 3 Zonen)

Skripte: `build-pages.ps1` (Logik, ASCII) + `pages-content.json` (Inhalte + Chrome-Texte, UTF-8).
Referenz: `DESIGN-KLASSISCH-UMSETZUNG.md` (aktualisiert) + Artboard „Klassisch".
Idempotent (per Slug), **alle 10 Seiten Status = `draft`**.

- **Medien:** Logo (ID 16) und Logo grau / „Favicon" (ID 17) in der Mediathek.
- **10 Seiten (IDs 19–28)** – nur noch **3 Farbzonen** (`wp:group {"align":"full"}`):
  1. **Anthrazit-Kopf `#2e2e2e`** – eine Gruppe, nahtlos: Top-Leiste
     (E-Mail/Öffnungszeiten links, Telefon rechts) + Navigation (JB-Badge +
     Firmenname, 10 Menüpunkte in Reihenfolge, aktiver Link `#ffffff`/fett,
     inaktive `#cccccc`), Trennung nur per `#444`-Haarlinie.
  2. **Heller Bereich `#eeeeee`, durchgehend** – keine Zwischenbänder mehr:
     Hero (H1 Tahoma `#333`, 2 Buttons solid/outline, darunter Subheading „Ihr
     Partner …" mit `#d8d8d8`-Haarlinie statt Farbband), zweispaltiges Intro +
     graue „30 Jahre"-Box, „Über uns", Marken-Pills (weiß/`#bbbbbb`, nur
     `#d8d8d8`-Linien oben/unten, kein grauer Hintergrund), Vorteile-Raster mit
     Häkchen, Kontaktformular (mailto-Fallback).
  3. **Anthrazit-Abschluss `#2b2b2b`** – eine Gruppe: CTA (zentriert + Button)
     direkt gefolgt vom dreispaltigen Footer + Lagehinweis, ohne Farbsprung.
  - Unterseiten: gleicher Kopf/Abschluss; Hero-lite (H1 + Intro-Absatz +
    Excerpt-Subheading mit Haarlinie), Fließtext aus `pages-content.json`
    (Überschriften `#333`/Tahoma, Buttons `#919191`/`#463939`, eckig 2px).
  - Farben exakt inline. Nav-/Footer-Links als feste `/slug/`-Permalinks.
  - Übersicht in `_page-results.json`.
- PS-Falle im Skript: `$c` kollidiert mit `$C` (Variablennamen case-insensitiv) – behoben.
- Frühere Vorlage „Hauptnavigation" (`wp_block` ID 29) bleibt bestehen, wird für
  dieses Design nicht mehr gebraucht (Nav steckt in jeder Seite).
- **Menüband (Update 2026-08-28):** aufklappbar + **mittig zentriert**, Grauton
  `#333333` wie www.kaffeetechniker.de. Top-Punkte + Dropdowns: Start /
  Reparatur → (Marken, Reparaturablauf, Reparaturdauer, Reparaturkosten,
  Gewährleistung) / Service → (Wartung, Mietgeräte) / Shop → (Shop, Warenkorb
  `/cart/`, Mein Konto `/my-account/`). Obere Leiste: nur noch Telefon (links) +
  Warenkorb-/Konto-Icon (rechts, Inline-SVG) – E-Mail/Öffnungszeiten dort raus.
  Darunter mittig die Marke, darunter mittig das Menü. CSS-only
  `:hover`/`:focus-within` (`<style>`-Block in Header-Zone), Dropdown-Panel `#2b2b2b`,
  unter 860px klappen die Untermenüs dauerhaft auf. Baum = `$NAVTREE` in
  `build-pages.ps1` (Knoten `{slug=}` oder `{label=;url=}`, Helper `Nav-Node`).
  Getestet: `<style>` (mit `:hover`/`@media`) übersteht die REST-Speicherung, der
  `claude-integration`-User hat also `unfiltered_html`.

### Noch offen / manuell
1. **Prüfen & veröffentlichen:** je Seite in wp-admin → Seiten → Vorschau ansehen,
   dann veröffentlichen. `align:full` bricht nur voll aus, wenn das Extendable-
   Seitentemplate das zulässt – sonst wird der Rahmen mittig statt randlos
   dargestellt (Farben/Struktur bleiben korrekt).
2. **Startseite:** Einstellungen → Lesen → statische Seite = „Wartung von
   Kaffeevollautomaten …" (start, ID 19). *(Admin nötig – 403 für claude-integration.)*
3. **Theme-Header/Footer:** da jede Seite den Rahmen selbst mitbringt, ggf. den
   Theme-eigenen Header/Footer (Extendable) leeren/ausblenden, damit es keine
   doppelte Navigation gibt – oder stattdessen ein echtes Menü + Template-Part
   bauen und den Inline-Rahmen aus den Seiten entfernen.
4. **Logo/Site-Icon:** Editor → Stile: Logo = Medien-ID 16, Site-Icon = ID 17.
5. **Kontaktformular** auf `start` ist mailto-Fallback – für echten Versand ein
   Formular-Plugin (Contact Form 7 o. ä.) einrichten.

## 3. Sicherheit / To-do
- `.gitignore` angelegt (schließt `.env` aus), falls der Ordner je unter Git kommt.
- Empfehlung aus CLAUDE.md bleibt: IONOS-SSH von Passwort auf Key-Pair umstellen.
- Application Password ist auf `claude-integration` beschränkt und in
  wp-admin → Benutzer → claude-integration → Anwendungspasswörter einzeln widerrufbar.
- Der Askpass-Helfer wird nach `%TEMP%\kt-askpass.cmd` geschrieben und enthält nur
  einen Verweis auf die Umgebungsvariable `KT_SSH_PW` (kein Klartext-Passwort in der Datei).
