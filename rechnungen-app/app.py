"""Rechnungsverwaltung mit DATEV-Export (lokal, SQLite).

Start:  py app.py   ->  http://127.0.0.1:5055
Daten:  data/rechnungen.db und data/belege/  (nicht in Git)
"""
import csv
import io
import os
import re
import hashlib
import shutil
import smtplib
import sqlite3
import threading
import time
import uuid
import zipfile
from datetime import date, datetime
from email.message import EmailMessage
from pathlib import Path

from pypdf import PdfReader, PdfWriter
from PIL import Image
from flask import (Flask, abort, flash, g, redirect, render_template_string,
                   request, send_file, url_for)
from werkzeug.utils import secure_filename

BASE = Path(__file__).resolve().parent
DATA = BASE / "data"
BELEGE = DATA / "belege"
DB = DATA / "rechnungen.db"
BELEGE.mkdir(parents=True, exist_ok=True)
PAKETE = DATA / "monatspakete"

app = Flask(__name__)
app.secret_key = "lokal-nur-auf-127.0.0.1"
app.config["MAX_CONTENT_LENGTH"] = 40 * 1024 * 1024
ERLAUBT = {".pdf", ".jpg", ".jpeg", ".png", ".tif", ".tiff"}

# Kategorie -> Standard-Aufwandskonto (SKR03). Bei SKR04 in den Einstellungen anpassen.
KATEGORIEN = {
    "Wareneinkauf": "3400",
    "Fremdleistungen": "3100",
    "Bürobedarf": "4930",
    "Porto/Telefon/Internet": "4910",
    "Software/Hosting": "4964",
    "Reparatur/Instandhaltung": "4805",
    "Kfz-Kosten": "4530",
    "Miete/Nebenkosten": "4210",
    "Werbung": "4610",
    "Sonstiges": "4980",
}
BELEGARTEN = ["Rechnungsausgang Service", "Rechnungsausgang Verkauf", "Rechnungsausgang eBay",
              "Rechnungseingang Lieferanten", "Kassenbuch", "Monatsjournal Kasse",
              "Rechnungsausgangliste"]
EINGANG = "Rechnungseingang Lieferanten"
UNKLAR = "Nicht zugeordnet"
BELEGARTEN_ALLE = BELEGARTEN + [UNKLAR]
STANDARD_ORDNER = r"Z:\Buchhaltung\Eingang"
# Zuordnungsregeln: "Belegart = stichwort, stichwort" - erste passende Zeile gewinnt.
# Gesucht wird im PDF-Text und im Dateinamen (Gross/Klein egal).
# "nr:261" = Rechnungsnummer beginnt mit 261.
STANDARD_LIEFERANTEN = """Jura Gastro
Jura
Amazon
BND
VW Leasing
Axa
Baloise
Böttcher
Deutsche Glasfaser
Gross
Ebay
Grover
GLS
Wentronic
Wertgarantie"""
STANDARD_REGELN = """Rechnungsausgangliste = rechnungsausgangsliste, rechnungsausgangliste, ausgangsliste
Monatsjournal Kasse = monatsjournal
Kassenbuch = kassenbuch
Rechnungsausgang eBay = ebay
Rechnungsausgang Service = nr:263
Rechnungsausgang Verkauf = nr:261
Rechnungseingang Lieferanten = eingangsrechnung, lieferant"""
STATUS = ["offen", "bezahlt", "an DATEV gesendet"]

SETTINGS_DEFAULT = {
    "beraternr": "", "mandantennr": "", "wj_beginn": f"{date.today().year}-01-01",
    "sachkontenlaenge": "4", "gegenkonto": "1600", "diktatkuerzel": "",
    "datev_mail": "", "smtp_host": "", "smtp_port": "587", "smtp_user": "",
    "smtp_pass": "", "absender": "",
    "eingang_ordner": STANDARD_ORDNER, "lieferanten": STANDARD_LIEFERANTEN, "regeln": STANDARD_REGELN,
}


# ---------------------------------------------------------------- Datenbank
def db():
    if "db" not in g:
        g.db = sqlite3.connect(DB)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def _close(_):
    d = g.pop("db", None)
    if d:
        d.close()


def init_db():
    c = sqlite3.connect(DB)
    c.executescript("""
    CREATE TABLE IF NOT EXISTS settings(k TEXT PRIMARY KEY, v TEXT);
    CREATE TABLE IF NOT EXISTS rechnungen(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        datum TEXT, lieferant TEXT, rechnungsnr TEXT,
        brutto REAL, mwst_satz REAL DEFAULT 19,
        kategorie TEXT, konto TEXT, status TEXT DEFAULT 'offen',
        notiz TEXT, datei TEXT, guid TEXT,
        angelegt TEXT, gesendet TEXT);
    """)
    try:
        c.execute("ALTER TABLE rechnungen ADD COLUMN hash TEXT")
    except sqlite3.OperationalError:
        pass
    try:
        c.execute("ALTER TABLE rechnungen ADD COLUMN belegart TEXT DEFAULT 'Rechnungseingang Lieferanten'")
    except sqlite3.OperationalError:
        pass
    c.commit()
    c.close()


def settings():
    s = dict(SETTINGS_DEFAULT)
    for r in db().execute("SELECT k, v FROM settings"):
        s[r["k"]] = r["v"]
    return s


