"""Rechnungsverwaltung mit DATEV-Export (lokal, SQLite).

Start:  py app.py   ->  http://127.0.0.1:5055
Daten:  data/rechnungen.db und data/belege/  (nicht in Git)
"""
import csv
import io
import os
import re
import hashlib
import itertools
import shutil
import smtplib
import sqlite3
import threading
import time
import uuid
import xml.etree.ElementTree as ET
import zipfile
from datetime import date, datetime, timedelta
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
ZAHLARTEN = ("Bank", "Bar", "Karte", "Scheck")
RECHNUNGSARTEN = ("Rechnungsausgang Service", "Rechnungsausgang Verkauf", "Rechnungsausgang eBay", "Rechnungseingang Lieferanten")
AUSGANG_RECHNUNGEN = ("Rechnungsausgang Service", "Rechnungsausgang Verkauf", "Rechnungsausgang eBay")
BELEGARTEN_ALLE = BELEGARTEN + [UNKLAR]
STANDARD_ORDNER = r"Z:\Buchhaltung\Eingang"
BANK_OHNE_BELEG = ("entgeltabrechnung",)   # Bankbuchungen, die grundsaetzlich keinen Beleg brauchen (Stichwort im Zweck/Namen)
BACKUP_ORDNER = r"Z:\Buchhaltung\Backup-Rechnungen-App"   # App und Daten liegen lokal, hierhin geht nur die Sicherung
# Zuordnungsregeln: "Belegart = stichwort, stichwort" - erste passende Zeile gewinnt.
# Gesucht wird im PDF-Text und im Dateinamen (Gross/Klein egal).
# "nr:261" = Rechnungsnummer beginnt mit 261.
STANDARD_LIEFERANTEN = """Jura Gastro = Wareneinkauf
Jura = Wareneinkauf
Amazon Business | Amazon Payments
Frank Windhorn | Windhorn
Nexi Germany | Nexi
Amazon
REPA Italia s.r.l. a socio unico | REPA Italia
Entega
Ionos
Flaschenpost
DKV
BND
VW Leasing
Axa
Baloise
Böttcher
Deutsche Glasfaser
Gross
Ebay
Grover
GLS | General Logistics Systems ; abzug
Wentronic
Wertgarantie
BüroShop = Bürobedarf
büroshop24 GmbH = Bürobedarf"""
STANDARD_REGELN = """Rechnungsausgangliste = rechnungsausgangsliste, rechnungsausgangliste, ausgangsliste
Monatsjournal Kasse = monatsjournal
Kassenbuch = kassenbuch
Rechnungsausgang eBay = ebay
Rechnungsausgang Service = nr:263
Rechnungsausgang Verkauf = nr:261
Rechnungseingang Lieferanten = eingangsrechnung, lieferant"""
STATUS = ["noch nicht gesendet", "an DATEV gesendet"]   # DATEV-Stand
ZAHLUNG = ["offen", "teilweise", "bezahlt"]

