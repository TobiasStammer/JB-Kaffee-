// Test: fuellt rep-auftrag-vorlage (Z:\...\Rep-Auftrag_2026_Online.pdf) mit Beispieldaten. Koordinaten in pt, Ursprung oben links.
const fs = require('fs');
const { PDFDocument, StandardFonts, rgb } = require('./pdf-lib.min.js');

const DATA = JSON.parse(process.argv[3] || '{}');
const D = Object.assign({
  nachname: 'Mustermann-Schmidt', vorname: 'Max', strasse: 'Musterstraße 123 a', plzort: '65719 Hofheim-Langenhain',
  mobil: '0171 1234567', telefon: '06192 2004363', hersteller: 'JURA', typ: 'E8 (EC) Piano White', seriennr: '12345678',
  auftrag: 'Wartung mit Fehler / Gastro', freigabe: '250', filter: 'ja', filter_neu: 'nein', miete: 'nein',
  fehler: 'Gerät zeigt „Brühgruppe fehlt“ an und macht keinen Kaffee mehr. Außerdem tropft es unten aus dem Gerät und der Milchschaum ist sehr dünn geworden.'
}, DATA);

(async () => {
  const doc = await PDFDocument.load(fs.readFileSync(process.argv[2]));
  const page = doc.getPages()[0];
  const H = page.getHeight();
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const black = rgb(0, 0, 0);
  // Text: x links, base = Grundlinie (Abstand von oben), maxX = rechte Grenze (Schrift schrumpft bis 7 pt)
  function T(str, x, base, size, maxX) {
    size = size || 11; const s = String(str || '');
    while (maxX && size > 7 && x + bold.widthOfTextAtSize(s, size) > maxX) size -= 0.5;
    page.drawText(s, { x, y: H - base, size, font: bold, color: black });
  }
  // Kreuz als zwei Striche mittig im Kaestchen (cx, cy = Mitte, von oben; h = halbe Kreuzgroesse)
  function X(cx, cy, h) {
    h = h || 3.0;
    const o = { thickness: 1.3, color: black };
    page.drawLine({ start: { x: cx - h, y: H - (cy - h) }, end: { x: cx + h, y: H - (cy + h) }, ...o });
    page.drawLine({ start: { x: cx - h, y: H - (cy + h) }, end: { x: cx + h, y: H - (cy - h) }, ...o });
  }
  const MAXL = 336; // linke Haelfte endet bei ~340 (rechts: graue JB-Felder)
  T(D.nachname, 112, 133.2, 11, MAXL);
  T(D.vorname, 108, 155.3, 11, MAXL);
  T(D.strasse, 99, 177.4, 11, MAXL);
  T(D.plzort, 104, 199.4, 11, MAXL);
  T(D.mobil, 95, 221.6, 11, MAXL);
  T(D.telefon, 102, 243.7, 11, MAXL);
  T(D.hersteller, 108, 414.2, 11, MAXL);
  T(D.typ, 109, 433.1, 11, MAXL);
  T(D.seriennr, 111, 451.9, 11, MAXL);

  // Auftrag: Zeilenmitte (Kaestchen) und Betragsfeld links davon
  const ROWS = { 'Nur Fehler': 300.25, 'Wartung': 319.0, 'Wartung mit Fehler / Gastro': 337.5, 'Wartung Siebträger': 356.0, 'Eigener Betrag': 374.75 };
  const ry = ROWS[D.auftrag];
  if (ry) {
    X(214.12, ry, 3.2);
    let frg = String(D.freigabe || '').trim();
    if (/^\d+([.,]\d{1,2})?$/.test(frg)) frg += ' \u20AC';
    T(frg, 76, ry + 3.6, 10, 128);
  }
  // Filter / Miete
  if (D.filter === 'ja') X(152.0, 470.25, 2.6); else if (D.filter === 'nein') X(188.75, 470.0, 2.6);
  if (D.filter === 'ja') { if (D.filter_neu === 'ja') X(258.25, 470.0, 2.6); else if (D.filter_neu === 'nein') X(289.75, 470.0, 2.6); }
  if (D.miete === 'ja') X(155.75, 489.25, 2.6); else if (D.miete === 'nein') X(188.75, 488.75, 2.6);

  // Fehlerbeschreibung: 3 Zeilen (Grundlinien), Breite 76..536
  function wrap(text, size, maxW) {
    const out = [];
    String(text || '').split(/\r?\n/).forEach(para => {
      let line = '';
      para.split(/\s+/).forEach(w => {
        const t = line ? line + ' ' + w : w;
        if (bold.widthOfTextAtSize(t, size) > maxW && line) { out.push(line); line = w; } else line = t;
      });
      out.push(line);
    });
    return out;
  }
  const BASES = [531.5, 557.5, 584.0];
  let fs_ = 11, lines;
  for (;;) { lines = wrap(D.fehler, fs_, 458); if (lines.length <= 3 || fs_ <= 7) break; fs_ -= 0.5; }
  lines.slice(0, 3).forEach((ln, i) => T(ln, 76, BASES[i], fs_));
  if (lines.length > 3) console.error('WARNUNG: Fehlerbeschreibung passt nicht komplett (' + lines.length + ' Zeilen)');

  fs.writeFileSync(process.argv[4] || 'ra-test.pdf', await doc.save());
  console.log('ok, Schrift Fehlerbeschreibung', fs_);
})();