def netto(brutto, satz):
    return round(brutto / (1 + satz / 100), 2) if satz else round(brutto, 2)


# ---------------------------------------------------------------- Oberfläche
CSS = """
:root{--accent:#334155;--accentd:#1e293b;--dark:#4a4a4a;--line:#d8d8d8;--soft:#f0efec;--head:#2b2b2b}
body{font-family:'Source Sans 3','Source Sans Pro',system-ui,'Segoe UI',sans-serif;margin:0;background:#e3e5ea;color:#1c1c1c;line-height:1.5}
h1,h2,h3,th,header b,button,.btn,label{font-family:Tahoma,Arial,sans-serif}
h2,h3{color:var(--head);margin:0 0 10px} h3{font-size:15px;margin-top:18px}
header{background:var(--dark);color:#fff;padding:0 24px;min-height:52px;display:flex;gap:6px;align-items:center;flex-wrap:wrap}
header b{font-size:16px;letter-spacing:.01em;margin-right:auto;padding:12px 0}
header a{color:#fff;text-decoration:none;font-weight:700;font-size:13px;padding:17px 12px;border-bottom:3px solid transparent}
header a:hover{border-bottom-color:#c9c9c9}
main{max-width:1160px;margin:22px auto;padding:0 16px}
a{color:var(--accent)}
table{border-collapse:collapse;width:100%;background:#fff;border:1px solid var(--line)}
th,td{padding:8px 11px;border-bottom:1px solid #e6e6e6;text-align:left;font-size:14px}
th{background:var(--soft);color:var(--head);font-size:13px} td.r,th.r{text-align:right;font-variant-numeric:tabular-nums}
tr:hover td{background:#fafafa}
.card{background:#fff;padding:18px 22px;margin-bottom:18px;border:1px solid var(--line);border-left:3px solid var(--accent);border-radius:6px}
label{display:block;font-size:13px;margin:10px 0 3px;font-weight:700;color:var(--head)}
input,select,textarea{padding:8px 9px;font-size:15px;font-family:inherit;width:100%;box-sizing:border-box;border:1px solid #c7c9cf;border-radius:4px;background:#fff}
input:focus,select:focus,textarea:focus{outline:2px solid var(--accent);outline-offset:-1px}
input[type=checkbox]{width:auto}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:0 16px}
button,.btn{background:var(--accent);color:#fff;border:0;padding:10px 20px;border-radius:3px;font-size:14px;font-weight:700;cursor:pointer;text-decoration:none;display:inline-block}
button:hover,.btn:hover{background:var(--accentd)}
button.sek,.btn.sek{background:#fff;color:var(--accent);border:1px solid var(--accent)}
button.sek:hover,.btn.sek:hover{background:var(--soft)}
.msg{padding:11px 15px;margin-bottom:14px;background:var(--soft);border:1px solid var(--line);border-left:3px solid var(--accent);border-radius:6px}
.st-offen{color:#b45309;font-weight:600}.st-bezahlt{color:#047857;font-weight:600}.st-an{color:var(--accent);font-weight:600}
small{color:#6b7178} code{background:var(--soft);padding:1px 5px;border-radius:3px}
@media(max-width:700px){header a{padding:10px 8px}}
"""

LAYOUT = """<!doctype html><html lang=de><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1"><title>Rechnungen</title>
<style>{{css}}</style>
<header><b>Rechnungen &amp; DATEV</b>
<a href="{{url_for('index')}}">Übersicht</a><a href="{{url_for('neu')}}">+ Neue Rechnung</a><a href="{{url_for('monat')}}">Monatsunterlagen</a>
<a href="{{url_for('einstellungen')}}">Einstellungen</a></header><main>
{% for m in get_flashed_messages() %}<div class=msg>{{m}}</div>{% endfor %}
{{body|safe}}</main></html>"""


def page(body_tpl, **ctx):
    body = render_template_string(body_tpl, **ctx)
    return render_template_string(LAYOUT, css=CSS, body=body)