SETTINGS_DEFAULT = {
    "beraternr": "", "mandantennr": "", "wj_beginn": f"{date.today().year}-01-01",
    "sachkontenlaenge": "4", "gegenkonto": "1600", "diktatkuerzel": "",
    "datev_mail": "", "smtp_host": "", "smtp_port": "587", "smtp_user": "",
    "smtp_pass": "", "absender": "",
    "start_datum": "2026-10-01",   # Anzeige ab diesem Tag; aeltere Rechnungen nur, solange sie offen sind
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
    CREATE TABLE IF NOT EXISTS kassenzeilen(
        id INTEGER PRIMARY KEY AUTOINCREMENT, dokument_id INTEGER, datum TEXT, beleg TEXT, name TEXT,
        betrag REAL, zeit TEXT, rechnungsnr TEXT, UNIQUE(datum, beleg, rechnungsnr));
    CREATE TABLE IF NOT EXISTS kasse_geprueft(dokument_id INTEGER PRIMARY KEY);
    CREATE TABLE IF NOT EXISTS kassentage(dokument_id INTEGER PRIMARY KEY, datum TEXT, credit REAL, bar REAL, scheck REAL);
    CREATE TABLE IF NOT EXISTS bank_ignoriert(bank_id INTEGER PRIMARY KEY, grund TEXT);
    CREATE TABLE IF NOT EXISTS quittiert(rechnungsnr TEXT PRIMARY KEY, bemerkung TEXT, am TEXT);
    CREATE TABLE IF NOT EXISTS bank(
        id INTEGER PRIMARY KEY AUTOINCREMENT, datum TEXT, betrag REAL, name TEXT, zweck TEXT,
        dokument TEXT, schluessel TEXT UNIQUE);
    CREATE TABLE IF NOT EXISTS zahlungen(
        id INTEGER PRIMARY KEY AUTOINCREMENT, quelle TEXT, datum TEXT, betrag REAL, rechnungsnr TEXT, info TEXT, bank_id INTEGER);
    CREATE TABLE IF NOT EXISTS rechnungen(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        datum TEXT, lieferant TEXT, rechnungsnr TEXT,
        brutto REAL, mwst_satz REAL DEFAULT 19,
        kategorie TEXT, konto TEXT, status TEXT DEFAULT 'noch nicht gesendet',
        notiz TEXT, datei TEXT, guid TEXT,
        angelegt TEXT, gesendet TEXT);
    """)
    try:
        c.execute("ALTER TABLE rechnungen ADD COLUMN zahlung TEXT DEFAULT 'offen'")
    except sqlite3.OperationalError:
        pass
    # frueher mischte 'status' Zahlung und DATEV-Stand
    c.execute("UPDATE rechnungen SET zahlung='bezahlt', status='noch nicht gesendet' WHERE status='bezahlt'")
    c.execute("UPDATE rechnungen SET status='noch nicht gesendet' WHERE status='offen'")
    try:  # Zahlart je Kassenbuch-Zeile: bestehende Kassenbuecher werden dafuer neu eingelesen
        c.execute("ALTER TABLE kassenzeilen ADD COLUMN zahlart TEXT")
        c.execute("DELETE FROM kasse_geprueft")
        c.execute("DELETE FROM kassenzeilen")
    except sqlite3.OperationalError:
        pass
    try:  # Skonto-Prozent laut Rechnungstext (NULL = noch nicht gelesen)
        c.execute("ALTER TABLE rechnungen ADD COLUMN skonto REAL")
    except sqlite3.OperationalError:
        pass
    try:
        c.execute("ALTER TABLE zahlungen ADD COLUMN zahlart TEXT")
    except sqlite3.OperationalError:
        pass
    for spalte in ("zahl_am TEXT", "zahl_quelle TEXT", "zahl_art TEXT"):
        try:
            c.execute(f"ALTER TABLE rechnungen ADD COLUMN {spalte}")
        except sqlite3.OperationalError:
            pass
    try:
        c.execute("ALTER TABLE rechnungen ADD COLUMN hash TEXT")
    except sqlite3.OperationalError:
        pass
    try:
        c.execute("ALTER TABLE rechnungen ADD COLUMN belegart TEXT DEFAULT 'Rechnungseingang Lieferanten'")
    except sqlite3.OperationalError:
        pass
    # Pruefsumme fuer aeltere Belege nachtragen, damit der Doppelt-Schutz auch sie erkennt
    for rid, datei in c.execute("SELECT id, datei FROM rechnungen WHERE hash IS NULL AND datei IS NOT NULL").fetchall():
        pf = BELEGE / datei
        if pf.exists():
            c.execute("UPDATE rechnungen SET hash=? WHERE id=?", (hashlib.sha1(pf.read_bytes()).hexdigest(), rid))
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
@font-face{font-family:'Source Sans 3';font-weight:400;font-display:swap;src:url(/static/fonts/source-sans-3-latin-400.woff2) format('woff2')}
@font-face{font-family:'Source Sans 3';font-weight:600;font-display:swap;src:url(/static/fonts/source-sans-3-latin-600.woff2) format('woff2')}
@font-face{font-family:'Source Sans 3';font-weight:700;font-display:swap;src:url(/static/fonts/source-sans-3-latin-700.woff2) format('woff2')}
:root{--accent:#334155;--accentd:#1e293b;--dark:#4a4a4a;--line:#d8d8d8;--soft:#f0efec;--head:#2b2b2b}
body{font-family:'Source Sans 3','Source Sans Pro',system-ui,'Segoe UI',sans-serif;margin:0;background:#e3e5ea;color:#1c1c1c;line-height:1.5}
h1,h2,h3,th,button,.btn,label{font-family:Tahoma,Arial,sans-serif}
h2,h3{color:var(--head);margin:0 0 10px} h3{font-size:15px;margin-top:18px}
.top{background:#fff;border-bottom:1px solid var(--line);text-align:center;padding:14px 16px 12px}
.top b{font-family:Tahoma,Arial,sans-serif;font-size:19px;color:var(--head);letter-spacing:.01em}
.top small{display:block;font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--accent);font-weight:700;margin-top:2px}
nav.band{background:var(--dark);position:sticky;top:0;z-index:90}
nav.band ul{list-style:none;margin:0 auto;padding:0;max-width:1200px;display:flex;flex-wrap:wrap;justify-content:center;align-items:center;gap:2px;font-family:Tahoma,Arial,sans-serif}
nav.band a{display:block;color:#c9c9c9;font-weight:400;font-size:14px;line-height:1.2;padding:12px 14px;text-decoration:none;white-space:nowrap}
nav.band a:hover,nav.band a:focus{color:#fff}
nav.band a.on{color:#fff;font-weight:700}
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
.st-neu{color:#6b7178}.st-an{color:var(--accent);font-weight:600}.z-offen{color:#b45309;font-weight:600}.z-teilweise{color:#1d4ed8;font-weight:600}.z-bezahlt{color:#047857;font-weight:600}
small{color:#6b7178} code{background:var(--soft);padding:1px 5px;border-radius:3px}
@media(max-width:700px){nav.band a{padding:10px 8px;font-size:13px}}
"""

LAYOUT = """<!doctype html><html lang=de><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1"><title>Rechnungen</title>
<link rel="icon" type="image/png" href="/static/icon.png"><link rel="shortcut icon" href="/static/icon.ico">
<style>{{css|safe}}</style>
<div class=top><b>Rechnungen &amp; DATEV</b><small>kaffeetechniker.de</small></div>
<nav class=band><ul>
<li><a href="{{url_for('index')}}" class="{{'on' if request.endpoint in ('index','bearbeiten') else ''}}">Übersicht</a></li>
<li><a href="{{url_for('abgleich')}}" class="{{'on' if request.endpoint=='abgleich' else ''}}">Abgleich</a></li>
<li><a href="{{url_for('zahlungen_seite')}}" class="{{'on' if request.endpoint=='zahlungen_seite' else ''}}">Zahlungen</a></li>
<li><a href="{{url_for('bank_seite')}}" class="{{'on' if request.endpoint=='bank_seite' else ''}}">Bank</a></li>
<li><a href="{{url_for('monat')}}" class="{{'on' if request.endpoint=='monat' else ''}}">Monatsunterlagen</a></li>
<li><a href="{{url_for('einstellungen')}}" class="{{'on' if request.endpoint=='einstellungen' else ''}}">Einstellungen</a></li>
</ul></nav><main>
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
 <div><label>DATEV</label><select name=status><option value="">alle</option>
  {% for s in STATUS %}<option {{'selected' if s==status}}>{{s}}</option>{% endfor %}</select></div>
 <div><label>Zahlung</label><select name=zahlung><option value="">alle</option>
  <option value="unbezahlt" {{'selected' if zahlung=='unbezahlt'}}>nur offene (offen + teilweise)</option>
  {% for z in ZAHLUNG %}<option {{'selected' if z==zahlung}}>{{z}}</option>{% endfor %}</select></div>
 <div><label>Zahlart</label><select name=zahlart><option value="">alle</option>
  {% for a in ZAHLARTEN %}<option {{'selected' if a==zahlart}}>{{a}}</option>{% endfor %}</select></div>
 <button>Filtern</button>
 {% if zahlung=='unbezahlt' %}<a class="btn sek" href="{{url_for('index',monat=monat,belegart=belegart)}}">Alle zeigen</a>
 {% else %}<a class="btn sek" href="{{url_for('index',zahlung='unbezahlt',monat=monat,belegart=belegart)}}">Nur offene</a>{% endif %}</form>
<form method=post action="{{url_for('eingang_jetzt')}}" class=card style="display:flex;gap:14px;align-items:center">
 <span style="flex:1">Eingangsordner: <code>{{ordner}}</code>
 {% if unklar %} &middot; <a href="{{url_for('index',belegart=UNKLAR)}}"><b style="color:#b45309">{{unklar}} nicht zugeordnet</b></a>{% endif %}
 {% if ausg_fehlt %} &middot; <a href="{{url_for('abgleich')}}"><b style="color:#b91c1c">{{ausg_fehlt}} Ausgangsrechnungen fehlen</b></a>{% endif %}</span>
 <button class=sek>Jetzt einlesen</button>
 <button class=sek formaction="{{url_for('neu_pruefen')}}">Neu prüfen</button></form>
{% if doppelte %}<div class=card style="border-left-color:#b91c1c"><b style="color:#b91c1c">Doppelte Belege</b>
 &ndash; dieselbe Datei ist mehrfach abgelegt:
 {% for g in doppelte %}<div>{% for r in g %}<a href="{{url_for('bearbeiten',rid=r.id)}}">#{{r.id}} {{r.rechnungsnr or r.lieferant}} ({{r.datum}})</a>{{' &middot; '|safe if not loop.last}}{% endfor %}</div>{% endfor %}
 <small>Das überzählige Exemplar kannst du unter &bdquo;bearbeiten&ldquo; löschen.</small></div>{% endif %}
<form method=post action="{{url_for('export')}}">
<table><tr><th></th><th>Datum</th><th>Belegart</th><th>Lieferant</th><th>Rechnungsnr.</th><th>Kategorie</th>
<th class=r>Brutto</th><th>Zahlung</th><th>Bezahlt am</th><th>Zahlart</th><th>DATEV</th><th>Beleg</th><th></th></tr>
{% for r in rows %}<tr>
 <td><input type=checkbox name=ids value="{{r.id}}" style="width:auto" {{'checked' if r.status!='an DATEV gesendet'}}></td>
 <td>{{r.datum}}</td><td><small>{{r.belegart}}</small></td><td>{{r.lieferant}}</td><td>{{r.rechnungsnr}}</td><td>{{r.kategorie}} <small>({{r.konto}})</small></td>
 <td class=r>{{'%.2f'|format(r.brutto)|replace('.',',')}}</td>
 {% if r.belegart in RECHNUNGSARTEN %}<td class="z-{{r.zahlung or 'offen'}}">{{r.zahlung or 'offen'}}</td>
 <td>{% if r.zahl_am %}{{r.zahl_am[8:]}}.{{r.zahl_am[5:7]}}.{{r.zahl_am[:4]}}{% endif %}</td>
 <td>{{r.zahl_art or ''}}</td>
 {% else %}<td>&ndash;</td><td></td><td></td>{% endif %}
 <td class="st-{{ 'an' if r.status.startswith('an') else 'neu' }}">{{r.status}}</td>
 <td>{% if r.datei %}<a href="{{url_for('beleg',rid=r.id)}}" target=_blank>öffnen</a>{% else %}<small>fehlt</small>{% endif %}</td>
 <td><a href="{{url_for('bearbeiten',rid=r.id)}}">bearbeiten</a></td></tr>
{% else %}<tr><td colspan=13>Noch keine Rechnungen.</td></tr>{% endfor %}
{% if summen|length<2 %}<tr><th colspan=6 class=r>Summe ({{rows|length}})</th>
<th class=r>{{'%.2f'|format(sb)|replace('.',',')}}</th><th colspan=6></th></tr>{% endif %}</table>
{% if summen|length>1 %}<table style="margin-top:14px;max-width:560px"><tr><th>Summe je Belegart</th><th class=r>Anzahl</th>
<th class=r>Brutto</th></tr>
{% for z in summen %}<tr><td>{{z.art}}</td><td class=r>{{z.n}}</td>
<td class=r>{{'%.2f'|format(z.brutto)|replace('.',',')}}</td></tr>{% endfor %}</table>{% endif %}
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
<div><label>Zahlung (aus Kassenbuch/Kontoauszug)</label><input disabled value="{{r.zahlung or 'offen'}}{{' – '~(r.zahl_art or r.zahl_quelle)~' '~r.zahl_am if r.zahl_am else ''}}"></div>
<div><label>DATEV-Stand</label><select name=status>{% for s in STATUS %}<option {{'selected' if s==r.status}}>{{s}}</option>{% endfor %}</select></div>
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
<label>Lieferanten (eine Zeile je Lieferant: <code>Name | Alias = Kategorie ; abzug</code> &ndash; Alias = weiterer Name im PDF/auf dem Kontoauszug,
<code>abzug</code> = Zahlung darf niedriger sein als die Rechnung, z. B. GLS verrechnet Gutschriften; längere Namen zuerst, z. B. „Jura Gastro“ vor „Jura“)</label>
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


STAND = str(os.path.getmtime(__file__))


@app.route("/__stand")
def stand():
    """Versionskennung (Aenderungszeit von app.py); der Starter prueft damit, ob der laufende Server aktuell ist."""
    return STAND


@app.route("/")
def index():
    q = request.args.get("q", "").strip()
    status = request.args.get("status", "")
    zahlung = request.args.get("zahlung", "")
    zahlart = request.args.get("zahlart", "")
    monat = request.args.get("monat", "")
    belegart = request.args.get("belegart", "")
    sql, par = "SELECT * FROM rechnungen WHERE 1=1", []
    if q:
        sql += " AND (lieferant LIKE ? OR rechnungsnr LIKE ? OR notiz LIKE ?)"
        par += [f"%{q}%"] * 3
    if status:
        sql += " AND status=?"
        par.append(status)
    if zahlart:
        sql += " AND COALESCE(zahl_art,'') LIKE ?"
        par.append(f"%{zahlart}%")
    if zahlung == "unbezahlt":  # nur Rechnungen, die noch nicht (voll) bezahlt sind
        sql += " AND COALESCE(zahlung,'offen')<>'bezahlt' AND belegart IN (?,?,?,?)"
        par += list(RECHNUNGSARTEN)
    elif zahlung:
        sql += " AND COALESCE(zahlung,'offen')=? AND belegart IN (?,?,?,?)"
        par += [zahlung] + list(RECHNUNGSARTEN)
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
    summen = {}
    for r in rows:
        z = summen.setdefault(r.belegart, dict(art=r.belegart, n=0, netto=0.0, brutto=0.0))
        z["n"] += 1
        z["netto"] += r.netto
        z["brutto"] += r.brutto
    doppelte = []
    for g in db().execute("SELECT hash FROM rechnungen WHERE hash IS NOT NULL GROUP BY hash HAVING COUNT(*)>1"):
        doppelte.append(db().execute("SELECT id, rechnungsnr, lieferant, datum FROM rechnungen WHERE hash=? "
                                     "ORDER BY id", (g["hash"],)).fetchall())
    return page(INDEX, doppelte=doppelte, summen=list(summen.values()), rows=rows, q=q, status=status, zahlung=zahlung, zahlart=zahlart, ZAHLARTEN=ZAHLARTEN, STATUS=STATUS, ZAHLUNG=ZAHLUNG, RECHNUNGSARTEN=RECHNUNGSARTEN, monat=monat,
                belegart=belegart, BELEGARTEN=BELEGARTEN_ALLE, UNKLAR=UNKLAR,
                ordner=settings()["eingang_ordner"], ausg_fehlt=len(fehlende_ausgangsrechnungen()[0]),
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
    datei_name = dh = None
    up = request.files.get("datei")
    if up and up.filename:
        ext = Path(up.filename).suffix.lower()
        if ext not in ERLAUBT:
            flash("Dateityp nicht erlaubt (PDF, JPG, PNG, TIF).")
            return None
        daten = up.read()
        dh = hashlib.sha1(daten).hexdigest()
        dup = db().execute("SELECT rechnungsnr, lieferant, datum FROM rechnungen WHERE hash=? AND id<>?",
                           (dh, rid or -1)).fetchone()
        if dup:
            flash(f"Diese Datei ist bereits abgelegt ({dup['rechnungsnr'] or dup['lieferant']} vom {dup['datum']}) "
                  "- nicht doppelt gespeichert.")
            return None
        datei_name = f"{uuid.uuid4().hex}{ext}"
        (BELEGE / datei_name).write_bytes(daten)
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
    ziel_id = rid if rid is not None else db().execute("SELECT MAX(id) FROM rechnungen").fetchone()[0]
    if dh:
        db().execute("UPDATE rechnungen SET hash=? WHERE id=?", (dh, ziel_id))
    db().commit()
    return True


@app.route("/neu", methods=["GET", "POST"])
def neu():
    if request.method == "POST" and _speichern():
        flash("Rechnung gespeichert.")
        return redirect(url_for("index"))
    r = type("R", (), dict(id=None, datum=date.today().isoformat(), lieferant="", rechnungsnr="",
                           brutto=0, mwst_satz=19, kategorie="Sonstiges", konto="",
                           status=STATUS[0], zahlung="offen", notiz="", datei=None, belegart=EINGANG))
    return page(FORM, r=r, KAT=KATEGORIEN, STATUS=STATUS, ZAHLUNG=ZAHLUNG, BELEGARTEN=BELEGARTEN_ALLE,
                LIEFERANTEN=lieferanten_liste(settings()))


@app.route("/<int:rid>/bearbeiten", methods=["GET", "POST"])
def bearbeiten(rid):
    r = lade(rid)
    if request.method == "POST" and _speichern(rid):
        flash("Änderungen gespeichert.")
        return redirect(url_for("index"))
    return page(FORM, r=type("R", (), dict(r)), KAT=KATEGORIEN, STATUS=STATUS, ZAHLUNG=ZAHLUNG, BELEGARTEN=BELEGARTEN_ALLE,
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


BETRAG_RE = re.compile(r"(?<![\d.,])(\d{1,3}(?:[. \u00a0\u202f]\d{3})+,\d{2}|\d+,\d{2})(?!\d)")
BRUTTO_KW = re.compile(r"gesamtbetrag|rechnungsbetrag|endbetrag|zu zahlen|zahlbetrag|gesamtsumme|"
                       r"summe brutto|brutto|total|gesamt|summe|betrag", re.I)
INKL_RE = re.compile(r"inkl\.?\s*(?:mwst|ust|mehrwertsteuer|umsatzsteuer)|incl\.?\s*(?:mwst|ust)|"
                     r"gesamt\w*\s*brutto|brutto\s*gesamt", re.I)
NETTO_RE = re.compile(r"netto|ohne\s*(?:mwst|ust|mehrwertsteuer)|zwischensumme", re.I)


def _zahl(t):
    return float(re.sub(r"[. \u00a0\u202f]", "", t).replace(",", "."))


def _betraege(zeilen, i):
    """Betraege der Zeile i; steht keiner dort, der erste der Folgezeile."""
    gef = [_zahl(x) for x in BETRAG_RE.findall(zeilen[i])]
    if not gef and i + 1 < len(zeilen):
        gef = [_zahl(x) for x in BETRAG_RE.findall(zeilen[i + 1])][:1]
    return gef


BETRAG_STRIKT_RE = re.compile(r"(?<![\d.,])(\d{1,3}(?:\.\d{3})+,\d{2}|\d+,\d{2})(?!\d)")


def _tabellenbetrag(zeilen):
    """Tabelle mit Spaltenueberschriften ('... Netto ... USt.-Betrag ... Rg.-Betrag EUR'): der groesste Betrag der
    Wertezeile darunter ist das Brutto. Strikter Betragsmuster (kein Leerzeichen als Tausenderpunkt), damit der
    Steuersatz-Wert ('19 378,88') nicht mit dem Betrag verschmilzt."""
    for i, z in enumerate(zeilen[:-1]):
        zl = z.lower()
        if "netto" in zl and re.search(r"betrag|brutto|gesamt|summe", zl):
            for k in range(i + 1, min(i + 5, len(zeilen))):
                gef = [_zahl(x) for x in BETRAG_STRIKT_RE.findall(zeilen[k])]
                if len(gef) >= 2:
                    return max(gef)
    return None


def finde_betrag(text):
    """Liest Brutto und MwSt-Satz aus Rechnungstext. Gibt (brutto, satz) oder (None, None) zurueck.
    Bei Gutschriften ist der Betrag negativ."""
    for m in re.finditer(r"Zubezahlen\s*\n\s*Endbetrag\s*\n(.{0,400})", text, re.S):  # REPA-Layout: Werte unter den Beschriftungen (Seite 1 'Segue' leer)
        zahlen = re.findall(r"\d[\d.]*,\d{2}", m.group(1))
        if len(zahlen) >= 3:  # Imponibile, Importo da pagare (nach Skonto), Totale Documento
            return _betrag_de(zahlen[-1]), 0.0 if re.search(r"steuerfrei", text, re.I) else 19.0
    m = re.search(r"Endbetrag\s*\n((?:\s*-?\d[\d.]*,\d{2}\s*\n){2,})\s*EUR\b", text)  # Spalten-Layout: ... Summe, MwSt, Endbetrag, EUR
    if m:
        zahlen = re.findall(r"-?\d[\d.]*,\d{2}", m.group(1))
        b = _betrag_de(zahlen[-1])
        if b:
            return b, 19.0
    m = re.search(r"Gesamtrechnungsbetrag.{0,200}?(\d[\d.]*,\d{2})\s*\n\s*(\d[\d.]*,\d{2})\s*\n", text, re.S)  # Nexi: ..., MwSt, Gesamtrechnungsbetrag
    if m:
        return _betrag_de(m.group(2)), 19.0
    zeilen = text.splitlines()
    inkl, kandidaten, netto = [], [], []
    for i, z in enumerate(zeilen):
        zl = z.lower()
        if NETTO_RE.search(z):
            netto += _betraege(zeilen, i)
        if INKL_RE.search(z):
            inkl += _betraege(zeilen, i)
            continue
        if "brutto" in zl and "netto" in zl:  # beides in einer Zeile: nur Betraege hinter "brutto"
            z = z[zl.index("brutto"):]
            zl = zl[zl.index("brutto"):]
            zeilen = zeilen[:i] + [z] + zeilen[i + 1:]
        if BRUTTO_KW.search(z) and not re.search(r"zwischensumme|netto|mwst|ust|steuer|skonto|ohne", zl):
            kandidaten += _betraege(zeilen, i)
    if inkl:
        brutto = max(inkl)
    elif kandidaten:
        brutto = max(kandidaten)
    else:
        brutto = _tabellenbetrag(zeilen)
        if brutto is None:
            return None, None
    satz = None
    for n in sorted(set(netto), reverse=True):
        if 0 < n < brutto:
            q = (brutto / n - 1) * 100
            for cand in (19, 7):
                if abs(q - cand) < 0.6:
                    satz = cand
                    break
            if satz is not None:
                break
    if satz is None:
        saetze = {int(x) for x in re.findall(r"(\d{1,2})(?:,0+)?\s*%", text) if x in ("19", "7")}
        satz = 19 if 19 in saetze or not saetze else 7
    if re.search(r"gutschrift", text[:400], re.I):
        brutto = -brutto
    return brutto, float(satz)


def _lokal(tag):
    return tag.rsplit("}", 1)[-1]


def _suche(el, *pfad):
    """Erstes Element, das ueber die lokalen Tag-Namen (je Schritt beliebig tief) erreichbar ist."""
    cur = [el]
    for name in pfad:
        nxt = []
        for c in cur:
            nxt += [x for x in c.iter() if x is not c and _lokal(x.tag) == name]
        cur = nxt
        if not cur:
            return None
    return cur[0]


def _txt(el, *pfad):
    x = _suche(el, *pfad) if el is not None else None
    return (x.text or "").strip() if x is not None else ""


def _num(t):
    try:
        return float(t)
    except (TypeError, ValueError):
        return None


def pdf_xml(pfad):
    """Eingebettete XML-Datei (ZUGFeRD/Factur-X/XRechnung) einer PDF oder None."""
    try:
        for name, daten in PdfReader(str(pfad)).attachments.items():
            if name.lower().endswith(".xml") and daten:
                return daten[0]
    except Exception:  # noqa: BLE001
        pass
    return None


def lese_erechnung(pfad):
    """Liest Nummer, Datum, Betraege usw. aus der eingebetteten XML einer E-Rechnung (CII oder UBL)."""
    if pfad.suffix.lower() != ".pdf":
        return None
    roh = pdf_xml(pfad)
    if not roh:
        return None
    try:
        root = ET.fromstring(roh)
    except ET.ParseError:
        return None
    wurzel = _lokal(root.tag)
    if wurzel == "CrossIndustryInvoice":
        nr = _txt(root, "ExchangedDocument", "ID")
        typ = _txt(root, "ExchangedDocument", "TypeCode")
        d = _txt(root, "ExchangedDocument", "IssueDateTime", "DateTimeString")
        datum = f"{d[:4]}-{d[4:6]}-{d[6:8]}" if re.fullmatch(r"\d{8}", d) else ""
        summ = _suche(root, "SpecifiedTradeSettlementHeaderMonetarySummation")
        brutto = _num(_txt(summ, "GrandTotalAmount"))
        netto = _num(_txt(summ, "TaxBasisTotalAmount"))
        satz, best = None, -1.0
        for t in root.iter():
            if _lokal(t.tag) == "ApplicableTradeTax":
                b, pz = _num(_txt(t, "BasisAmount")), _num(_txt(t, "RateApplicablePercent"))
                if b is not None and pz is not None and b > best:
                    satz, best = pz, b
        if satz is None:
            satz = _num(_txt(root, "RateApplicablePercent"))
        verk = _txt(root, "SellerTradeParty", "Name")
        kauf = _txt(root, "BuyerTradeParty", "Name")
    elif wurzel in ("Invoice", "CreditNote"):
        nr = _txt(root, "ID")
        typ = _txt(root, "InvoiceTypeCode") or ("381" if wurzel == "CreditNote" else "380")
        datum = _txt(root, "IssueDate")
        brutto = _num(_txt(root, "LegalMonetaryTotal", "TaxInclusiveAmount"))
        netto = _num(_txt(root, "LegalMonetaryTotal", "TaxExclusiveAmount"))
        satz = _num(_txt(root, "TaxSubtotal", "TaxCategory", "Percent"))
        verk = _txt(root, "AccountingSupplierParty", "RegistrationName") or _txt(root, "AccountingSupplierParty", "Name")
        kauf = _txt(root, "AccountingCustomerParty", "RegistrationName") or _txt(root, "AccountingCustomerParty", "Name")
    else:
        return None
    m = re.fullmatch(r"(\d{7})\s*/\s*\d+", nr)  # Kasse schreibt '2610205 / 1'
    if m:
        nr = m.group(1)
    if brutto is not None and typ in ("381", "396"):
        brutto = -abs(brutto)
    if satz is not None:
        satz = float(round(satz))
    return dict(nr=nr, datum=datum, brutto=brutto, netto=netto, satz=satz if satz is not None else 19.0,
                verkaeufer=verk, kaeufer=kauf, typ=typ)


def _lief_zeilen(cfg):
    """Zeilenformat der Lieferantenliste: 'Name [| Alias ...] [= Kategorie] [; abzug]'.
    Aliase helfen beim Finden im PDF-Text; 'abzug' = die Zahlung darf niedriger sein als die Rechnung."""
    out = []
    for z in (cfg.get("lieferanten") or "").splitlines():
        kopf, _, opt = z.partition(";")
        namen, _, kat = kopf.partition("=")
        teile = [t.strip() for t in namen.split("|") if t.strip()]
        if teile:
            out.append(dict(name=teile[0], suche=teile, kategorie=kat.strip(), abzug="abzug" in opt.lower()))
    return out


def lieferanten_liste(cfg):
    return [l["name"] for l in _lief_zeilen(cfg)]


def lieferanten_suchliste(cfg):
    return [(l["name"], l["suche"]) for l in _lief_zeilen(cfg)]


def lieferanten_abzug(cfg):
    return {l["name"] for l in _lief_zeilen(cfg) if l["abzug"]}


def lieferant_aliase(cfg):
    return {l["name"]: l["suche"] for l in _lief_zeilen(cfg)}


def lieferant_kategorie(cfg, name):
    for l in _lief_zeilen(cfg):
        if l["name"] == name and l["kategorie"] in KATEGORIEN:
            return l["kategorie"]
    return "Sonstiges"


def finde_lieferant(text, dateiname, liste):
    """liste: Namen oder (Name, [Suchbegriffe]) - gibt den Namen des ersten Lieferanten zurueck, dessen Begriff im Text steht."""
    heu = text + "\n" + dateiname
    eintraege = [(x, [x]) if isinstance(x, str) else x for x in liste]
    for name, begriffe in eintraege:
        for bg in begriffe:
            if re.search(r"(?<!\w)" + re.escape(bg) + r"(?!\w)", heu, re.I):
                return name
    # zweiter Durchgang ohne Rechtsform ('büroshop24 GmbH' findet auch 'büroshop24')
    for name, begriffe in eintraege:
        for bg in begriffe:
            kurz = re.sub(r"[\s,]+(gmbh\s*&\s*co\.?\s*(?:kg|ohg)|gmbh|ag|kg|ohg|gbr|ug|mbh|e\.?\s?k\.?|se)\.?$", "", bg,
                          flags=re.I)
            if kurz != bg and len(kurz) >= 4 and re.search(r"(?<!\w)" + re.escape(kurz) + r"(?!\w)", heu, re.I):
                return name
    return ""


_OCR = {}


def _ocr_engine():
    """RapidOCR (pip install rapidocr onnxruntime pymupdf) - laedt erst beim ersten Scan; fehlt es, bleibt Scan-Text leer."""
    if "e" not in _OCR:
        try:
            from rapidocr import RapidOCR
            _OCR["e"] = RapidOCR()
        except Exception as e:  # noqa: BLE001
            print("OCR nicht verfuegbar:", e)
            _OCR["e"] = None
    return _OCR["e"]


def ocr_text(pfad, max_seiten=3):
    """Text aus einem gescannten PDF / Bild per OCR. Ergebnis wird in data/ocr zwischengespeichert."""
    pfad = Path(pfad)
    try:
        roh = pfad.read_bytes()
    except OSError:
        return ""
    cache = DATA / "ocr" / f"{hashlib.sha1(roh).hexdigest()}_{max_seiten}.txt"
    if cache.exists():
        return cache.read_text(encoding="utf-8")
    eng = _ocr_engine()
    if eng is None:
        return ""
    try:
        import pymupdf
        seiten = []
        if pfad.suffix.lower() == ".pdf":
            doc = pymupdf.open(stream=roh, filetype="pdf")
            seiten = [pg.get_pixmap(dpi=200).tobytes("png") for pg in list(doc)[:max_seiten]]
        else:
            seiten = [roh]
        teile = []
        for png in seiten:
            res = eng(png)
            teile.append("\n".join(res.txts) if res is not None and res.txts else "")
        text = "\n".join(teile)
    except Exception as e:  # noqa: BLE001
        print("OCR-Fehler:", pfad.name, e)
        return ""
    cache.parent.mkdir(exist_ok=True)
    cache.write_text(text, encoding="utf-8")
    return text


def pdf_text(pfad, max_seiten=3):
    text = ""
    if Path(pfad).suffix.lower() == ".pdf":
        try:
            r = PdfReader(str(pfad))
            text = "\n".join((pg.extract_text() or "") for pg in r.pages[:max_seiten])
        except Exception:  # noqa: BLE001
            text = ""
    if len(re.sub(r"\s", "", text)) < 40:  # Scan ohne Textebene (oder Bild): OCR
        text = ocr_text(pfad, max_seiten or 50) or text
    return text


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


_DAT = r"(\d{1,2})\.(\d{1,2})\.(\d{4})"
_RE_DATUM_LABEL = (r"(?:Rechnungs-?\s?datum|Rechnung(?:s)?\s+vom|Belegdatum|Beleg-Datum|Rechnungsdatum|Invoice\s+date|"
                   r"Datum\s+der\s+Rechnung|Ausstellungsdatum|Re\.?-?\s?Datum|Datum)")


def _iso_datum(t, m_, j):
    try:
        d = date(int(j), int(m_), int(t))
        return d.isoformat() if 2000 <= d.year <= 2100 else None
    except ValueError:
        return None


def finde_rechnungsdatum(text):
    """Nur ein ausdruecklich beschriftetes Rechnungsdatum (Rechnungsdatum, Belegdatum, 'Rechnung vom', 'vom 30/09/26'), sonst ''."""
    m = re.search(r"(?:RECHNUNG|FATTURA)[^\n]{0,30}?vom\s+(\d{1,2})/(\d{1,2})/(\d{2,4})", text, re.I)  # '... nr. 5963 vom 30/09/26'
    if m:
        j = int(m.group(3)) + (2000 if len(m.group(3)) == 2 else 0)
        d = _iso_datum(m.group(1), m.group(2), j)
        if d:
            return d
    for m in re.finditer(r"(?<![\w-])" + _RE_DATUM_LABEL + r"\s*:?\s*(?:\n\s*)?" + _DAT + r"\b", text, re.I):
        d = _iso_datum(m.group(1), m.group(2), m.group(3))
        if d:
            return d
    return ""


def finde_datum(text, fallback):
    """Rechnungsdatum: zuerst Angaben mit Beschriftung, dann das erste Datum im Text, sonst fallback."""
    d = finde_rechnungsdatum(text)
    if d:
        return d
    for t, m_, j in re.findall(r"\b" + _DAT + r"\b", text):
        d = _iso_datum(t, m_, j)
        if d:
            return d
    return fallback


def finde_nummer(text):
    for m in re.finditer(r"(?:Rechnungs?-?\s?(?:nummer|nr\.?)|Beleg-?\s?Nr\.?)\s*:?\s*([A-Za-z0-9][A-Za-z0-9\-/]*)",
                         text, re.I):
        if re.search(r"\d", m.group(1)):  # 'Kunden-Nr' o. ae. ist keine Nummer
            return m.group(1)
    # Tabellenlayout: Spaltenueberschriften ('Rechnungs-Nr. Kunden-Nr. Datum ...'), Werte in den Zeilen darunter
    zeilen = text.splitlines()
    for i, z in enumerate(zeilen[:-1]):
        if re.search(r"Rechnungs?-?\s?(?:nummer|nr)", z, re.I) and len(re.findall(r"nr\.?|nummer|datum", z, re.I)) >= 2:
            for k in range(i + 1, min(i + 4, len(zeilen))):
                for tok in zeilen[k].split():
                    if re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9\-/]{3,}", tok) and re.search(r"\d", tok):
                        return tok
    m = re.search(r"(?:Offene Rechnung|Vorkasse|Nachnahme)\s+(\d{6,10})\b", text)  # Spalten-Layout: Verrechnungsart + Rechnungs-Nr.
    if m:
        return m.group(1)
    m = re.search(r"\bRg\.?\s*(?:-?Nr\.?)?\s*(\d{5,})", text)  # z. B. Verwendungszweck 'Rg. 152545060'
    if m:
        return m.group(1)
    g = re.search(r"Gutschrift\s*(?:Nr\.?)?\s*:?\s*([A-Za-z0-9][A-Za-z0-9\-/]*)", text[:400], re.I)
    return g.group(1) if g else ""


def bank_doppelt(c, b, dokument):
    """Gleiche Buchung (Betrag, Name, Verwendungszweck) mit bis zu 3 Tagen Abstand aus einer ANDEREN Datei = dieselbe Buchung
    (vorgemerkt, spaeter mit neuem Datum gebucht)."""
    try:
        d = date.fromisoformat(b["datum"])
    except ValueError:
        return False
    return bool(c.execute("SELECT 1 FROM bank WHERE betrag=? AND name=? AND zweck=? AND dokument<>? AND datum BETWEEN ? AND ?",
                          (b["betrag"], b["name"], b["zweck"], dokument,
                           (d - timedelta(days=3)).isoformat(), (d + timedelta(days=3)).isoformat())).fetchone())


def _kontoauszug_importieren(c, f, fertig):
    """Liest eine Kontoauszugsdatei aus dem Eingangsordner in die Tabelle bank. True, wenn es einer war."""
    try:
        daten = f.read_bytes()
        buchungen = parse_kontoauszug(daten, f.name)
    except Exception:  # noqa: BLE001
        return False
    if not buchungen:
        return False
    for b in buchungen:
        if bank_doppelt(c, b, f.name):
            continue
        key = hashlib.sha1(f"{b['datum']}|{b['betrag']:.2f}|{b['name']}|{b['zweck']}".encode()).hexdigest()
        c.execute("INSERT OR IGNORE INTO bank(datum,betrag,name,zweck,dokument,schluessel) VALUES(?,?,?,?,?,?)",
                  (b["datum"], b["betrag"], b["name"], b["zweck"], f.name, key))
    c.commit()
    (DATA / "kontoauszuege").mkdir(exist_ok=True)
    (DATA / "kontoauszuege" / f"{datetime.now():%Y%m%d-%H%M%S}_{secure_filename(f.name)}").write_bytes(daten)
    shutil.move(str(f), str(fertig / f"{int(time.time())}_{f.name}"))
    return True


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
        if f.is_file() and f.suffix.lower() in (".csv", ".xml", ".camt"):
            # Kontoauszug (CSV-CAMT / CAMT.053): einlesen; andere CSV/XML-Dateien bleiben unberuehrt liegen
            if time.time() - f.stat().st_mtime >= 3 and _kontoauszug_importieren(c, f, fertig):
                n += 1
            continue
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
        text = pdf_text(f)
        ex = lese_erechnung(f)
        if ex and ex["nr"] and ex["brutto"] is not None and c.execute(
                "SELECT 1 FROM rechnungen WHERE rechnungsnr=? AND ABS(brutto-?)<0.005 AND belegart=?",
                (ex["nr"], ex["brutto"], EINGANG)).fetchone():  # E-Rechnung schon vorhanden (anderes PDF, gleiche Nummer)
            shutil.move(str(f), str(fertig / f"doppelt_{int(time.time())}_{f.name}"))
            continue
        art = klassifiziere(text + ("\n" + ex["nr"] if ex else ""), f.stem, regeln)
        lief = ""
        if art in (UNKLAR, EINGANG):
            lief = finde_lieferant(text + ("\n" + ex["verkaeufer"] if ex else ""), f.stem, lieferanten_suchliste(cfg))
            if lief:
                art = EINGANG
        mtime = date.fromtimestamp(f.stat().st_mtime).isoformat()
        datum = finde_datum(text, mtime)
        if art == "Rechnungsausgangliste" and parse_zeitraum(text):
            datum = parse_zeitraum(text)[1]
        brutto, satz, hinweis = 0, 0, ""
        kat = lieferant_kategorie(cfg, lief) if lief else "Sonstiges"
        if art == EINGANG:
            b, sz = finde_betrag(text)
            if b:
                brutto, satz, hinweis = b, sz, " | Betrag automatisch gelesen - bitte pruefen"
        elif art in AUSGANG_RECHNUNGEN:
            b = finde_endsumme(text)
            if b is not None:
                brutto, satz = b, finde_ausgang_satz(text)
        anzeige = lief or art
        nr_beleg = finde_nummer(text)
        if ex:  # E-Rechnung: strukturierte Daten sind verlaesslicher als der Text
            nr_beleg = ex["nr"] or nr_beleg
            datum = ex["datum"] or datum
            if art in (EINGANG,) + AUSGANG_RECHNUNGEN and ex["brutto"] is not None:
                brutto, satz = ex["brutto"], ex["satz"]
                hinweis = " | E-Rechnung (XML) gelesen" if art == EINGANG else ""
            if art in AUSGANG_RECHNUNGEN and ex["kaeufer"]:
                anzeige = ex["kaeufer"]
            elif art == EINGANG and not lief and ex["verkaeufer"]:
                anzeige = ex["verkaeufer"]
        name = f"{uuid.uuid4().hex}{f.suffix.lower()}"
        (BELEGE / name).write_bytes(daten)
        c.execute("INSERT INTO rechnungen(datum,lieferant,rechnungsnr,brutto,mwst_satz,kategorie,konto,status,"
                  "notiz,datei,guid,angelegt,belegart,hash) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                  (datum, anzeige, nr_beleg, brutto, satz, kat, KATEGORIEN[kat] if art == EINGANG else "",
                   "noch nicht gesendet", f.name + hinweis, name,
                   str(uuid.uuid4()), datetime.now().isoformat(timespec="seconds"), art, h))
        c.commit()
        if ziel_alt.exists():
            ziel_alt = fertig / f"{int(time.time())}_{f.name}"
        shutil.move(str(f), str(ziel_alt))
        n += 1
    c.close()
    return n


def backup_nach_z():
    """Sicherung auf das Netzlaufwerk: konsistente DB-Kopie (taeglich datiert, 14 Tage) + neue Belege/Kontoauszuege/OCR."""
    ziel = Path(BACKUP_ORDNER)
    try:
        ziel.mkdir(parents=True, exist_ok=True)
        heute = ziel / f"rechnungen-{date.today():%Y%m%d}.db"
        src = sqlite3.connect(DB)
        dst = sqlite3.connect(heute)
        src.backup(dst)
        dst.close()
        src.close()
        for alt in sorted(ziel.glob("rechnungen-*.db"))[:-14]:
            alt.unlink()
        for ordner in ("belege", "kontoauszuege", "monatspakete", "ocr"):
            quelle = DATA / ordner
            if not quelle.is_dir():
                continue
            for f in quelle.rglob("*"):
                if f.is_file():
                    z = ziel / ordner / f.relative_to(quelle)
                    if not z.exists() or z.stat().st_size != f.stat().st_size:
                        z.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(f, z)
        (ziel / "letzte-sicherung.txt").write_text(datetime.now().isoformat(timespec="seconds"), encoding="utf-8")
        return True
    except Exception as e:  # noqa: BLE001
        print("Sicherung:", e)
        return False


def _waechter():
    letzte_sicherung = 0
    while True:
        try:
            eingang_einlesen()
        except Exception as e:  # noqa: BLE001
            print("Eingang:", e)
        if time.time() - letzte_sicherung > 3600:  # beim Start und danach stuendlich
            backup_nach_z()
            letzte_sicherung = time.time()
        time.sleep(10)


@app.route("/eingang/neu-pruefen", methods=["POST"])
def neu_pruefen():
    """Wendet Regeln, Lieferantenliste und Betragserkennung erneut auf noch unfertige Belege an."""
    cfg = settings()
    regeln = regeln_parsen(cfg["regeln"])
    liste = lieferanten_suchliste(cfg)
    n = 0
    for r in db().execute("SELECT * FROM rechnungen WHERE datei IS NOT NULL AND "
                          "(belegart=? OR (belegart=? AND (brutto=0 OR konto='' OR konto IS NULL)) OR "
                          "(belegart IN (?,?,?) AND (brutto=0 OR lieferant=belegart)))",
                          (UNKLAR, EINGANG) + AUSGANG_RECHNUNGEN).fetchall():
        pfad = BELEGE / r["datei"]
        if not pfad.exists():
            continue
        text = pdf_text(pfad)
        ex = lese_erechnung(pfad)
        art = r["belegart"]
        lief = r["lieferant"]
        if art == UNKLAR:
            art = klassifiziere(text + ("\n" + ex["nr"] if ex else ""), Path(r["notiz"] or "").stem, regeln)
            if art in (UNKLAR, EINGANG):
                lief = finde_lieferant(text + ("\n" + ex["verkaeufer"] if ex else ""),
                                       Path(r["notiz"] or "").stem, liste)
                if lief:
                    art = EINGANG
            lief = lief or art
        brutto, satz, notiz = r["brutto"], r["mwst_satz"], r["notiz"] or ""
        if art == EINGANG and not brutto:
            b, sz = finde_betrag(text)
            if b:
                brutto, satz = b, sz
                notiz += " | Betrag automatisch gelesen - bitte pruefen"
        if art in AUSGANG_RECHNUNGEN and not brutto:
            b = finde_endsumme(text)
            if b is not None:
                brutto, satz = b, finde_ausgang_satz(text)
        alt_nr = r["rechnungsnr"] if re.search(r"\d", r["rechnungsnr"] or "") else ""
        nr = alt_nr or (ex["nr"] if ex and ex["nr"] else finde_nummer(text))
        if ex:
            if art in (EINGANG,) + AUSGANG_RECHNUNGEN and not r["brutto"] and ex["brutto"] is not None:
                brutto, satz = ex["brutto"], ex["satz"]
                if art == EINGANG:
                    notiz = notiz.replace(" | Betrag automatisch gelesen - bitte pruefen", "")
                    notiz += " | E-Rechnung (XML) gelesen"
            if art in AUSGANG_RECHNUNGEN and ex["kaeufer"] and lief in (r["belegart"], art, UNKLAR, ""):
                lief = ex["kaeufer"]
            elif art == EINGANG and lief in (UNKLAR, "") and ex["verkaeufer"]:
                lief = ex["verkaeufer"]
        kat, konto = r["kategorie"], r["konto"] or ""
        if art == EINGANG:
            if kat == "Sonstiges":
                kat = lieferant_kategorie(cfg, lief)
            konto = konto or KATEGORIEN[kat]
        if (art, lief, brutto, nr, kat, konto) != (r["belegart"], r["lieferant"], r["brutto"],
                                                   r["rechnungsnr"], r["kategorie"], r["konto"] or ""):
            db().execute("UPDATE rechnungen SET belegart=?, lieferant=?, brutto=?, mwst_satz=?, notiz=?, "
                         "rechnungsnr=?, kategorie=?, konto=? WHERE id=?",
                         (art, lief, brutto, satz, notiz, nr, kat, konto, r["id"]))
            n += 1
    db().commit()
    flash(f"{n} Belege neu zugeordnet bzw. mit Betrag versehen." if n else "Nichts zu aktualisieren.")
    return redirect(url_for("index"))


@app.route("/eingang/jetzt", methods=["POST"])
def eingang_jetzt():
    n = eingang_einlesen()
    flash(f"{n} neue Dateien eingelesen." if n else "Keine neuen Dateien im Eingangsordner.")
    return redirect(url_for("index"))


# ---------------------------------------------------------------- Abgleich Rechnungsausgangsliste
NUMMERNKREISE = ("261", "263")
LISTE_RE = re.compile(r"^(\d+)\n((?:[^\n]*\n){1,3}?)(\d{7})\n(\d{2}\.\d{2}\.\d{4})\n(-?\d+\.\d{2})\n(-?\d+\.\d{2})$",
                      re.M)


def kasse_zahl(t):
    """Kassenformat '2.499.00' / '1298.90' (Punkt auch als Tausender) -> float."""
    neg = t.strip().startswith("-")
    ziffern = re.sub(r"\D", "", t)
    return (-1 if neg else 1) * int(ziffern) / 100


def finde_endsumme(text):
    m = re.search(r"Endsumme:?\s*(-?[\d.]+)\s*€", text)
    if m:
        return kasse_zahl(m.group(1))
    b, _ = finde_betrag(text)
    return b


def finde_ausgang_satz(text):
    """MwSt-Satz aus Kassenrechnung ('MwSt.: 19% = 399.00 EUR, Netto ...'); sonst 19."""
    m = re.search(r"MwSt\.?:?\s*(\d{1,2})\s*%", text)
    return float(m.group(1)) if m and m.group(1) in ("19", "7", "0") else 19.0


def parse_ausgangsliste(text):
    out = []
    for kd, name, nr, dat, offen, betrag in LISTE_RE.findall(text):
        t, m_, j = dat.split(".")
        out.append(dict(kd=kd, name=" ".join(name.split()), nr=nr, datum=f"{j}-{m_}-{t}",
                        offen=float(offen), betrag=float(betrag)))
    return out


def nummern_bereiche(nummern):
    """[2610199, 2610200, 2610202] -> '2610199–2610200, 2610202'"""
    nummern = sorted(int(n) for n in nummern)
    teile, start, prev = [], None, None
    for n in nummern + [None]:
        if start is None:
            start = prev = n
        elif n is not None and n == prev + 1:
            prev = n
        else:
            teile.append(str(start) if start == prev else f"{start}\u2013{prev}")
            start = prev = n
    return ", ".join(teile)


def parse_zeitraum(text):
    """'vom: 01.10.2026 bis: 31.10.2026' -> ('2026-10-01', '2026-10-31') oder None."""
    m = re.search(r"vom:?\s*(\d{2})\.(\d{2})\.(\d{4})\s*bis:?\s*(\d{2})\.(\d{2})\.(\d{4})", text, re.I)
    if not m:
        return None
    t1, m1, j1, t2, m2, j2 = m.groups()
    return f"{j1}-{m1}-{t1}", f"{j2}-{m2}-{t2}"


def listen_laden():
    """Alle abgelegten Rechnungsausgangslisten, aelteste zuerst (nach Zeitraum-Ende)."""
    out = []
    for l in db().execute("SELECT id, datum, notiz, datei FROM rechnungen WHERE belegart='Rechnungsausgangliste' "
                          "AND datei IS NOT NULL ORDER BY id"):
        pfad = BELEGE / l["datei"]
        if not (pfad.exists() and pfad.suffix.lower() == ".pdf"):
            continue
        text = pdf_text(pfad, max_seiten=None)
        von, bis = parse_zeitraum(text) or (l["datum"], l["datum"])
        eint = {e["nr"]: e for e in parse_ausgangsliste(text)}
        t1, m1, j1 = von[8:], von[5:7], von[:4]
        t2, m2, j2 = bis[8:], bis[5:7], bis[:4]
        out.append(dict(id=l["id"], notiz=l["notiz"], von=von, bis=bis, eintraege=eint,
                        label=f"{t1}.{m1}. \u2013 {t2}.{m2}.{j2}  ({len(eint)} Rechnungen, {l['notiz']})"))
    out.sort(key=lambda x: (x["bis"], x["id"]))
    return out


def liste_waehlen(listen, param):
    """param: 'alle' | Listen-ID | leer/'neueste'. Gibt (Eintraege-Dict, gewaehlte Listen) zurueck."""
    if param == "alle":
        auswahl = listen
    elif param and param != "neueste":
        auswahl = [l for l in listen if str(l["id"]) == param]
    else:
        auswahl = listen[-1:]
    eintraege = {}
    for l in auswahl:
        eintraege.update(l["eintraege"])
    return eintraege, auswahl


def quittiert_laden():
    """{Rechnungsnummer: {bem, am}} - im Abgleich per 'OK geben' bestaetigte Abweichungen."""
    return {r["rechnungsnr"]: dict(bem=r["bemerkung"] or "", am=r["am"])
            for r in db().execute("SELECT rechnungsnr, bemerkung, am FROM quittiert")}


def fehlende_ausgangsrechnungen(param=None):
    """Eintraege der gewaehlten Liste (Standard: neueste) mit Nummernkreis 261/263, zu denen keine PDF vorliegt."""
    listen = listen_laden()
    zahlungen_synchronisieren()  # Zahlstatus (Kassenbuch/Kontoauszug) bei der Gelegenheit aktuell halten
    eintraege, _ = liste_waehlen(listen, param)
    vorhanden = {r[0] for r in db().execute("SELECT rechnungsnr FROM rechnungen WHERE datei IS NOT NULL "
                                            "AND rechnungsnr<>'' AND belegart<>'Rechnungsausgangliste'")}
    quitt = quittiert_laden()
    return [e for nr, e in sorted(eintraege.items())
            if nr.startswith(NUMMERNKREISE) and nr not in vorhanden and nr not in quitt], len(eintraege)


@app.route("/abgleich/fehlt.csv")
def fehlt_csv():
    fehlt, _ = fehlende_ausgangsrechnungen(request.args.get("liste"))
    out = io.StringIO()
    w = csv.writer(out, delimiter=";", lineterminator="\r\n")
    w.writerow(["Rg.-Nr.", "Rg.-Datum", "Kd.-Nr.", "Kunde", "Betrag", "Nummernkreis"])
    for e in fehlt:
        w.writerow([e["nr"], e["datum"], e["kd"], e["name"], f"{e['betrag']:.2f}".replace(".", ","), e["nr"][:3]])
    return send_file(io.BytesIO(("\ufeff" + out.getvalue()).encode("utf-8")), mimetype="text/csv",
                     as_attachment=True, download_name=f"Fehlende_Ausgangsrechnungen_{date.today():%Y%m%d}.csv")


ABGLEICH = """
<form method=get class=card style="display:flex;gap:12px;align-items:end;flex-wrap:wrap">
 <div><label>Rechnungsausgangsliste</label><select name=liste>
  <option value="neueste" {{'selected' if liste=='neueste'}}>neueste Liste (Standard)</option>
  {% for l in listen|reverse %}<option value="{{l.id}}" {{'selected' if liste==l.id|string}}>{{l.label}}</option>{% endfor %}
  <option value="alle" {{'selected' if liste=='alle'}}>alle Listen zusammen</option></select></div>
 <label style="display:flex;gap:6px;align-items:center;margin:0 0 8px"><input type=checkbox name=alle value=1 {{'checked' if alle}}> alle Zeilen zeigen</label>
 <button>Abgleichen</button></form>
{% if not eintraege %}<div class=card>Keine Rechnungsausgangsliste gefunden oder nicht lesbar. Lege sie unter
 <a href="{{url_for('monat')}}">Monatsunterlagen</a> ab bzw. in den Eingangsordner.</div>{% else %}
<div class=card><h2>Fehlt noch</h2>
<p style="margin:0 0 8px"><small>Abgleich gegen: <b>{{gewaehlt_label}}</b> &middot; „Bezahlt“ kommt nur aus
 Kassenbuch und Kontoauszug (<a href="{{url_for('zahlungen_seite')}}">Zahlungen</a>), nicht aus der Liste.</small></p>
{% if fehlt_gesamt %}
{% for k in kreise if k.fehlt %}<p style="margin:6px 0"><b>{{k.kreis}}xxxx {{k.name}}:</b> {{k.fehlt}} von {{k.n}} Rechnungen fehlen
 ({{'%.2f'|format(k.fehlt_summe)|replace('.',',')}} &euro;)<br><span style="font-family:monospace">{{k.fehlt_bereiche}}</span></p>{% endfor %}
<p><a class=btn href="{{url_for('fehlt_csv',liste=liste)}}">Fehlende als CSV (zum Nachdrucken)</a></p>
{% else %}<p style="color:#047857;font-weight:700">&#10003; Alle Rechnungen der Liste sind vorhanden.</p>{% endif %}</div>
{% if verlauf|length>1 %}<div class=card><h2>Verlauf je Liste</h2>
<table><tr><th>Liste</th><th class=r>Rechnungen</th><th class=r>davon fehlen</th><th></th></tr>
{% for v in verlauf %}<tr><td>{{v.label}}</td><td class=r>{{v.n}}</td>
<td class=r {{'style="color:#b91c1c;font-weight:700"'|safe if v.fehlt else 'style="color:#047857"'|safe}}>{{v.fehlt if v.fehlt else '✓ 0'}}</td>
<td><a href="{{url_for('abgleich',liste=v.id)}}">anzeigen</a></td></tr>{% endfor %}</table></div>{% endif %}
<div class=card><h2>Zusammenfassung</h2>
<table><tr><th>Nummernkreis</th><th class=r>Rechnungen in Liste</th><th class=r>Summe Liste</th><th class=r>PDF vorhanden</th>
<th class=r>PDF fehlt</th><th class=r>Betrag weicht ab</th><th class=r>Bezahlt (Kasse/Konto)</th><th>Lücken in der Nummernfolge</th></tr>
{% for k in kreise %}<tr><td><b>{{k.kreis}}</b>xxxx {{k.name}}</td><td class=r>{{k.n}}</td>
<td class=r>{{'%.2f'|format(k.summe)|replace('.',',')}}</td><td class=r>{{k.mit}}</td>
<td class=r {{'style="color:#b91c1c;font-weight:700"'|safe if k.fehlt}}>{{k.fehlt}}</td>
<td class=r {{'style="color:#b91c1c;font-weight:700"'|safe if k.abw}}>{{k.abw}}</td>
<td class=r>{{k.bez_n}} von {{k.n}}{% if k.unbez_n %}<br><small>{{k.unbez_n}} unbezahlt ({{'%.2f'|format(k.unbez_summe)|replace('.',',')}} &euro;)</small>{% endif %}</td>
<td>{% if k.luecken %}{{k.luecken|length}}: {{k.luecken[:12]|join(', ')}}{{' …' if k.luecken|length>12}}{% else %}keine{% endif %}</td></tr>{% endfor %}
</table><small>Zeitraum der Liste(n): {{von}} bis {{bis}}. Lücken können stornierte oder nicht gedruckte Nummern sein.</small></div>
<div class=card><h2>{{'Alle Rechnungen' if alle else 'Abweichungen'}} ({{zeilen|length}})</h2>
<table><tr><th>Rg.-Nr.</th><th>Datum</th><th>Kunde</th><th class=r>Betrag Liste</th><th>Zahlung</th><th class=r>Betrag PDF</th><th>Ergebnis</th><th></th></tr>
{% for z in zeilen %}<tr><td>{{z.nr}}</td><td>{{z.datum}}</td><td>{{z.name}}</td>
<td class=r>{{'%.2f'|format(z.betrag)|replace('.',',')}}</td>
<td class="z-{{z.zahl_klasse}}">{{z.zahl}}</td>
<td class=r>{{('%.2f'|format(z.pdf_betrag)|replace('.',',')) if z.pdf_betrag is not none else '–'}}</td>
<td style="color:{{z.farbe}};font-weight:600">{{z.text}}{% if z.rid %} &middot; <a href="{{url_for('beleg',rid=z.rid)}}" target=_blank>PDF</a>{% endif %}</td>
<td>{% if z.bestaetigt %}<form method=post action="{{url_for('abgleich_ok')}}"><input type=hidden name=nr value="{{z.nr}}"><input type=hidden name=aufheben value=1><input type=hidden name=zurueck value="{{zurueck}}"><button class=sek style="padding:4px 10px">Bestätigung aufheben</button></form>
{% elif not z.ok %}<form method=post action="{{url_for('abgleich_ok')}}" style="display:flex;gap:6px;align-items:center"><input type=hidden name=nr value="{{z.nr}}"><input type=hidden name=zurueck value="{{zurueck}}"><input name=bemerkung placeholder="Bemerkung (optional)" style="width:170px;padding:4px"><button style="padding:4px 12px;white-space:nowrap">OK geben</button></form>{% endif %}</td></tr>
{% else %}<tr><td colspan=8>Keine Abweichungen &ndash; alles passt.</td></tr>{% endfor %}</table></div>
{% if extra %}<div class=card><h2>PDFs ohne Eintrag in der Liste ({{extra|length}})</h2>
<table><tr><th>Rg.-Nr.</th><th>Datum</th><th>Belegart</th><th>PDF</th></tr>
{% for r in extra %}<tr><td>{{r.rechnungsnr}}</td><td>{{r.datum}}</td><td>{{r.belegart}}</td>
<td><a href="{{url_for('beleg',rid=r.id)}}" target=_blank>öffnen</a> &middot; <a href="{{url_for('bearbeiten',rid=r.id)}}">bearbeiten</a></td></tr>{% endfor %}</table></div>{% endif %}
{% if falsch %}<div class=card><h2>Belegart passt nicht zum Nummernkreis ({{falsch|length}})</h2>
<table><tr><th>Rg.-Nr.</th><th>aktuell</th><th>erwartet</th><th></th></tr>
{% for r,soll in falsch %}<tr><td>{{r.rechnungsnr}}</td><td>{{r.belegart}}</td><td>{{soll}}</td>
<td><a href="{{url_for('bearbeiten',rid=r.id)}}">bearbeiten</a></td></tr>{% endfor %}</table></div>{% endif %}
{% endif %}"""

KREIS_ART = {"261": "Rechnungsausgang Verkauf", "263": "Rechnungsausgang Service"}


@app.route("/abgleich/ok", methods=["POST"])
def abgleich_ok():
    """Bestaetigt eine Abweichung im Abgleich ('OK geben') bzw. nimmt die Bestaetigung zurueck."""
    nr = request.form.get("nr", "").strip()
    if nr:
        if request.form.get("aufheben"):
            db().execute("DELETE FROM quittiert WHERE rechnungsnr=?", (nr,))
        else:
            db().execute("INSERT OR REPLACE INTO quittiert(rechnungsnr,bemerkung,am) VALUES(?,?,?)",
                         (nr, request.form.get("bemerkung", "").strip(), date.today().isoformat()))
        db().commit()
    ziel = request.form.get("zurueck", "")
    return redirect(ziel if ziel.startswith("/abgleich") else url_for("abgleich"))


@app.route("/abgleich")
def abgleich():
    zahlungen_synchronisieren()
    quitt = quittiert_laden()
    liste = request.args.get("liste") or "neueste"
    alle = bool(request.args.get("alle"))
    listen = listen_laden()
    eintraege, gewaehlt = liste_waehlen(listen, liste)
    vorhanden_nr = {r[0] for r in db().execute("SELECT rechnungsnr FROM rechnungen WHERE datei IS NOT NULL "
                                               "AND rechnungsnr<>'' AND belegart<>'Rechnungsausgangliste'")}
    verlauf = [dict(id=l["id"], label=l["label"].split("  (")[0], n=len(l["eintraege"]),
                    fehlt=sum(1 for nr in l["eintraege"] if nr.startswith(NUMMERNKREISE) and nr not in vorhanden_nr
                              and nr not in quitt))
               for l in reversed(listen)]
    page_ctx = dict(listen=listen, liste=liste, alle=alle, eintraege=eintraege, verlauf=verlauf,
                    gewaehlt_label=" + ".join(l["label"].split("  (")[0] for l in gewaehlt) or "–",
                    kreise=[], zeilen=[], extra=[], falsch=[], von="", bis="", fehlt_gesamt=0,
                    zurueck=request.full_path.rstrip("?"))
    if not eintraege:
        return page(ABGLEICH, **page_ctx)

    # abgelegte Rechnungen nach Nummer
    pdfs = {}
    for r in db().execute("SELECT * FROM rechnungen WHERE rechnungsnr<>'' AND datei IS NOT NULL "
                          "AND belegart<>'Rechnungsausgangliste'"):
        pdfs.setdefault(r["rechnungsnr"], r)

    pay = zahlungsstand()

    def ist_bezahlt(e):  # bezahlt = Zahlung nachgewiesen; eine bestaetigte 0,00-Rechnung braucht keine Zahlung
        return _bezahlt(pay.get(e["nr"]), e["betrag"]) or (e["betrag"] == 0 and e["nr"] in quitt)

    zeilen, kreise = [], []
    for kreis in NUMMERNKREISE:
        mine = [e for e in eintraege.values() if e["nr"].startswith(kreis)]
        nummern = sorted(int(e["nr"]) for e in mine)
        luecken = [n for n in range(nummern[0], nummern[-1] + 1) if n not in set(nummern)] if nummern else []
        mit = fehlt = abw = 0
        for e in sorted(mine, key=lambda x: x["nr"]):
            r = pdfs.get(e["nr"])
            z = dict(e, rid=None, pdf_betrag=None)
            if not r:
                fehlt += e["nr"] not in quitt
                z.update(text="PDF fehlt", farbe="#b91c1c")
            else:
                mit += 1
                z["rid"] = r["id"]
                pfad = BELEGE / r["datei"]
                pb = r["brutto"] if r["brutto"] else (
                    finde_endsumme(pdf_text(pfad)) if pfad.suffix.lower() == ".pdf" else None)
                z["pdf_betrag"] = pb
                if pb is None:
                    z.update(text="PDF da, Betrag nicht lesbar", farbe="#6b7178")
                elif abs(pb - e["betrag"]) > 0.01:
                    abw += e["nr"] not in quitt
                    z.update(text=f"Betrag weicht ab ({pb - e['betrag']:+.2f})".replace(".", ","), farbe="#b91c1c")
                elif e["betrag"] == 0:
                    z.update(text="Betrag 0,00 – bitte prüfen", farbe="#b45309")
                else:
                    z.update(text="OK", farbe="#047857")
            z["ok"] = z["text"] == "OK"
            z["bestaetigt"] = False
            if not z["ok"] and e["nr"] in quitt:
                q = quitt[e["nr"]]
                z.update(text=f"OK bestätigt {_dm(q['am'])}" + (f": {q['bem']}" if q["bem"] else ""),
                         farbe="#047857", ok=True, bestaetigt=True)
            p = pay.get(e["nr"])
            if e["betrag"] == 0 and e["nr"] in quitt and not p:
                z.update(zahl="bezahlt (ohne Zahlung, bestätigt)", zahl_klasse="bezahlt")
            elif _bezahlt(p, e["betrag"]):
                z.update(zahl=f"bezahlt ({p['arten'] or p['quellen']} {_dm(p['am'])})", zahl_klasse="bezahlt")
            elif p:
                z.update(zahl=f"teilweise ({p['summe']:.2f} €)".replace(".", ","), zahl_klasse="teilweise")
            else:
                z.update(zahl="offen", zahl_klasse="offen")
            zeilen.append(z)
        fe = [e for e in mine if e["nr"] not in pdfs and e["nr"] not in quitt]
        kreise.append(dict(kreis=kreis, name=KREIS_ART[kreis].replace("Rechnungsausgang ", ""), n=len(mine),
                           summe=sum(e["betrag"] for e in mine), mit=mit, fehlt=fehlt, abw=abw, luecken=luecken,
                           fehlt_summe=sum(e["betrag"] for e in fe),
                           bez_n=sum(1 for e in mine if ist_bezahlt(e)),
                           unbez_n=sum(1 for e in mine if not ist_bezahlt(e)),
                           unbez_summe=sum(e["betrag"] for e in mine if not ist_bezahlt(e)),
                           fehlt_bereiche=nummern_bereiche([e["nr"] for e in fe]) if fe else ""))
    page_ctx["kreise"] = kreise
    page_ctx["fehlt_gesamt"] = sum(k["fehlt"] for k in kreise)
    page_ctx["zeilen"] = zeilen if alle else [z for z in zeilen if not z["ok"]]
    daten = sorted(e["datum"] for e in eintraege.values())
    page_ctx["von"], page_ctx["bis"] = daten[0], daten[-1]

    # PDFs im Zeitraum der Liste, die in der Liste fehlen / falsche Belegart
    for nr, r in sorted(pdfs.items()):
        kreis = next((k for k in NUMMERNKREISE if nr.startswith(k) and len(nr) == 7), None)
        if not kreis:
            continue
        if nr not in eintraege and daten[0] <= r["datum"] <= daten[-1]:
            page_ctx["extra"].append(r)
        if r["belegart"] != KREIS_ART[kreis]:
            page_ctx["falsch"].append((r, KREIS_ART[kreis]))
    return page(ABGLEICH, **page_ctx)


# ---------------------------------------------------------------- Zahlungen (Kassenbuch / Kontoauszug)
KASSE_RE = re.compile(r"(\d{7})\nZlg\.-Rg\.:\s*(.*?)\s*\n(-?[\d.]+) ?€\n(\d{2}:\d{2}:\d{2})\n[^\n]*\nRg\.-Nr\.:\s*(\d{7})")


def _dm(iso):
    return f"{iso[8:10]}.{iso[5:7]}." if iso and len(iso) >= 10 else ""


def kassenbuch_zeilen(text):
    """Zahlungszeilen eines Kassenbuch-Ausdrucks: 'Zlg.-Rg.: Name  Betrag  Uhrzeit' + 'Rg.-Nr.: 2630957'."""
    m = re.search(r"Datum:\s*(\d{2})\.(\d{2})\.(\d{4})", text)
    if not m:
        return []
    datum = f"{m.group(3)}-{m.group(2)}-{m.group(1)}"
    return [dict(datum=datum, beleg=b, name=n, betrag=kasse_zahl(bt), zeit=z, rechnungsnr=rg)
            for b, n, bt, z, rg in KASSE_RE.findall(text)]


def kassenjournal_summen(text):
    """Kassenjournal ('Tagessumme:' + Scheck/Bar/Credit) -> dict(datum, scheck, bar, credit). Sonst nur das Datum, Summen 0.
    Die Credit-Summe des Journals (Verkaeufe an der Kasse) kommt zu den Karten-Zahlungen im Kassenbuch dazu."""
    m = re.search(r"Datum:\s*(\d{2})\.(\d{2})\.(\d{4})", text)
    if not m:
        return None
    out = dict(datum=f"{m.group(3)}-{m.group(2)}-{m.group(1)}", scheck=0.0, bar=0.0, credit=0.0)
    ts = re.findall(r"Tagessumme:\s*\n([^\n]*)\n\s*\n([^\n]*)\n([^\n]*)\n([^\n]*)", text)
    if ts:
        def zahl(t):
            return int(re.sub(r"\D", "", t) or 0) / 100
        out["scheck"], out["bar"], out["credit"] = (zahl(x) for x in ts[-1][1:4])
    return out


def kassenbuch_zahlarten(pfad):
    """{Beleg-Nr: 'Bar'|'Karte'|'Scheck'} - nach der Spalte (Scheck/Bar/Credit), in der der Betrag steht."""
    try:
        reader = PdfReader(str(pfad))
    except Exception:  # noqa: BLE001
        return {}
    items = []
    for i, pg in enumerate(reader.pages):
        def besuch(text, cm, tm, fd, fs, i=i):
            t = text.strip()
            if t:
                items.append((i, round(tm[5]), round(tm[4]), t))
        try:
            pg.extract_text(visitor_text=besuch)
        except Exception:  # noqa: BLE001
            return {}
    zeilen = {}
    for seite, y, x, t in items:
        zeilen.setdefault((seite, y), []).append((x, t))
    betrag_re = re.compile(r"-?[\d.]+ ?€$")
    # Spaltenanker aus der Summenzeile (mindestens 4 Betraege in einer Zeile: Scheck, Bar, Credit, Ausgaben)
    anker = None
    for key in sorted(zeilen, key=lambda k: (k[0], -k[1])):
        xs = sorted(x for x, t in zeilen[key] if betrag_re.match(t))
        if len(xs) >= 4:
            anker = xs[:3]
            break
    anker = anker or [9907, 11153, 13153]
    namen = ("Scheck", "Bar", "Karte")
    out = {}
    for key, zl in zeilen.items():
        beleg = next((t for x, t in zl if re.fullmatch(r"\d{7}", t) and x < 2500), None)
        betrag = next((x for x, t in zl if betrag_re.match(t) and x < 14000), None)
        if beleg and betrag is not None and any(t.startswith("Zlg.-Rg.") for x, t in zl):
            out[beleg] = namen[min(range(3), key=lambda k: abs(anker[k] - betrag))]
    return out


def _datum_iso(t):
    t = (t or "").strip()
    m = re.fullmatch(r"(\d{1,2})\.(\d{1,2})\.(\d{2}|\d{4})", t)
    if m:
        j = m.group(3) if len(m.group(3)) == 4 else "20" + m.group(3)
        return f"{j}-{int(m.group(2)):02d}-{int(m.group(1)):02d}"
    return t[:10] if re.match(r"\d{4}-\d{2}-\d{2}", t) else ""


def _betrag_de(t):
    t = (t or "").strip().replace("\u00a0", "").replace(" ", "")
    if "," in t:
        t = t.replace(".", "").replace(",", ".")
    try:
        return float(t)
    except ValueError:
        return None


def parse_kontoauszug(daten, dateiname):
    """Liest Bankbuchungen aus CSV (Sparkasse CSV-CAMT & aehnliche) oder CAMT.053-XML."""
    out = []
    if daten.lstrip()[:5] in (b"<?xml", b"<Docu") or dateiname.lower().endswith((".xml", ".camt")):
        root = ET.fromstring(daten)
        for ntry in root.iter():
            if _lokal(ntry.tag) != "Ntry":
                continue
            betrag = _num(_txt(ntry, "Amt"))
            if betrag is None:
                continue
            if _txt(ntry, "CdtDbtInd") == "DBIT":
                betrag = -betrag
            datum = _txt(ntry, "BookgDt", "Dt") or _txt(ntry, "BookgDt", "DtTm")[:10]
            zweck = " ".join((x.text or "").strip() for x in ntry.iter() if _lokal(x.tag) == "Ustrd")
            name = _txt(ntry, "RltdPties", "Dbtr", "Nm") if betrag > 0 else _txt(ntry, "RltdPties", "Cdtr", "Nm")
            out.append(dict(datum=datum[:10], betrag=betrag, name=name, zweck=zweck))
        return out
    try:
        text = daten.decode("utf-8-sig")
    except UnicodeDecodeError:
        text = daten.decode("latin-1")
    zeilen = text.splitlines()
    trenner = max(";\t,", key=lambda t: sum(z.count(t) for z in zeilen[:30]))
    rows = list(csv.reader(zeilen, delimiter=trenner))
    kopf_i = next((i for i, r in enumerate(rows)
                   if any("betrag" in c.lower() for c in r) and any(("buchungstag" in c.lower() or "datum" in c.lower()
                                                                      or "valuta" in c.lower()) for c in r)), None)
    if kopf_i is None:
        return []
    kopf = [c.strip().strip('"').lower() for c in rows[kopf_i]]

    def spalte(*namen, exakt=False):
        for n in namen:
            for i, c in enumerate(kopf):
                if (c == n) if exakt else (n in c):
                    return i
        return None

    i_dat = spalte("buchungstag", "buchungsdatum", "datum", "valuta")
    i_bet = spalte("betrag", exakt=True)
    if i_bet is None:
        i_bet = spalte("betrag")
    i_zw = spalte("verwendungszweck", "buchungstext")
    i_nm = spalte("beguenstigter", "begünstigter", "zahlungspflichtiger", "auftraggeber", "name")
    for r in rows[kopf_i + 1:]:
        if not r or max(i_dat, i_bet) >= len(r):
            continue
        betrag, datum = _betrag_de(r[i_bet]), _datum_iso(r[i_dat])
        if betrag is None or not datum:
            continue
        out.append(dict(datum=datum, betrag=betrag, name=r[i_nm].strip() if i_nm is not None and i_nm < len(r) else "",
                        zweck=" ".join(r[i_zw].split()) if i_zw is not None and i_zw < len(r) else ""))
    return out


def skonto_prozent(text):
    """Skonto-Prozent aus dem Rechnungstext, z. B. 'SEPA-Lastschrift 14 TAGE, 3% SK.' oder '2 % Skonto'. 0 = keins."""
    for pat in (r"(\d{1,2}(?:[.,]\d+)?)\s*%\s*(?:SK\b|Skonto)", r"Skonto[^\n\d]{0,25}(\d{1,2}(?:[.,]\d+)?)\s*%"):
        m = re.search(pat, text, re.I)
        if m:
            v = float(m.group(1).replace(",", "."))
            if 0 < v <= 10:
                return v
    return 0.0


def _sk_faktor(skonto):
    """Kleinster Zahlbetrag relativ zur Rechnung: Skonto der Rechnung (mit 0,5 % Spielraum), sonst allgemein 3,5 %."""
    return 1 - skonto / 100 - 0.005 if skonto else 0.965


def _norm(t):
    t = t.lower().replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")
    return re.sub(r"[^a-z0-9]", "", t)


def _nr_im_text(nr, nt):
    """Rechnungsnummer (normalisiert) steht im normalisierten Bank-Text. Zu kurze Nummern und reine Jahreszahlen zaehlen nicht."""
    n = _norm(nr)
    return len(n) >= 5 and not re.fullmatch(r"(19|20)\d{2}", n) and n in nt


def _ausgang_fallback(text, betrag, ausg, kd_map):
    """Wenn keine Rechnungsnummer sauber im Text steht: (a) zusammengeschriebene Nummer ('261020913') nur mit
    passendem Betrag, (b) Kundennummer im Text + Betrag passt zu einer Rechnung (oder Summe von bis zu 4) dieses Kunden."""
    gesamt = abs(betrag)
    for nr, br in ausg.items():
        if nr in text and abs(abs(br) - gesamt) <= 0.01:
            return [(nr, abs(br))]
    for tok in re.findall(r"(?<!\d)\d{3,6}(?!\d)", text):
        kand = kd_map.get(tok)
        if not kand:
            continue
        for k in range(1, min(4, len(kand)) + 1):
            for combo in itertools.combinations(kand, k):
                if abs(sum(abs(b) for _, b in combo) - gesamt) <= 0.02:
                    return [(nr, abs(b)) for nr, b in combo]
    return []


def _eingang_fallback(name, betrag, eing, eing_lief, aliase=None, eing_sk=None):
    """Lieferantenzahlung ohne Rechnungsnummer im Text: Lieferantenname im Bank-Namen + Betrag passt (ggf. mit
    Skonto bis 3,5 %) zu genau einer Rechnung. Bei mehreren Treffern wird nicht geraten."""
    gesamt, nn = abs(betrag), _norm(name)
    kand = []
    for nr, br in eing.items():
        if (br > 0) != (betrag < 0):
            continue
        namen = (aliase or {}).get(eing_lief.get(nr, ""), [eing_lief.get(nr, "")])
        lief_ok = any(len(_norm(x)) >= 3 and _norm(x) in nn for x in namen)
        soll = abs(br)
        if lief_ok and soll > 0 and (abs(soll - gesamt) <= 0.01
                                     or soll * _sk_faktor((eing_sk or {}).get(nr, 0)) - 0.01 <= gesamt <= soll):
            kand.append((nr, soll))
    return kand if len(kand) == 1 else []


def kartenabrechnungen():
    """Ordnet Karten-Sammelgutschriften der Bank ('INIT:CC:ABR:DAT..:BRUTTO..') den Karten-Tagessummen der
    Kassenbuecher zu. Rueckgabe: {bank_id: {betrag, dat, kasse}}; kasse = Text der Kassenbuch-Tage oder None."""
    tage = kartentage()
    out = {}
    for b in db().execute("SELECT id, zweck, name, datum, betrag FROM bank "
                          "WHERE zweck LIKE '%INIT:CC:ABR%' OR UPPER(name) LIKE '%NEXI%'"):
        if b["betrag"] < 0:  # Lastschrift von Nexi = Entgelte (Rechnung), keine Kartenabrechnung
            continue
        m = re.search(r"DAT(\d{2})\.(\d{2})\.(\d{2}).*?BRUTTO(\d+),(\d{2})", b["zweck"])
        if m:
            brutto = float(f"{m.group(4)}.{m.group(5)}")
            dat = date(2000 + int(m.group(3)), int(m.group(2)), int(m.group(1)))
        elif b["betrag"] > 0:  # NEXI-Gutschrift ohne Detailangaben: Bankdatum und Betrag
            brutto, dat = b["betrag"], date.fromisoformat(b["datum"])
        else:
            continue
        kasse, gedeckt = None, []
        for versatz in range(0, 6):          # Abrechnung kommt meist 1-4 Tage nach dem Kassentag
            for laenge in range(1, 6):       # ... und kann mehrere Tage (Wochenende) zusammenfassen
                tage_liste = [(dat - timedelta(days=versatz + j)).isoformat() for j in range(laenge)]
                # erster/letzter Tag brauchen Kartenumsatz; Tage ohne Kassenbuch (Wochenende) zaehlen 0
                if tage_liste[0] in tage and tage_liste[-1] in tage \
                        and abs(sum(tage.get(t, 0) for t in tage_liste) - brutto) <= 0.01:
                    a, e = tage_liste[-1], tage_liste[0]
                    kasse = _dm(a) if a == e else f"{_dm(a)}\u2013{_dm(e)}"
                    gedeckt = [t for t in tage_liste if t in tage]
                    break
            if kasse:
                break
        out[b["id"]] = dict(betrag=brutto, dat=dat.isoformat(), kasse=kasse, tage=gedeckt,
                            kasse_summe=tage.get(dat.isoformat()))  # Kassenbuch-Credit des NEXI-Tages (zur Fehlersuche)
    return out


def kartentage():
    """{Kassentag: Credit-Summe} = Karten-Zahlungen auf Rechnungen (Kassenbuch) + Credit-Verkaeufe (Kassenjournal)."""
    tage = {r["datum"]: r["s"] for r in db().execute(
        "SELECT datum, ROUND(SUM(betrag),2) s FROM kassenzeilen WHERE zahlart='Karte' GROUP BY datum")}
    for r in db().execute("SELECT datum, ROUND(SUM(credit),2) s FROM kassentage GROUP BY datum"):
        tage[r["datum"]] = round(tage.get(r["datum"], 0) + r["s"], 2)
    return {d: v for d, v in tage.items() if v}


def bank_zahlungen():
    """Ordnet Bankbuchungen ueber die Rechnungsnummer im Verwendungszweck Rechnungen zu."""
    ausg = {r["rechnungsnr"]: r["brutto"] for r in db().execute(
        "SELECT rechnungsnr, brutto FROM rechnungen WHERE rechnungsnr<>'' AND belegart IN (?,?,?)", AUSGANG_RECHNUNGEN)}
    kd_map = {}
    liste_eintraege, _ = liste_waehlen(listen_laden(), "alle")  # auch Rechnungen, deren PDF noch fehlt
    for nr, e in liste_eintraege.items():
        if nr.startswith(NUMMERNKREISE):
            ausg.setdefault(nr, e["betrag"])
            kd_map.setdefault(e["kd"], []).append((nr, e["betrag"]))
    eing = {r["rechnungsnr"]: r["brutto"] for r in db().execute(
        "SELECT rechnungsnr, brutto FROM rechnungen WHERE rechnungsnr<>'' AND belegart=?", (EINGANG,))}
    aliase = lieferant_aliase(settings())
    eing_sk = {r["rechnungsnr"]: r["skonto"] or 0 for r in db().execute(
        "SELECT rechnungsnr, skonto FROM rechnungen WHERE rechnungsnr<>'' AND belegart=?", (EINGANG,))}
    eing_lief = {r["rechnungsnr"]: r["lieferant"] or "" for r in db().execute(
        "SELECT rechnungsnr, lieferant FROM rechnungen WHERE rechnungsnr<>'' AND belegart=?", (EINGANG,))}
    out = []
    for b in db().execute("SELECT * FROM bank ORDER BY datum, id"):
        text = f"{b['zweck']} {b['name']}"
        nt = _norm(text)
        treffer = []
        if b["betrag"] > 0:  # Zahlungseingang: Kundenzahlung oder Gutschrift eines Lieferanten
            zahlen = set(re.findall(r"(?<!\d)\d{7}(?!\d)", text))
            treffer += [(nr, abs(ausg[nr])) for nr in ausg if nr in zahlen]
            if not treffer:
                treffer += _ausgang_fallback(text, b["betrag"], ausg, kd_map)
            treffer += [(nr, abs(br)) for nr, br in eing.items() if br < 0 and _nr_im_text(nr, nt)]
        else:  # Zahlungsausgang an Lieferanten
            treffer += [(nr, abs(br)) for nr, br in eing.items() if br > 0 and _nr_im_text(nr, nt)]
        if not treffer:  # ohne Rechnungsnummer: Lieferant im Namen + passender Betrag
            treffer += _eingang_fallback(f"{b['name']} {b['zweck']}", b["betrag"], eing, eing_lief, aliase, eing_sk)  # PayPal: Lieferant steht im Zweck
        if not treffer:
            continue
        gesamt = abs(b["betrag"])
        summe = sum(t[1] for t in treffer)
        faktor_min = min(_sk_faktor(eing_sk.get(t[0], 0)) for t in treffer)
        if len(treffer) > 1 and not (abs(summe - gesamt) <= 0.02 or summe * faktor_min <= gesamt <= summe + 0.02):
            continue  # mehrere Rechnungen, Betrag passt nicht -> nicht raten
        faktor = gesamt / summe if len(treffer) > 1 and summe else 1
        for nr, br in treffer:
            out.append(("Kontoauszug", b["datum"], gesamt if len(treffer) == 1 else round(br * faktor, 2), nr,
                        f"{b['name']}: {b['zweck'][:70]}", b["id"]))
    return out


def _bezahlt(p, betrag):
    return bool(p) and p["summe"] >= abs(betrag) - 0.01


def zahlungsstand():
    """{Rechnungsnummer: {summe, quellen, am}} aus der Tabelle zahlungen."""
    out = {}
    for r in db().execute("SELECT rechnungsnr, SUM(betrag) s, GROUP_CONCAT(DISTINCT quelle) q, MAX(datum) am, "
                          "GROUP_CONCAT(DISTINCT zahlart) a FROM zahlungen GROUP BY rechnungsnr"):
        out[r["rechnungsnr"]] = dict(summe=r["s"], quellen=r["q"].replace(",", "/"), am=r["am"],
                                     arten=(r["a"] or "").replace(",", "/"))
    return out


def zahlungen_synchronisieren():
    """Liest neue Kassenbuecher, ordnet Bankbuchungen zu und setzt daraus den Zahlstatus der Rechnungen.
    'bezahlt' entsteht ausschliesslich aus Kassenbuch und Kontoauszug."""
    geprueft = {r[0] for r in db().execute("SELECT dokument_id FROM kasse_geprueft")}
    mit_tag = {r[0] for r in db().execute("SELECT dokument_id FROM kassentage")}
    for r in db().execute("SELECT id, datei FROM rechnungen WHERE belegart='Kassenbuch' AND datei IS NOT NULL").fetchall():
        if r["id"] in geprueft and r["id"] in mit_tag:
            continue
        pfad = BELEGE / r["datei"]
        if pfad.exists() and pfad.suffix.lower() == ".pdf":
            arten = kassenbuch_zahlarten(pfad)
            text = pdf_text(pfad, max_seiten=None)
            tag = kassenjournal_summen(text)
            if tag:
                db().execute("INSERT OR REPLACE INTO kassentage(dokument_id,datum,credit,bar,scheck) VALUES(?,?,?,?,?)",
                             (r["id"], tag["datum"], tag["credit"], tag["bar"], tag["scheck"]))
            for z in kassenbuch_zeilen(text):
                db().execute("INSERT OR IGNORE INTO kassenzeilen(dokument_id,datum,beleg,name,betrag,zeit,rechnungsnr,zahlart) "
                             "VALUES(?,?,?,?,?,?,?,?)", (r["id"], z["datum"], z["beleg"], z["name"], z["betrag"],
                                                         z["zeit"], z["rechnungsnr"], arten.get(z["beleg"], "Kasse")))
            db().execute("INSERT OR IGNORE INTO kasse_geprueft(dokument_id) VALUES(?)", (r["id"],))
    for r in db().execute("SELECT id, datei FROM rechnungen WHERE belegart=? AND skonto IS NULL", (EINGANG,)).fetchall():
        pfad = BELEGE / r["datei"] if r["datei"] else None
        sk = skonto_prozent(pdf_text(pfad, max_seiten=None)) if pfad and pfad.suffix.lower() == ".pdf" and pfad.exists() else 0
        db().execute("UPDATE rechnungen SET skonto=? WHERE id=?", (sk, r["id"]))
    ids = "(SELECT id FROM rechnungen)"
    db().execute(f"DELETE FROM kassenzeilen WHERE dokument_id NOT IN {ids}")
    db().execute(f"DELETE FROM kasse_geprueft WHERE dokument_id NOT IN {ids}")
    db().execute(f"DELETE FROM kassentage WHERE dokument_id NOT IN {ids}")
    db().execute("DELETE FROM zahlungen")
    db().execute("INSERT INTO zahlungen(quelle,datum,betrag,rechnungsnr,info,zahlart) "
                 "SELECT 'Kassenbuch', datum, betrag, rechnungsnr, 'Beleg '||beleg||' '||name, COALESCE(zahlart,'Kasse') "
                 "FROM kassenzeilen")
    for q, datum, betrag, nr, info, bank_id in bank_zahlungen():
        db().execute("INSERT INTO zahlungen(quelle,datum,betrag,rechnungsnr,info,bank_id,zahlart) VALUES(?,?,?,?,?,?,?)",
                     (q, datum, betrag, nr, info, bank_id, "Bank"))
    pay = zahlungsstand()
    quitt = {r[0]: r[1] for r in db().execute("SELECT rechnungsnr, am FROM quittiert")}
    abzug_set = lieferanten_abzug(settings())
    for r in db().execute("SELECT id, rechnungsnr, brutto, belegart, lieferant, zahlung, zahl_am, zahl_quelle, zahl_art, skonto FROM rechnungen "
                          "WHERE rechnungsnr<>'' AND belegart IN (?,?,?,?)", AUSGANG_RECHNUNGEN + (EINGANG,)).fetchall():
        p, soll = pay.get(r["rechnungsnr"]), abs(r["brutto"] or 0)
        abzug_ok = r["belegart"] == EINGANG and r["lieferant"] in abzug_set  # z. B. GLS: Gutschriften werden abgezogen
        if p and (p["summe"] >= soll - 0.01 or (r["belegart"] == EINGANG and p["summe"] >= soll * _sk_faktor(r["skonto"] or 0))
                  or (abzug_ok and p["summe"] > 0)):
            z = "bezahlt"
        elif p and p["summe"] > 0:
            z = "teilweise"
        else:
            z = "offen"
        am, quelle, art = (p["am"], p["quellen"], p["arten"]) if p else (None, None, None)
        if not p and soll < 0.005 and r["rechnungsnr"] in quitt:  # 0,00-Rechnung ohne Zahlung, vom Benutzer bestaetigt
            z, am, quelle, art = "bezahlt", quitt[r["rechnungsnr"]], "Bestätigt", ""
        if (z, r["zahl_am"], r["zahl_quelle"], r["zahl_art"]) != (r["zahlung"], am, quelle, art) and not (
                z == r["zahlung"] == "offen" and not r["zahl_am"] and not r["zahl_art"]):
            db().execute("UPDATE rechnungen SET zahlung=?, zahl_am=?, zahl_quelle=?, zahl_art=? WHERE id=?",
                         (z, am, quelle, art, r["id"]))
    db().commit()


ZAHLUNGEN = """
<form method=post enctype=multipart/form-data class=card>
<h2>Kontoauszug hochladen</h2>
<p>CSV (z. B. Sparkasse &bdquo;CSV-CAMT&ldquo;) oder CAMT.053-XML aus dem Online-Banking. Die App sucht die Rechnungsnummer im
Verwendungszweck. Doppelte Buchungen werden erkannt und nicht noch einmal gespeichert.</p>
<input type=file name=auszug accept=".csv,.txt,.xml,.camt" multiple>
<p><button>Hochladen &amp; abgleichen</button></p></form>
<div class=card><h2>Stand</h2>
<table><tr><th>Quelle</th><th class=r>Buchungen / Zeilen</th><th class=r>davon Rechnungen zugeordnet</th></tr>
<tr><td>Kassenbuch ({{kassen_docs}} Dokumente)</td><td class=r>{{kassen_n}}</td><td class=r>{{kassen_n}}</td></tr>
<tr><td>Kontoauszug</td><td class=r>{{bank_n}}</td><td class=r>{{bank_zugeordnet}}</td></tr>
{% if karten_zeilen %}<tr><td>&nbsp;&nbsp;davon EC-Karteneingänge (NEXI Germany &harr; Kassenbuch)</td><td class=r>{{karten_zeilen|length}}</td><td class=r>{{karten_gefunden}}</td></tr>{% endif %}</table>
<small>Kontoauszüge (CSV/CAMT) kannst du auch in den Eingangsordner legen, die App liest sie automatisch ein.<br>
Rechnungen gelten nur als &bdquo;bezahlt&ldquo;, wenn hier eine Zahlung zugeordnet ist (Skonto bis 3,5 % bei Eingangsrechnungen).
Offene Rechnungen: <a href="{{url_for('index',zahlung='unbezahlt')}}">anzeigen</a></small></div>
<div class=card><h2>Zugeordnete Zahlungen ({{zahlungen|length}})</h2>
<table><tr><th>Datum</th><th>Quelle</th><th>Zahlart</th><th>Rg.-Nr.</th><th class=r>Betrag</th><th>Info</th></tr>
{% for z in zahlungen %}<tr><td>{{z.datum}}</td><td>{{z.quelle}}</td><td>{{z.zahlart}}</td><td>{{z.rechnungsnr}}</td>
<td class=r>{{'%.2f'|format(z.betrag)|replace('.',',')}}</td><td><small>{{z.info}}</small></td></tr>
{% else %}<tr><td colspan=6>Noch keine Zahlungen. Lade ein Kassenbuch (Monatsunterlagen) oder einen Kontoauszug hoch.</td></tr>{% endfor %}</table></div>
{% if karten_zeilen %}<div class=card><h2>EC-Karteneingänge (NEXI Germany): Bank &harr; Kassenbuch ({{karten_zeilen|length}})</h2>
<table><tr><th>Bank-Datum</th><th>Kassentag laut NEXI</th><th class=r>Betrag</th><th>Kartenumsätze laut Kassenbuch vom</th></tr>
{% for k in karten_zeilen %}<tr><td>{{k.datum}}</td><td>{{k.tag[8:]}}.{{k.tag[5:7]}}.{{k.tag[:4]}}</td><td class=r>{{'%.2f'|format(k.betrag)|replace('.',',')}}</td>
<td>{% if k.kasse %}<b style="color:#047857">&#10003; {{k.kasse}}</b>{% elif k.summe is not none %}<span style="color:#b45309">Kassenbuch {{k.tag[8:]}}.{{k.tag[5:7]}}.: {{'%.2f'|format(k.summe)|replace('.',',')}} &euro; &ndash; Differenz {{'%.2f'|format(k.betrag - k.summe)|replace('.',',')}} &euro;</span>{% else %}<span style="color:#b45309">kein Kassenbuch für diesen Tag vorhanden</span>{% endif %}</td></tr>{% endfor %}</table></div>{% endif %}
{% if offen_bank %}<div class=card><h2>Nicht zugeordnete Bankbuchungen ({{offen_bank|length}})</h2>
<table><tr><th>Datum</th><th class=r>Betrag</th><th>Name</th><th>Verwendungszweck</th></tr>
{% for b in offen_bank %}<tr><td>{{b.datum}}</td><td class=r>{{'%.2f'|format(b.betrag)|replace('.',',')}}</td><td>{{b.name}}</td><td><small>{{b.zweck}}</small></td></tr>{% endfor %}
</table></div>{% endif %}"""


@app.route("/zahlungen", methods=["GET", "POST"])
def zahlungen_seite():
    if request.method == "POST":
        neu = doppelt = 0
        for up in request.files.getlist("auszug"):
            if not up.filename:
                continue
            daten = up.read()
            try:
                buchungen = parse_kontoauszug(daten, up.filename)
            except Exception as e:  # noqa: BLE001
                flash(f"{up.filename}: nicht lesbar ({e}).")
                continue
            if not buchungen:
                flash(f"{up.filename}: keine Buchungen erkannt. Bitte CSV oder CAMT.053 aus dem Online-Banking verwenden.")
                continue
            for b in buchungen:
                if bank_doppelt(db(), b, up.filename):
                    doppelt += 1
                    continue
                key = hashlib.sha1(f"{b['datum']}|{b['betrag']:.2f}|{b['name']}|{b['zweck']}".encode()).hexdigest()
                cur = db().execute("INSERT OR IGNORE INTO bank(datum,betrag,name,zweck,dokument,schluessel) "
                                   "VALUES(?,?,?,?,?,?)", (b["datum"], b["betrag"], b["name"], b["zweck"],
                                                           up.filename, key))
                neu += cur.rowcount
                doppelt += 1 - cur.rowcount
            (DATA / "kontoauszuege").mkdir(exist_ok=True)
            (DATA / "kontoauszuege" / f"{datetime.now():%Y%m%d-%H%M%S}_{secure_filename(up.filename)}").write_bytes(daten)
        db().commit()
        zahlungen_synchronisieren()
        if neu or doppelt:
            flash(f"{neu} neue Buchungen eingelesen" + (f", {doppelt} bereits vorhanden (übersprungen)." if doppelt else "."))
        return redirect(url_for("zahlungen_seite"))
    zahlungen_synchronisieren()
    zahlungen = db().execute("SELECT * FROM zahlungen ORDER BY datum DESC, id DESC").fetchall()
    zugeordnet = {r[0] for r in db().execute("SELECT DISTINCT bank_id FROM zahlungen WHERE bank_id IS NOT NULL")}
    alle_bank = db().execute("SELECT * FROM bank ORDER BY datum DESC, id DESC").fetchall()
    karten = kartenabrechnungen()
    karte_ok = {i for i, k in karten.items() if k["kasse"]}
    start = settings()["start_datum"]
    offen_bank = [b for b in alle_bank if b["id"] not in zugeordnet and b["id"] not in karten
                  and b["datum"] >= start]  # Karten: eigene Tabelle
    n_zug = len([b for b in alle_bank if b["id"] in zugeordnet or b["id"] in karte_ok])
    karten_zeilen = [dict(datum=b["datum"], betrag=karten[b["id"]]["betrag"], kasse=karten[b["id"]]["kasse"],
                          tag=karten[b["id"]]["dat"], summe=karten[b["id"]]["kasse_summe"])
                     for b in alle_bank if b["id"] in karten and b["datum"] >= start]
    return page(ZAHLUNGEN, zahlungen=zahlungen, offen_bank=offen_bank, karten_zeilen=karten_zeilen,
                karten_gefunden=len(karte_ok), bank_n=db().execute("SELECT COUNT(*) FROM bank").fetchone()[0],
                bank_zugeordnet=n_zug, kassen_n=db().execute("SELECT COUNT(*) FROM kassenzeilen").fetchone()[0],
                kassen_docs=db().execute("SELECT COUNT(*) FROM kasse_geprueft").fetchone()[0])


# ---------------------------------------------------------------- Bank: Eingangsrechnungen gegen Kontoauszug
BANK = """
<style>details.bank{background:#fff;border:1px solid var(--line);border-left:3px solid var(--accent);border-radius:6px;margin-bottom:10px;padding:0 18px}details.bank>summary{cursor:pointer;font:600 14px Tahoma,Arial,sans-serif;color:var(--head);padding:9px 0}details.bank[open]{padding-bottom:14px}details.bank[open]>summary{border-bottom:1px solid var(--line);margin-bottom:10px}</style>
<form method=get class=card style="display:flex;gap:12px;align-items:end;flex-wrap:wrap">
 <div><label>Monat</label><input type=month name=monat value="{{monat}}"></div>
 <button>Filtern</button> <a class="btn sek" href="{{url_for('bank_seite')}}">Zurücksetzen</a>
 <button type=submit formmethod=post formaction="{{url_for('bank_aktualisieren')}}" class=sek>&#8635; Aktualisieren</button></form>
<details class=bank open><summary>Offene Rechnungen &ndash; Stand laut Kontoauszug</summary>
{% if bank_n == 0 %}<p style="color:#b45309"><b>Noch kein Kontoauszug vorhanden.</b> Lege eine CSV/CAMT-Datei in den Eingangsordner oder lade sie unter
 <a href="{{url_for('zahlungen_seite')}}">Zahlungen</a> hoch.</p>{% endif %}
<table style="max-width:640px"><tr><th>Eingangsrechnungen</th><th class=r>Anzahl</th><th class=r>Summe brutto</th></tr>
{% for z in summen %}<tr><td class="z-{{z.klasse}}">{{z.name}}</td><td class=r>{{z.n}}</td><td class=r>{{'%.2f'|format(z.summe)|replace('.',',')}}</td></tr>{% endfor %}
<tr><td class="z-offen">Zahlungen ohne Rechnung (Bankausgänge)</td><td class=r>{{ohne|length}}</td><td class=r>{{'%.2f'|format(ohne_summe)|replace('.',',')}}</td></tr></table>
<small>&bdquo;Bezahlt&ldquo; heißt: Die Zahlung wurde im Kontoauszug über Rechnungsnummer oder Lieferant + Betrag gefunden (Skonto bis 3,5 % ist erlaubt).</small></details>
{% macro credit_tabelle(titel, liste, summe, hinweis, offen) %}<details class=bank {{"open" if offen}}><summary>{{titel}} ({{liste|length}}) &ndash; {{'%.2f'|format(summe)|replace('.',',')}} &euro;</summary>{{hinweis|safe}}
<table style="max-width:640px"><tr><th>Kassentag(e)</th><th class=r>Betrag Credit</th><th>Bank</th></tr>
{% for c in liste %}<tr><td>{{c.kasse}}</td><td class=r>{{'%.2f'|format(c.betrag)|replace('.',',')}}</td><td>{{c.bank}}</td></tr>
{% else %}<tr><td colspan=3>Keine Einträge{{' in diesem Monat' if monat}}.</td></tr>{% endfor %}
<tr style="font-weight:bold;border-top:2px solid #333"><td>Endsumme</td><td class=r>{{'%.2f'|format(summe)|replace('.',',')}}</td><td></td></tr></table></details>{% endmacro %}
{% macro rg_tabelle(titel, liste, summe, offen) %}<details class=bank {{"open" if offen}}><summary>{{titel}} ({{liste|length}}) &ndash; {{'%.2f'|format(summe)|replace('.',',')}} &euro;</summary>
<table><tr><th>Datum</th><th>Lieferant</th><th>Rg.-Nr.</th><th class=r>Brutto</th><th>Zahlung</th><th>Bezahlt am</th><th>Bankbuchung</th><th></th></tr>
{% for r in liste %}<tr><td>{{r.datum}}</td><td>{{r.lieferant}}</td><td>{{r.rechnungsnr}}</td>
<td class=r>{% if r.brutto %}{{'%.2f'|format(r.brutto)|replace('.',',')}}{% else %}<span style="color:#b45309">Betrag fehlt</span>{% endif %}</td>
<td class="z-{{r.zahlung or 'offen'}}">{{r.zahlung or 'offen'}}</td>
<td>{% if r.zahl_am %}{{r.zahl_am[8:]}}.{{r.zahl_am[5:7]}}.{{r.zahl_am[:4]}}{% endif %}</td>
<td><small>{{info.get(r.rechnungsnr,'')}}</small>{% if r.abzug %}<br><b style="color:#1d4ed8">Abzug {{'%.2f'|format(r.abzug)|replace('.',',')}} &euro;</b>{% endif %}</td>
<td>{% if r.datei %}<a href="{{url_for('beleg',rid=r.id)}}" target=_blank>PDF</a> &middot; {% endif %}<a href="{{url_for('bearbeiten',rid=r.id)}}">bearbeiten</a></td></tr>
{% else %}<tr><td colspan=8>Keine Rechnungen{{' in diesem Monat' if monat}}.</td></tr>{% endfor %}
<tr style="font-weight:bold;border-top:2px solid #333"><td colspan=3>Endsumme</td><td class=r>{{'%.2f'|format(summe)|replace('.',',')}}</td><td colspan=4></td></tr></table></details>{% endmacro %}
{{ rg_tabelle('Offene Rechnungen', offene_liste, offene_summe, true) }}
{{ rg_tabelle('Bezahlte Rechnungen', bezahlte_liste, bezahlte_summe, false) }}
{{ credit_tabelle('Credit-Zahlungen: Geldeingang offen', credit_offen, credit_offen_summe, '<p><small>Kartenumsätze aus Kassenbuch und Kassenjournal, zu denen noch keine NEXI-Gutschrift auf dem Konto gefunden wurde &ndash; hier prüfen, ob das Geld ankommt.</small></p>', true) }}
{{ credit_tabelle('Credit-Zahlungen: Geldeingang bestätigt', credit_ok, credit_ok_summe, '', false) }}
<details class=bank open><summary>Bankausgänge ohne Rechnung ({{ohne|length}}) &ndash; {{'%.2f'|format(ohne_summe)|replace('.',',')}} &euro;</summary>
<p><small>Zahlungen vom Konto, zu denen keine Eingangsrechnung gefunden wurde &ndash; entweder fehlt die Rechnung in der App oder es braucht keinen Beleg
(z. B. Versicherung, Steuer). Dann auf &bdquo;Kein Beleg nötig&ldquo; klicken.</small></p>
<table><tr><th>Datum</th><th>Empfänger</th><th>Verwendungszweck</th><th class=r>Betrag</th><th></th></tr>
{% for b in ohne %}<tr><td>{{b.datum}}</td><td>{{b.name}}</td><td><small>{{b.zweck[:90]}}</small></td><td class=r>{{'%.2f'|format(b.betrag)|replace('.',',')}}</td>
<td><form method=post action="{{url_for('bank_ignorieren')}}" style="display:flex;gap:6px"><input type=hidden name=bank_id value="{{b.id}}"><input type=hidden name=zurueck value="{{zurueck}}">
<input name=grund placeholder="Grund (optional)" style="width:150px;padding:4px"><button class=sek style="padding:4px 10px;white-space:nowrap">Kein Beleg nötig</button></form></td></tr>
{% else %}<tr><td colspan=5 style="color:#047857"><b>&#10003; Alle Bankausgänge sind Rechnungen zugeordnet.</b></td></tr>{% endfor %}</table>
{% if ignoriert %}<details style="margin-top:12px"><summary>{{ignoriert|length}} als &bdquo;kein Beleg nötig&ldquo; markiert</summary>
<table>{% for b in ignoriert %}<tr><td>{{b.datum}}</td><td>{{b.name}}</td><td class=r>{{'%.2f'|format(b.betrag)|replace('.',',')}}</td><td><small>{{b.grund}}</small></td>
<td>{% if not b.auto %}<form method=post action="{{url_for('bank_ignorieren')}}"><input type=hidden name=bank_id value="{{b.id}}"><input type=hidden name=aufheben value=1><input type=hidden name=zurueck value="{{zurueck}}"><button class=sek style="padding:4px 10px">wieder anzeigen</button></form>{% endif %}</td></tr>{% endfor %}</table></details>{% endif %}</details>"""


@app.route("/bank")
def bank_seite():
    zahlungen_synchronisieren()
    monat = request.args.get("monat", "")
    sql, par = "SELECT * FROM rechnungen WHERE belegart=?", [EINGANG]
    if monat:
        sql += " AND substr(datum,1,7)=?"
        par.append(monat)
    start = settings()["start_datum"]
    # Anzeige ab Startdatum; aeltere Rechnungen nur, wenn noch nicht (ganz) bezahlt oder erst ab Startdatum bezahlt
    alle_rechnungen = [dict(r) for r in db().execute(sql + " ORDER BY datum DESC, id DESC", par)
                       if (r["datum"] or "") >= start or r["zahlung"] != "bezahlt" or (r["zahl_am"] or "") >= start]
    pay, abzug_set = zahlungsstand(), lieferanten_abzug(settings())
    for r in alle_rechnungen:  # Abzug = Rechnung - tatsaechliche Zahlung (nur bei Lieferanten mit 'abzug')
        p = pay.get(r["rechnungsnr"])
        diff = abs(r["brutto"] or 0) - (p["summe"] if p else 0)
        r["abzug"] = diff if p and (r["lieferant"] in abzug_set or r["skonto"]) and r["zahlung"] == "bezahlt" and diff > 0.01 else 0
    summen = []
    for name, klasse, test in (("offen", "offen", lambda r: (r["zahlung"] or "offen") == "offen"),
                               ("teilweise bezahlt", "teilweise", lambda r: r["zahlung"] == "teilweise"),
                               ("bezahlt", "bezahlt", lambda r: r["zahlung"] == "bezahlt")):
        gruppe = [r for r in alle_rechnungen if test(r)]
        summen.append(dict(name=name, klasse=klasse, n=len(gruppe), summe=sum(abs(r["brutto"] or 0) for r in gruppe)))
    offene_liste = [r for r in alle_rechnungen if r["zahlung"] != "bezahlt"]  # offen + teilweise bezahlt
    bezahlte_liste = [r for r in alle_rechnungen if r["zahlung"] == "bezahlt"]
    info = {r[0]: r[1] for r in db().execute(
        "SELECT rechnungsnr, GROUP_CONCAT(substr(info,1,60), ' | ') FROM zahlungen WHERE quelle='Kontoauszug' GROUP BY rechnungsnr")}
    zug = {r[0] for r in db().execute("SELECT DISTINCT bank_id FROM zahlungen WHERE bank_id IS NOT NULL")}
    ign = {r[0]: r[1] for r in db().execute("SELECT bank_id, grund FROM bank_ignoriert")}
    bsql, bpar = "SELECT * FROM bank WHERE betrag<0 AND datum>=?", [start]
    if monat:
        bsql += " AND substr(datum,1,7)=?"
        bpar.append(monat)
    ohne, ignoriert = [], []
    for b in db().execute(bsql + " ORDER BY datum DESC, id DESC", bpar):
        if b["id"] in zug:
            continue
        text = f"{b['name']} {b['zweck']}".lower()
        if b["id"] in ign:
            ignoriert.append(dict(dict(b), grund=ign[b["id"]] or ""))
        elif any(k in text for k in BANK_OHNE_BELEG):
            ignoriert.append(dict(dict(b), grund="Bankentgelt \u2013 kein Beleg nötig", auto=True))
        else:
            ohne.append(b)
    karten = kartenabrechnungen()
    gedeckt = {}
    for bid, k in karten.items():
        for t in k["tage"]:
            gedeckt[t] = bid
    bank_datum = {b["id"]: b["datum"] for b in db().execute("SELECT id, datum FROM bank")}

    def dmy(iso):
        return f"{iso[8:10]}.{iso[5:7]}.{iso[:4]}"
    credit_offen = [dict(kasse=dmy(t), betrag=v, bank="noch nicht eingegangen")
                    for t, v in sorted(kartentage().items(), reverse=True)
                    if t not in gedeckt and t >= start and (not monat or t[:7] == monat)]
    credit_ok = [dict(kasse=k["kasse"], betrag=k["betrag"], bank="Gutschrift vom " + dmy(bank_datum[bid]))
                 for bid, k in sorted(karten.items(), key=lambda x: x[1]["dat"], reverse=True)
                 if k["kasse"] and k["dat"] >= start and (not monat or k["dat"][:7] == monat)]
    return page(BANK, monat=monat, summen=summen, info=info,
                credit_offen=credit_offen, credit_offen_summe=sum(c["betrag"] for c in credit_offen),
                credit_ok=credit_ok, credit_ok_summe=sum(c["betrag"] for c in credit_ok),
                offene_liste=offene_liste, offene_summe=sum(abs(r["brutto"] or 0) for r in offene_liste),
                bezahlte_liste=bezahlte_liste, bezahlte_summe=sum(abs(r["brutto"] or 0) for r in bezahlte_liste), ohne=ohne,
                ohne_summe=sum(abs(b["betrag"]) for b in ohne), ignoriert=ignoriert,
                bank_n=db().execute("SELECT COUNT(*) FROM bank").fetchone()[0], zurueck=request.full_path.rstrip("?"))


@app.route("/bank/aktualisieren", methods=["POST"])
def bank_aktualisieren():
    """Liest neue Dateien (Rechnungen, Kontoauszuege, Kassenbuecher) aus dem Eingangsordner und gleicht neu ab."""
    n = eingang_einlesen()
    neu_pruefen()  # unfertige Belege (z. B. Lieferant neu in der Liste) erneut zuordnen
    zahlungen_synchronisieren()
    flash(f"{n} neue Dateien eingelesen, Abgleich aktualisiert." if n else "Keine neuen Dateien - Abgleich aktualisiert.")
    monat = request.form.get("monat", "")
    return redirect(url_for("bank_seite", monat=monat) if monat else url_for("bank_seite"))


@app.route("/bank/ignorieren", methods=["POST"])
def bank_ignorieren():
    bid = request.form.get("bank_id", type=int)
    if bid:
        if request.form.get("aufheben"):
            db().execute("DELETE FROM bank_ignoriert WHERE bank_id=?", (bid,))
        else:
            db().execute("INSERT OR REPLACE INTO bank_ignoriert(bank_id, grund) VALUES(?,?)",
                         (bid, request.form.get("grund", "").strip()))
        db().commit()
    ziel = request.form.get("zurueck", "")
    return redirect(ziel if ziel.startswith("/bank") else url_for("bank_seite"))


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
<form method=post action="{{url_for('daten_pruefen')}}" class=card><input type=hidden name=m value="{{m}}">
<small>Ein Beleg gehört in den Monat seines <b>Rechnungsdatums</b>. Falsch eingelesene Daten (z. B. Einlesedatum statt Rechnungsdatum)
kannst du hier aus den PDFs neu lesen lassen.</small> <button class=sek>Rechnungsdaten prüfen</button></form>
<form method=post action="{{url_for('paket')}}" class=card>
<h2>Monatspaket für Unternehmen online</h2><input type=hidden name=m value="{{m}}">
<p>Fügt pro Belegart alle PDFs/Bilder von {{m}} zu <b>einer</b> PDF zusammen
(z. B. <code>{{m}}_Kassenbuch.pdf</code>) und legt sie in einen Ordner.
<b>E-Rechnungen</b> (PDF mit eingebetteter XML, z. B. deine Ausgangsrechnungen) werden dabei <b>nicht</b> zusammengefügt,
sondern einzeln als unveränderte Originale im Unterordner <code>E-Rechnungen</code> abgelegt, damit der XML-Anhang erhalten bleibt. Diese Dateien lädst du in
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
        liste_hochgeladen = False
        doppelt = []
        for i, b in enumerate(BELEGARTEN):
            for up in request.files.getlist(f"f{i}"):
                if not up.filename:
                    continue
                ext = Path(up.filename).suffix.lower()
                if ext not in ERLAUBT:
                    flash(f"{up.filename}: Dateityp nicht erlaubt.")
                    continue
                daten = up.read()
                dh = hashlib.sha1(daten).hexdigest()
                dup = db().execute("SELECT rechnungsnr, lieferant, datum FROM rechnungen WHERE hash=?", (dh,)).fetchone()
                if dup:
                    doppelt.append(f"{up.filename} (= {dup['rechnungsnr'] or dup['lieferant']} vom {dup['datum']})")
                    continue
                name = f"{uuid.uuid4().hex}{ext}"
                (BELEGE / name).write_bytes(daten)
                datum, nr, brutto, satz = ende, "", 0, 0
                kunde = b
                if b in AUSGANG_RECHNUNGEN and ext == ".pdf":
                    text = pdf_text(BELEGE / name)
                    datum, nr = finde_datum(text, ende), finde_nummer(text)
                    be = finde_endsumme(text)
                    if be is not None:
                        brutto, satz = be, finde_ausgang_satz(text)
                    ex = lese_erechnung(BELEGE / name)
                    if ex:
                        datum, nr = ex["datum"] or datum, ex["nr"] or nr
                        if ex["brutto"] is not None:
                            brutto, satz = ex["brutto"], ex["satz"]
                        kunde = ex["kaeufer"] or b
                cur = db().execute("INSERT INTO rechnungen(datum,lieferant,rechnungsnr,brutto,mwst_satz,kategorie,"
                             "konto,status,notiz,datei,guid,angelegt,belegart) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
                             (datum, kunde, nr, brutto, satz, "Sonstiges", "", "noch nicht gesendet", Path(up.filename).name, name,
                              str(uuid.uuid4()), datetime.now().isoformat(timespec="seconds"), b))
                db().execute("UPDATE rechnungen SET hash=? WHERE id=?", (dh, cur.lastrowid))
                n += 1
                liste_hochgeladen = liste_hochgeladen or b == "Rechnungsausgangliste"
        db().commit()
        flash(f"{n} Dateien gespeichert.")
        if doppelt:
            flash("Doppelt, nicht erneut gespeichert: " + "; ".join(doppelt))
        if liste_hochgeladen:
            fehlt, anzahl = fehlende_ausgangsrechnungen()
            flash(f"Rechnungsausgangsliste abgeglichen: {anzahl} Rechnungen, "
                  + (f"{len(fehlt)} fehlen noch." if fehlt else "alle vorhanden."))
            return redirect(url_for("abgleich"))
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


@app.route("/monat/daten-pruefen", methods=["POST"])
def daten_pruefen():
    """Liest bei Eingangs-/Ausgangsrechnungen das beschriftete Rechnungsdatum neu aus dem PDF (Monatszuordnung!)."""
    korrigiert = []
    for r in db().execute("SELECT id, datum, lieferant, rechnungsnr, datei, belegart FROM rechnungen WHERE datei IS NOT NULL "
                          "AND belegart IN (?,?,?,?)", (EINGANG, "Rechnungsausgang Service", "Rechnungsausgang Verkauf",
                                                         "Nicht zugeordnet")).fetchall():
        pfad = BELEGE / r["datei"]
        if not pfad.exists():
            continue
        ex = lese_erechnung(pfad)
        d = (ex["datum"] if ex and ex["datum"] else "") or finde_rechnungsdatum(pdf_text(pfad))
        if d and d != r["datum"]:
            db().execute("UPDATE rechnungen SET datum=? WHERE id=?", (d, r["id"]))
            korrigiert.append(f'{r["rechnungsnr"] or r["lieferant"]}: {r["datum"]} \u2192 {d}')
    db().commit()
    flash("Rechnungsdatum korrigiert bei " + str(len(korrigiert)) + " Belegen: " + "; ".join(korrigiert)
          if korrigiert else "Alle Rechnungsdaten stimmen mit den Belegen überein.")
    return redirect(url_for("monat", m=request.form.get("m", "")))


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
        slug = re.sub(r"[^A-Za-z0-9_.-]+", "_", f"{m}_{b}")
        erech = [r for r in rows if pdf_xml(BELEGE / r["datei"])]
        normal = [r for r in rows if r not in erech]
        if erech:  # E-Rechnungen: Originaldatei samt XML-Anhang unveraendert, nie zusammenfuegen
            (ziel / "E-Rechnungen").mkdir(exist_ok=True)
            for r in erech:
                nr = re.sub(r"[^A-Za-z0-9_.-]+", "_", r["rechnungsnr"] or str(r["id"]))
                shutil.copy2(BELEGE / r["datei"], ziel / "E-Rechnungen" / f"{slug}_{nr}.pdf")
            fertig.append(f"E-Rechnungen/{slug}_*.pdf ({len(erech)} Originale mit XML, einzeln)")
        w = PdfWriter()
        for r in normal:
            try:
                _in_pdf(w, BELEGE / r["datei"])
            except Exception as e:  # noqa: BLE001
                fehler.append(f'{r["notiz"] or r["datei"]}: {e}')
        if len(w.pages):
            name = slug + ".pdf"
            with open(ziel / name, "wb") as fh:
                w.write(fh)
            fertig.append(f"{name} ({len(normal)} Dateien, {(ziel / name).stat().st_size / 1e6:.1f} MB)")
        w.close()
        if not erech and not normal:
            continue
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
        felder = [_betrag(abs(r["brutto"])), "H" if r["brutto"] < 0 else "S", "EUR", "", "", "", r["konto"] or KATEGORIEN.get(r["kategorie"], "4980"), s["gegenkonto"], bu,
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
