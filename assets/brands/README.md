# Hersteller-Logos

Hier die Logo-Dateien der Marken ablegen, die auf der Startseite und der
Marken-Seite als Logo-Raster erscheinen sollen.

## Dateinamen (genau so, klein geschrieben)

| Marke      | Dateiname             |
|------------|-----------------------|
| Jura       | `jura.png`            |
| DeLonghi   | `delonghi.png`        |
| Philips    | `philips.png`         |
| Siemens    | `siemens.png`         |
| AEG        | `aeg.png`             |
| Bosch      | `bosch.png`           |
| Spidem     | `spidem.png`          |
| Gaggia     | `gaggia.png`          |
| Saeco      | `saeco.png`           |
| Nivona     | `nivona.png`          |
| Miele      | `miele.png`           |
| Melitta    | `melitta.png`         |
| ECM        | `ecm.png`             |
| La Pavoni  | `la-pavoni.png`       |

Optional zusätzlich:
- `jura-servicestelle.png` – „Autorisierte JURA Servicestelle"-Siegel

## Format

- **PNG mit transparentem Hintergrund** (oder SVG), Logo in Schwarz/Dunkelgrau
- Breite ca. 400–800 px, Höhe egal (wird auf ~44 px skaliert)
- Werden im Raster einheitlich grau dargestellt, beim Darüberfahren farbig/voll

## Danach

`.\upload-brands.ps1` ausführen – lädt neue Dateien in die WP-Mediathek und
schreibt `brands-media.json`. Dann `.\build-pages.ps1`.

Marken ohne Datei erscheinen weiterhin als sauberer Text-Kachel – es müssen
also nicht alle auf einmal da sein.