INDEX = """
<form method=get class=card style="display:flex;gap:12px;align-items:end">
 <div style="flex:1"><label>Suche</label><input name=q value="{{q}}" placeholder="Lieferant, Nummer, Notiz"></div>
 <div><label>Monat</label><input type=month name=monat value="{{monat}}"></div>
 <div><label>Belegart</label><select name=belegart><option value="">alle</option>
  {% for b in BELEGARTEN %}<option {{'selected' if b==belegart}}>{{b}}</option>{% endfor %}</select></div>
 <div><label>Status</label><select name=status><option value="">alle</option>
  {% for s in STATUS %}<option {{'selected' if s==status}}>{{s}}</option>{% endfor %}</select></div>
 <button>Filtern</button></form>
<form method=post action="{{url_for('eingang_jetzt')}}" class=card style="display:flex;gap:14px;align-items:center">
 <span style="flex:1">Eingangsordner: <code>{{ordner}}</code>
 {% if unklar %} &middot; <a href="{{url_for('index',belegart=UNKLAR)}}"><b style="color:#b45309">{{unklar}} nicht zugeordnet</b></a>{% endif %}</span>
 <button class=sek>Jetzt einlesen</button></form>
<form method=post action="{{url_for('export')}}">
<table><tr><th></th><th>Datum</th><th>Belegart</th><th>Lieferant</th><th>Rechnungsnr.</th><th>Kategorie</th>
<th class=r>Netto</th><th class=r>Brutto</th><th>Status</th><th>Beleg</th><th></th></tr>
{% for r in rows %}<tr>
 <td><input type=checkbox name=ids value="{{r.id}}" style="width:auto" {{'checked' if r.status!='an DATEV gesendet'}}></td>
 <td>{{r.datum}}</td><td><small>{{r.belegart}}</small></td><td>{{r.lieferant}}</td><td>{{r.rechnungsnr}}</td><td>{{r.kategorie}} <small>({{r.konto}})</small></td>
 <td class=r>{{'%.2f'|format(r.netto)|replace('.',',')}}</td><td class=r>{{'%.2f'|format(r.brutto)|replace('.',',')}}</td>
 <td class="st-{{ 'an' if r.status.startswith('an') else r.status }}">{{r.status}}</td>
 <td>{% if r.datei %}<a href="{{url_for('beleg',rid=r.id)}}" target=_blank>öffnen</a>{% else %}<small>fehlt</small>{% endif %}</td>
 <td><a href="{{url_for('bearbeiten',rid=r.id)}}">bearbeiten</a></td></tr>
{% else %}<tr><td colspan=11>Noch keine Rechnungen.</td></tr>{% endfor %}
<tr><th colspan=6 class=r>Summe ({{rows|length}})</th><th class=r>{{'%.2f'|format(sn)|replace('.',',')}}</th>
<th class=r>{{'%.2f'|format(sb)|replace('.',',')}}</th><th colspan=3></th></tr></table>
<p style="display:flex;gap:10px">
<button name=aktion value=zip>DATEV-Export (ZIP) für markierte</button>
<button class=sek name=aktion value=mail>Per E-Mail an DATEV senden</button></p>
<small>Markierte Rechnungen werden exportiert und danach als „an DATEV gesendet“ gekennzeichnet.</small>
</form>"""

FORM = """
<form method=post enctype=multipart/form-data class=card>
<h2>{{'Rechnung bearbeiten' if r.id else 'Neue Rechnung'}}</h2>
<div class=grid>
<div><label>Belegart</label><select name=belegart>
 {% for b in BELEGARTEN %}<option {{'selected' if b==r.belegart}}>{{b}}</option>{% endfor %}</select></div>
<div><label>Rechnungsdatum</label><input type=date name=datum value="{{r.datum}}" required></div>
<div><label>Lieferant</label><input name=lieferant value="{{r.lieferant}}" list=lief required><datalist id=lief>{% for l in LIEFERANTEN %}<option value="{{l}}">{% endfor %}</datalist></div>
<div><label>Rechnungsnummer</label><input name=rechnungsnr value="{{r.rechnungsnr}}"></div>
<div><label>Bruttobetrag (€, nur Rechnungseingang nötig)</label><input name=brutto value="{{'%.2f'|format(r.brutto)|replace('.',',') if r.brutto else ''}}"></div>
<div><label>MwSt.-Satz</label><select name=mwst_satz>
 {% for s in (19,7,0) %}<option value="{{s}}" {{'selected' if r.mwst_satz==s}}>{{s}} %</option>{% endfor %}</select></div>
<div><label>Kategorie</label><select name=kategorie>
 {% for k,v in KAT.items() %}<option {{'selected' if k==r.kategorie}}>{{k}}</option>{% endfor %}</select></div>
<div><label>Aufwandskonto (leer = Standard der Kategorie)</label><input name=konto value="{{r.konto or ''}}"></div>
<div><label>Status</label><select name=status>{% for s in STATUS %}<option {{'selected' if s==r.status}}>{{s}}</option>{% endfor %}</select></div>
</div>
<label>Notiz</label><textarea name=notiz rows=2>{{r.notiz or ''}}</textarea>
<label>Beleg (PDF/JPG/PNG){{' – vorhanden, neue Datei ersetzt sie' if r.datei}}</label><input type=file name=datei accept=".pdf,.jpg,.jpeg,.png,.tif,.tiff">
<p><button>Speichern</button> <a class="btn sek" href="{{url_for('index')}}">Abbrechen</a></p>
</form>
{% if r.id %}<form method=post action="{{url_for('loeschen',rid=r.id)}}" onsubmit="return confirm('Rechnung wirklich löschen?')"><button class=sek>Löschen</button></form>{% endif %}"""

