# Livetag: Umzug auf www.kaffeetechniker.de (geplant Di 2026-09-29, ab ca. 9:00)

Aufgabenteilung: **[DU]** = im IONOS-Konto / Zahlungsanbieter-Konten, **[CLAUDE]** = per Schnittstelle. Dauer gesamt ca. 1-2 Stunden.

## 0. Vorher (schon erledigt)
- Probelauf des Datenbank-Umzugs: 186 Zeilen / 3.886 Vorkommen (Revisionen ausgelassen). Umzugswerkzeug (Snippet 25) und Host-Umleitung (Snippet 26) liegen **inaktiv** bereit.
- 81 Weiterleitungen von alten Adressen (Liste: `Weiterleitungen-alte-Seite.csv`) sind schon aktiv (greifen nur bei 404).
- Vorkasse-Bankverbindung, Lieferzeiten, Rechtstexte, Preisangaben, Sitemap, Favicon usw. sind fertig.

## 1. Backup [DU] ~9:00
- IONOS: Vollbackup von **Webspace und Datenbank** anlegen (Sicherung/Snapshot im Kundenkonto). Erst danach weitermachen.
- Kurz melden: "Backup fertig".

## 2. Letzter Schnellcheck [CLAUDE] ~9:10
- Seite erreichbar, Kasse/Zahlarten, Formulare, Mails, Crawl (alle Seiten 200).

## 3. Domain zuweisen [DU] ~9:15
- IONOS: `www.kaffeetechniker.de` demselben Webspace/Zielordner zuweisen wie `new.kaffeetechniker.de` (die alte Seite wird dadurch ersetzt).
- SSL-Zertifikat fuer `www` aktivieren. **MX/SPF/DKIM (E-Mail-DNS) NICHT anfassen.**
- Warten, bis `https://www.kaffeetechniker.de` erreichbar ist (WordPress leitet zunaechst evtl. auf `new.` um - das ist normal). Melden: "www zeigt auf den Webspace".

## 4. Umzug ausfuehren [CLAUDE] ~9:30-9:45
1. Probelauf wiederholen (aktuelle Zahlen).
2. Umzug: `new.kaffeetechniker.de` -> `www.kaffeetechniker.de` (Datenbank-Ersetzung), `siteurl`/`home` auf www, `blog_public = 1`, Caches leeren.
3. Host-Umleitung `new.` -> `www.` (Snippet 26) aktivieren.
4. Umzugswerkzeug (Snippet 25) wieder abschalten/loeschen.
5. Meine Zugangsdatei auf www umstellen (WP_URL).
- **Danach [DU]:** im Browser neu bei WordPress anmelden (unter www).

## 5. Zahlungen neu verbinden [DU, ich begleite] ~9:45-10:15
- **PayPal:** WooCommerce -> Einstellungen -> Zahlungen -> PayPal -> Webhooks/Verbindung erneuern (Status pruefen).
- **WooPayments:** WooCommerce -> Zahlungen -> Status kontrollieren; falls "Verbindung wiederherstellen"/Jetpack-Hinweis: bestaetigen. Apple Pay/Google Pay: Domain-Pruefung.
- **Amazon Pay:** Status pruefen.
- Ich lese danach die Einstellungen aus und pruefe Livemodus.

## 6. Testkaeufe [DU] ~10:15-10:45
- Karte (kleiner Artikel, z. B. Pflegeprodukt), **Vorkasse** (danach Bestellung stornieren), optional PayPal.
- Ich pruefe: Bestellmail an Kunde (Bankdaten bei Vorkasse), Mail an `shop@`, Bestellung im Admin, Zahlungseingang.

## 7. Pruefung nach dem Umzug [CLAUDE] ~10:45
- Crawl (alle Seiten 200, keine alten `new.`-Adressen), Weiterleitungen alte Adressen, Sitemap/robots, mobil, Formulare, Kurzlink `vqr.vc/gw2FD9Pft` -> Wertgarantie.

## 8. Nacharbeit (am selben Tag)
- [DU] Google Search Console: Property `https://www.kaffeetechniker.de` anlegen, Sitemap `https://www.kaffeetechniker.de/wp-sitemap.xml` einreichen.
- [DU] Google-Unternehmensprofil, Social-Links, Flyer/QR-Codes auf `www` pruefen.
- [DU] SSH-Zugang bei IONOS von Passwort auf Schluessel umstellen und Passwoerter erneuern.
- [CLAUDE] Notizen/Repo aktualisieren.

## Zurueck (falls noetig)
- Umzug erneut mit vertauschtem `from`/`to` ausfuehren, DNS-Zuweisung zuruecknehmen, im Notfall Backup einspielen.
- Der IONOS-Zwischenspeicher haelt Weiterleitungen bis zu 1 Stunde, kurzzeitig alte Antworten sind normal.