EINST = """
<form method=post class=card><h2>Einstellungen</h2>
<h3>DATEV</h3><div class=grid>
<div><label>Beraternummer</label><input name=beraternr value="{{s.beraternr}}" required></div>
<div><label>Mandantennummer</label><input name=mandantennr value="{{s.mandantennr}}" required></div>
<div><label>Beginn Wirtschaftsjahr</label><input type=date name=wj_beginn value="{{s.wj_beginn}}"></div>
<div><label>Sachkontenlänge</label><input name=sachkontenlaenge value="{{s.sachkontenlaenge}}"></div>
<div><label>Gegenkonto (Verbindlichkeiten, SKR03: 1600)</label><input name=gegenkonto value="{{s.gegenkonto}}"></div>
<div><label>Diktatkürzel (optional)</label><input name=diktatkuerzel value="{{s.diktatkuerzel}}"></div></div>
<h3>E-Mail-Versand an „DATEV Belege online“ (optional)</h3><div class=grid>
<div><label>Belege-Mail-Adresse des Mandanten</label><input name=datev_mail value="{{s.datev_mail}}"></div>
<div><label>Absender-Adresse</label><input name=absender value="{{s.absender}}"></div>
<div><label>SMTP-Server</label><input name=smtp_host value="{{s.smtp_host}}"></div>
<div><label>SMTP-Port</label><input name=smtp_port value="{{s.smtp_port}}"></div>
<div><label>SMTP-Benutzer</label><input name=smtp_user value="{{s.smtp_user}}"></div>
<div><label>SMTP-Passwort</label><input type=password name=smtp_pass value="{{s.smtp_pass}}"></div></div>
<h3>Automatischer Eingang (Kassensoftware &rarr; PDF)</h3>
<label>Eingangsordner (hier speicherst du die PDFs aus der Kasse ab)</label><input name=eingang_ordner value="{{s.eingang_ordner}}">
<label>Lieferanten (ein Name pro Zeile; längere Namen zuerst, z. B. „Jura Gastro“ vor „Jura“)</label>
<textarea name=lieferanten rows=8>{{s.lieferanten}}</textarea>
<label>Zuordnungsregeln (eine Zeile je Belegart: <code>Belegart = stichwort, stichwort</code>; oberste passende Zeile gewinnt)</label>
<textarea name=regeln rows=8 style="font-family:monospace">{{s.regeln}}</textarea>
<small>Alles bleibt lokal in data/rechnungen.db auf diesem Rechner.</small>
<p><button>Speichern</button></p></form>"""


# ---------------------------------------------------------------- Routen
def lade(rid):
    r = db().execute("SELECT * FROM rechnungen WHERE id=?", (rid,)).fetchone()
    if not r:
        abort(404)
    return r


@app.route("/")
def index():
    q = request.args.get("q", "").strip()
    status = request.args.get("status", "")
    monat = request.args.get("monat", "")
    belegart = request.args.get("belegart", "")
    sql, par = "SELECT * FROM rechnungen WHERE 1=1", []
    if q:
        sql += " AND (lieferant LIKE ? OR rechnungsnr LIKE ? OR notiz LIKE ?)"
        par += [f"%{q}%"] * 3
    if status:
        sql += " AND status=?"
        par.append(status)
    if monat:
        sql += " AND substr(datum,1,7)=?"
        par.append(monat)
    if belegart:
        sql += " AND belegart=?"
        par.append(belegart)
    rows = []
    for r in db().execute(sql + " ORDER BY datum DESC, id DESC", par):
        d = dict(r)
        d["netto"] = netto(r["brutto"], r["mwst_satz"])
        rows.append(type("R", (), d))
    return page(INDEX, rows=rows, q=q, status=status, STATUS=STATUS, monat=monat,
                belegart=belegart, BELEGARTEN=BELEGARTEN_ALLE, UNKLAR=UNKLAR,
                ordner=settings()["eingang_ordner"],
                unklar=db().execute("SELECT COUNT(*) FROM rechnungen WHERE belegart=?", (UNKLAR,)).fetchone()[0],
                sb=sum(r.brutto for r in rows), sn=sum(r.netto for r in rows))


def _speichern(rid=None):
    f = request.form
    try:
        b = f["brutto"].strip()
        brutto = 0.0 if not b else (float(b.replace(".", "").replace(",", ".")) if "," in b else float(b))
    except ValueError:
        flash("Bruttobetrag ungültig.")
        return None
    kat = f["kategorie"] if f["kategorie"] in KATEGORIEN else "Sonstiges"
    konto = f.get("konto", "").strip() or KATEGORIEN[kat]
    datei_name = None
    up = request.files.get("datei")
    if up and up.filename:
        ext = Path(up.filename).suffix.lower()
        if ext not in ERLAUBT:
            flash("Dateityp nicht erlaubt (PDF, JPG, PNG, TIF).")
            return None
        datei_name = f"{uuid.uuid4().hex}{ext}"
        up.save(BELEGE / datei_name)
    belegart = f.get("belegart") if f.get("belegart") in BELEGARTEN_ALLE else EINGANG
    vals = (f["datum"], f["lieferant"].strip(), f["rechnungsnr"].strip(), brutto,
            float(f["mwst_satz"]), kat, konto, f["status"], f["notiz"].strip())
    if rid is None:
        db().execute("INSERT INTO rechnungen(datum,lieferant,rechnungsnr,brutto,mwst_satz,kategorie,"
                     "konto,status,notiz,datei,guid,angelegt,belegart) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
                     vals + (datei_name, str(uuid.uuid4()), datetime.now().isoformat(timespec="seconds"), belegart))
    else:
        db().execute("UPDATE rechnungen SET datum=?,lieferant=?,rechnungsnr=?,brutto=?,mwst_satz=?,"
                     "kategorie=?,konto=?,status=?,notiz=?,belegart=? WHERE id=?", vals + (belegart, rid))
        if datei_name:
            alt = lade(rid)["datei"]
            db().execute("UPDATE rechnungen SET datei=? WHERE id=?", (datei_name, rid))
            if alt:
                (BELEGE / alt).unlink(missing_ok=True)
    db().commit()
    return True


@app.route("/neu", methods=["GET", "POST"])
def neu():
    if request.method == "POST" and _speichern():
        flash("Rechnung gespeichert.")
        return redirect(url_for("index"))
    r = type("R", (), dict(id=None, datum=date.today().isoformat(), lieferant="", rechnungsnr="",
                           brutto=0, mwst_satz=19, kategorie="Sonstiges", konto="",
                           status="offen", notiz="", datei=None, belegart=EINGANG))
    return page(FORM, r=r, KAT=KATEGORIEN, STATUS=STATUS, BELEGARTEN=BELEGARTEN_ALLE,
                LIEFERANTEN=lieferanten_liste(settings()))


@app.route("/<int:rid>/bearbeiten", methods=["GET", "POST"])
def bearbeiten(rid):
    r = lade(rid)
    if request.method == "POST" and _speichern(rid):
        flash("Änderungen gespeichert.")
        return redirect(url_for("index"))
    return page(FORM, r=type("R", (), dict(r)), KAT=KATEGORIEN, STATUS=STATUS, BELEGARTEN=BELEGARTEN_ALLE,
                LIEFERANTEN=lieferanten_liste(settings()))


@app.route("/<int:rid>/loeschen", methods=["POST"])
def loeschen(rid):
    r = lade(rid)
    if r["datei"]:
        (BELEGE / r["datei"]).unlink(missing_ok=True)
    db().execute("DELETE FROM rechnungen WHERE id=?", (rid,))
    db().commit()
    flash("Rechnung gelöscht.")
    return redirect(url_for("index"))


@app.route("/<int:rid>/beleg")
def beleg(rid):
    r = lade(rid)
    if not r["datei"]:
        abort(404)
    return send_file(BELEGE / r["datei"])


@app.route("/einstellungen", methods=["GET", "POST"])
def einstellungen():
    if request.method == "POST":
        for k in SETTINGS_DEFAULT:
            db().execute("INSERT OR REPLACE INTO settings(k,v) VALUES(?,?)", (k, request.form.get(k, "").strip()))
        db().commit()
        flash("Einstellungen gespeichert.")
        return redirect(url_for("einstellungen"))
    return page(EINST, s=settings())


# ---------------------------------------------------------------- Automatischer Eingang
def regeln_parsen(text):
    out = []
    for zeile in (text or "").splitlines():
        if "=" in zeile:
            art, _, kw = zeile.partition("=")
            art = art.strip()
            if art in BELEGARTEN:
                out.append((art, [k.strip().lower() for k in kw.split(",") if k.strip()]))
    return out


def lieferanten_liste(cfg):
    return [z.strip() for z in (cfg.get("lieferanten") or "").splitlines() if z.strip()]


def finde_lieferant(text, dateiname, liste):
    heu = text + "\n" + dateiname
    for name in liste:
        if re.search(r"(?<!\w)" + re.escape(name) + r"(?!\w)", heu, re.I):
            return name
    return ""


def pdf_text(pfad):
    try:
        r = PdfReader(str(pfad))
        return "\n".join((pg.extract_text() or "") for pg in r.pages[:3])
    except Exception:  # noqa: BLE001
        return ""


def klassifiziere(text, dateiname, regeln):
    heu = (text + "\n" + dateiname).lower()
    for art, kws in regeln:
        for k in kws:
            if k.startswith("nr:"):
                if re.search(r"(?<!\d)" + re.escape(k[3:].strip()) + r"\d{2,}", heu):
                    return art
            elif k in heu:
                return art
    return UNKLAR


def finde_datum(text, fallback):
    for t, m_, j in re.findall(r"\b(\d{1,2})\.(\d{1,2})\.(\d{4})\b", text):
        try:
            d = date(int(j), int(m_), int(t))
            if 2000 <= d.year <= 2100:
                return d.isoformat()
        except ValueError:
            continue
    return fallback


def finde_nummer(text):
    m = re.search(r"(?:Rechnungs?-?\s?(?:nummer|nr\.?)|Beleg-?\s?Nr\.?)\s*:?\s*([A-Za-z0-9][A-Za-z0-9\-/]*)",
                  text, re.I)
    return m.group(1) if m else ""


def eingang_einlesen():
    """Liest alle neuen PDFs/Bilder aus dem Eingangsordner. Eigene DB-Verbindung (laeuft auch im Thread)."""
    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    cfg = dict(SETTINGS_DEFAULT)
    cfg.update({r["k"]: r["v"] for r in c.execute("SELECT k, v FROM settings")})
    ordner = Path(cfg["eingang_ordner"] or STANDARD_ORDNER)
    fertig = ordner / "verarbeitet"
    try:
        fertig.mkdir(parents=True, exist_ok=True)
    except OSError:  # Laufwerk (z. B. Z:) nicht erreichbar
        c.close()
        return 0
    regeln = regeln_parsen(cfg["regeln"])
    n = 0
    for f in sorted(ordner.iterdir()):
        if not f.is_file() or f.suffix.lower() not in ERLAUBT:
            continue
        if time.time() - f.stat().st_mtime < 3:  # Drucker schreibt evtl. noch
            continue
        try:
            daten = f.read_bytes()
        except OSError:
            continue
        h = hashlib.sha1(daten).hexdigest()
        ziel_alt = fertig / f.name
        if c.execute("SELECT 1 FROM rechnungen WHERE hash=?", (h,)).fetchone():
            shutil.move(str(f), str(fertig / f"doppelt_{int(time.time())}_{f.name}"))
            continue
        text = pdf_text(f) if f.suffix.lower() == ".pdf" else ""
        art = klassifiziere(text, f.stem, regeln)
        lief = ""
        if art in (UNKLAR, EINGANG):
            lief = finde_lieferant(text, f.stem, lieferanten_liste(cfg))
            if lief:
                art = EINGANG
        mtime = date.fromtimestamp(f.stat().st_mtime).isoformat()
        datum = finde_datum(text, mtime)
        name = f"{uuid.uuid4().hex}{f.suffix.lower()}"
        (BELEGE / name).write_bytes(daten)
        c.execute("INSERT INTO rechnungen(datum,lieferant,rechnungsnr,brutto,mwst_satz,kategorie,konto,status,"
                  "notiz,datei,guid,angelegt,belegart,hash) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                  (datum, lief or art, finde_nummer(text), 0, 0, "Sonstiges", "", "offen", f.name, name,
                   str(uuid.uuid4()), datetime.now().isoformat(timespec="seconds"), art, h))
        c.commit()
        if ziel_alt.exists():
            ziel_alt = fertig / f"{int(time.time())}_{f.name}"
        shutil.move(str(f), str(ziel_alt))
        n += 1
    c.close()
    return n


def _waechter():
    while True:
        try:
            eingang_einlesen()
        except Exception as e:  # noqa: BLE001
            print("Eingang:", e)
        time.sleep(10)


@app.route("/eingang/jetzt", methods=["POST"])
def eingang_jetzt():
    n = eingang_einlesen()
    flash(f"{n} neue Dateien eingelesen." if n else "Keine neuen Dateien im Eingangsordner.")
    return redirect(url_for("index"))


# ---------------------------------------------------------------- Monatsunterlagen
MONAT = """
<form class=card method=get><label>Monat</label>
<input type=month name=m value="{{m}}" onchange="this.form.submit()" style="width:auto"></form>
<form method=post enctype=multipart/form-data class=card>
<h2>Monatsunterlagen {{m}}</h2><input type=hidden name=m value="{{m}}">
<table><tr><th>Belegart</th><th>Vorhanden</th><th>Hochladen (mehrere Dateien möglich)</th></tr>
{% for b in BELEGARTEN %}<tr><td>{{b}}</td>
<td>{% if anzahl.get(b) %}<b style="color:#047857">&#10003; {{anzahl[b]}}</b>{% else %}<span style="color:#b45309">fehlt</span>{% endif %}</td>
<td><input type=file name="f{{loop.index0}}" multiple accept=".pdf,.jpg,.jpeg,.png,.tif,.tiff"></td></tr>{% endfor %}</table>
<p><button>Hochladen</button> <a class="btn sek" href="{{url_for('index',monat=m)}}">Belege dieses Monats anzeigen</a></p>
</form>
<form method=post action="{{url_for('paket')}}" class=card>
<h2>Monatspaket für Unternehmen online</h2><input type=hidden name=m value="{{m}}">
<p>Fügt pro Belegart alle PDFs/Bilder von {{m}} zu <b>einer</b> PDF zusammen
(z. B. <code>{{m}}_Kassenbuch.pdf</code>) und legt sie in einen Ordner. Diese Dateien lädst du in
DATEV Unternehmen online unter „Belege“ hoch.</p>
<button>Monatspaket erstellen &amp; Ordner öffnen</button></form>
<form class=card style="background:none;padding:0"><small>Pro Datei entsteht ein Beleg mit Datum = Monatsende. Rechnungseingänge mit Beträgen besser über „+ Neue Rechnung“ erfassen.</small>
</form>"""


@app.route("/monat", methods=["GET", "POST"])
def monat():
    m = request.values.get("m") or date.today().strftime("%Y-%m")
    if request.method == "POST":
        jahr, mon = int(m[:4]), int(m[5:7])
        ende = (date(jahr + (mon == 12), mon % 12 + 1, 1) - date.resolution).isoformat()
        n = 0
        for i, b in enumerate(BELEGARTEN):
            for up in request.files.getlist(f"f{i}"):
                if not up.filename:
                    continue
                ext = Path(up.filename).suffix.lower()
                if ext not in ERLAUBT:
                    flash(f"{up.filename}: Dateityp nicht erlaubt.")
                    continue
                name = f"{uuid.uuid4().hex}{ext}"
                up.save(BELEGE / name)
                db().execute("INSERT INTO rechnungen(datum,lieferant,rechnungsnr,brutto,mwst_satz,kategorie,"
                             "konto,status,notiz,datei,guid,angelegt,belegart) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
                             (ende, b, "", 0, 0, "Sonstiges", "", "offen", Path(up.filename).name, name,
                              str(uuid.uuid4()), datetime.now().isoformat(timespec="seconds"), b))
                n += 1
        db().commit()
        flash(f"{n} Dateien gespeichert.")
        return redirect(url_for("monat", m=m))
    anzahl = {r["belegart"]: r["n"] for r in db().execute(
        "SELECT belegart, COUNT(*) n FROM rechnungen WHERE substr(datum,1,7)=? GROUP BY belegart", (m,))}
    return page(MONAT, m=m, BELEGARTEN=BELEGARTEN, anzahl=anzahl)


def _in_pdf(w, pfad):
    """Hängt PDF-Seiten bzw. ein Bild als PDF-Seite an den Writer an."""
    if pfad.suffix.lower() == ".pdf":
        w.append(str(pfad))
        return
    img = Image.open(pfad)
    if getattr(img, "n_frames", 1) > 1:  # mehrseitiges TIFF
        frames = []
        for i in range(img.n_frames):
            img.seek(i)
            frames.append(img.convert("RGB").copy())
    else:
        frames = [img.convert("RGB")]
    buf = io.BytesIO()
    frames[0].save(buf, "PDF", save_all=True, append_images=frames[1:], resolution=150)
    buf.seek(0)
    w.append(buf)


@app.route("/monat/paket", methods=["POST"])
def paket():
    m = request.form["m"]
    ziel = PAKETE / m
    ziel.mkdir(parents=True, exist_ok=True)
    fertig, fehler = [], []
    for b in BELEGARTEN:
        rows = db().execute("SELECT * FROM rechnungen WHERE substr(datum,1,7)=? AND belegart=? AND datei "
                            "IS NOT NULL ORDER BY datum, id", (m, b)).fetchall()
        if not rows:
            continue
        w = PdfWriter()
        for r in rows:
            try:
                _in_pdf(w, BELEGE / r["datei"])
            except Exception as e:  # noqa: BLE001
                fehler.append(f'{r["notiz"] or r["datei"]}: {e}')
        if not len(w.pages):
            continue
        name = re.sub(r"[^A-Za-z0-9_.-]+", "_", f"{m}_{b}") + ".pdf"
        with open(ziel / name, "wb") as fh:
            w.write(fh)
        w.close()
        fertig.append(f"{name} ({len(rows)} Dateien, {(ziel / name).stat().st_size / 1e6:.1f} MB)")
        for r in rows:
            db().execute("UPDATE rechnungen SET status='an DATEV gesendet', gesendet=? WHERE id=?",
                         (datetime.now().isoformat(timespec="seconds"), r["id"]))
    db().commit()
    if fehler:
        flash("Nicht verarbeitbar: " + "; ".join(fehler))
    flash("Erstellt: " + (", ".join(fertig) if fertig else "nichts – für diesen Monat liegen keine Belege vor.")
          + f" → {ziel}")
    if fertig and hasattr(os, "startfile"):
        os.startfile(ziel)
    return redirect(url_for("monat", m=m))


# ---------------------------------------------------------------- DATEV-Export
def _betrag(x):
    return f"{x:.2f}".replace(".", ",")


def buchungsstapel_csv(rows, s):
    """DATEV-Format 'Buchungsstapel' (EXTF, Version 700 / Format 21), nur Spalten 1-20."""
    jetzt = datetime.now().strftime("%Y%m%d%H%M%S") + "000"
    daten = sorted(r["datum"] for r in rows)
    von, bis = daten[0].replace("-", ""), daten[-1].replace("-", "")
    wj = (s["wj_beginn"] or f"{date.today().year}-01-01").replace("-", "")
    out = io.StringIO()
    w = csv.writer(out, delimiter=";", quoting=csv.QUOTE_NONNUMERIC, lineterminator="\r\n")
    # Kopfzeile: Zahlen ohne Anführungszeichen -> manuell schreiben
    q = lambda t: f'"{t}"'
    out.write(";".join([q("EXTF"), "700", "21", q("Buchungsstapel"), "13", jetzt, "", q("RE"), q(""), q(""),
                        s["beraternr"], s["mandantennr"], wj, s["sachkontenlaenge"], von, bis,
                        q("Eingangsrechnungen"), q(s["diktatkuerzel"]), "1", "0", "0", q("EUR")]) + "\r\n")
    spalten = ["Umsatz (ohne Soll/Haben-Kz)", "Soll/Haben-Kennzeichen", "WKZ Umsatz", "Kurs",
               "Basis-Umsatz", "WKZ Basis-Umsatz", "Konto", "Gegenkonto (ohne BU-Schlüssel)",
               "BU-Schlüssel", "Belegdatum", "Belegfeld 1", "Belegfeld 2", "Skonto", "Buchungstext",
               "Postensperre", "Diverse Adressnummer", "Geschäftspartnerbank", "Sachverhalt",
               "Zinssperre", "Beleglink"]
    out.write(";".join(spalten) + "\r\n")
    for r in rows:
        d = datetime.strptime(r["datum"], "%Y-%m-%d")
        bu = {19: "9", 7: "8"}.get(int(r["mwst_satz"]), "")
        text = f'{r["lieferant"]} {r["rechnungsnr"] or ""}'.strip()[:60].replace('"', "'")
        link = f'BEDI "{r["guid"]}"' if r["datei"] else ""
        felder = [_betrag(r["brutto"]), "S", "EUR", "", "", "", r["konto"], s["gegenkonto"], bu,
                  d.strftime("%d%m"), (r["rechnungsnr"] or "").replace('"', "")[:36], "", "", text,
                  "", "", "", "", "", link]
        zahl = {0, 3, 4, 6, 7, 8, 9}
        out.write(";".join(v if (i in zahl or v == "") else '"' + v.replace('"', '""') + '"'
                           for i, v in enumerate(felder)) + "\r\n")
    return out.getvalue().encode("cp1252", errors="replace")


def document_xml(rows):
    """document.xml für den Beleg-Import (DATEV Belegbilderservice, Schema v05.0)."""
    jetzt = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    docs = []
    for r in rows:
        if not r["datei"]:
            continue
        docs.append(f'<document guid="{r["guid"]}"><extension xsi:type="File" name="{r["datei"]}"/>'
                    f'</document>')
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<archive xmlns="http://xml.datev.de/bedi/tps/document/v05.0" '
            'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
            'xsi:schemaLocation="http://xml.datev.de/bedi/tps/document/v05.0 Document_v050.xsd" '
            f'version="5.0" generatingSystem="Rechnungen-App"><header><date>{jetzt}</date></header>'
            f'<content>{"".join(docs)}</content></archive>').encode("utf-8")


def _markiere(ids):
    jetzt = datetime.now().isoformat(timespec="seconds")
    for i in ids:
        db().execute("UPDATE rechnungen SET status='an DATEV gesendet', gesendet=? WHERE id=?", (jetzt, i))
    db().commit()


@app.route("/export", methods=["POST"])
def export():
    ids = [int(i) for i in request.form.getlist("ids")]
    if not ids:
        flash("Keine Rechnungen markiert.")
        return redirect(url_for("index"))
    s = settings()
    if request.form.get("aktion") == "mail":
        return _mailen(ids, s)
    if not (s["beraternr"] and s["mandantennr"]):
        flash("Bitte zuerst Berater- und Mandantennummer in den Einstellungen eintragen.")
        return redirect(url_for("einstellungen"))
    rows = [lade(i) for i in ids]
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        buch = [r for r in rows if r["belegart"] == EINGANG and r["brutto"]]
        if buch:
            z.writestr(f"EXTF_Buchungsstapel_{date.today():%Y%m%d}.csv", buchungsstapel_csv(buch, s))
        z.writestr("document.xml", document_xml(rows))
        for r in rows:
            if r["datei"]:
                z.write(BELEGE / r["datei"], r["datei"])
        z.writestr("Uebersicht.txt", "\n".join(
            f'{r["datei"] or "-"}\t{r["datum"]}\t{r["belegart"]}\t{r["lieferant"]}' for r in rows))
    _markiere(ids)
    buf.seek(0)
    return send_file(buf, mimetype="application/zip", as_attachment=True,
                     download_name=f"DATEV_Export_{date.today():%Y%m%d}.zip")


def _mailen(ids, s):
    if not (s["datev_mail"] and s["smtp_host"] and s["absender"]):
        flash("Bitte Belege-Mail-Adresse, Absender und SMTP-Server in den Einstellungen eintragen.")
        return redirect(url_for("einstellungen"))
    gesendet, fehlt = [], 0
    try:
        with smtplib.SMTP(s["smtp_host"], int(s["smtp_port"] or 587), timeout=30) as smtp:
            smtp.starttls()
            if s["smtp_user"]:
                smtp.login(s["smtp_user"], s["smtp_pass"])
            for i in ids:
                r = lade(i)
                if not r["datei"]:
                    fehlt += 1
                    continue
                m = EmailMessage()
                m["From"], m["To"] = s["absender"], s["datev_mail"]
                m["Subject"] = f'Beleg {r["lieferant"]} {r["rechnungsnr"] or ""}'.strip()
                m.set_content("Eingangsrechnung zur Buchung.")
                p = BELEGE / r["datei"]
                ext = p.suffix.lower()
                mt = "application/pdf" if ext == ".pdf" else "image/" + ext.strip(".").replace("jpg", "jpeg")
                name = secure_filename(f'{r["datum"]}_{r["lieferant"]}_{r["rechnungsnr"] or r["id"]}{ext}')
                m.add_attachment(p.read_bytes(), maintype=mt.split("/")[0], subtype=mt.split("/")[1],
                                 filename=name)
                smtp.send_message(m)
                gesendet.append(i)
    except Exception as e:  # noqa: BLE001
        _markiere(gesendet)
        flash(f"Mailversand abgebrochen nach {len(gesendet)} Belegen: {e}")
        return redirect(url_for("index"))
    _markiere(gesendet)
    flash(f"{len(gesendet)} Belege gesendet" + (f", {fehlt} ohne Datei übersprungen." if fehlt else "."))
    return redirect(url_for("index"))


if __name__ == "__main__":
    init_db()
    try:
        Path(STANDARD_ORDNER).mkdir(parents=True, exist_ok=True)
    except OSError:
        print("Eingangsordner nicht erreichbar:", STANDARD_ORDNER)
    threading.Thread(target=_waechter, daemon=True).start()
    app.run(host="127.0.0.1", port=5055, debug=False)
