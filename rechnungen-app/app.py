"""Rechnungsverwaltung mit DATEV-Export (lokal, SQLite).

Start:  py app.py   ->  http://127.0.0.1:5055
Daten:  data/rechnungen.db und data/belege/  (nicht in Git)
"""
import csv
import io
import os
import smtplib
import sqlite3
import uuid
import zipfile
from datetime import date, datetime
from email.message import EmailMessage
from pathlib import Path

from flask import (Flask, abort, flash, g, redirect, render_template_string,
                   request, send_file, url_for)
from werkzeug.utils import secure_filename

BASE = Path(__file__).resolve().parent
DATA = BASE / "data"
BELEGE = DATA / "belege"
DB = DATA / "rechnungen.db"
BELEGE.mkdir(parents=True, exist_ok=True)

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
STATUS = ["offen", "bezahlt", "an DATEV gesendet"]

SETTINGS_DEFAULT = {
    "beraternr": "", "mandantennr": "", "wj_beginn": f"{date.today().year}-01-01",
    "sachkontenlaenge": "4", "gegenkonto": "1600", "diktatkuerzel": "",
    "datev_mail": "", "smtp_host": "", "smtp_port": "587", "smtp_user": "",
    "smtp_pass": "", "absender": "",
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
body{font-family:Segoe UI,Arial,sans-serif;margin:0;background:#f4f1ec;color:#2b2118}
header{background:#3b2a1d;color:#fff;padding:12px 24px;display:flex;gap:24px;align-items:center}
header a{color:#f1d9b5;text-decoration:none;font-weight:600} header b{font-size:18px;margin-right:auto}
main{max-width:1150px;margin:20px auto;padding:0 16px}
table{border-collapse:collapse;width:100%;background:#fff} th,td{padding:7px 9px;border-bottom:1px solid #e6dfd5;text-align:left;font-size:14px}
th{background:#eadfce} td.r,th.r{text-align:right}
.card{background:#fff;padding:16px 20px;margin-bottom:18px;border-radius:6px}
label{display:block;font-size:13px;margin:8px 0 2px;font-weight:600}
input,select,textarea{padding:6px;font-size:14px;width:100%;box-sizing:border-box;border:1px solid #c9bda9;border-radius:4px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:0 16px}
button,.btn{background:#7a4a21;color:#fff;border:0;padding:8px 16px;border-radius:4px;font-size:14px;cursor:pointer;text-decoration:none;display:inline-block}
button.sek,.btn.sek{background:#8c8273} .msg{padding:10px 14px;margin-bottom:12px;background:#fff3cd;border-left:4px solid #e0a800}
.st-offen{color:#b45309}.st-bezahlt{color:#047857}.st-an{color:#1d4ed8} small{color:#6b5f52}
"""

LAYOUT = """<!doctype html><html lang=de><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1"><title>Rechnungen</title>
<style>{{css}}</style>
<header><b>&#9749; Rechnungen &amp; DATEV</b>
<a href="{{url_for('index')}}">Übersicht</a><a href="{{url_for('neu')}}">+ Neue Rechnung</a>
<a href="{{url_for('einstellungen')}}">Einstellungen</a></header><main>
{% for m in get_flashed_messages() %}<div class=msg>{{m}}</div>{% endfor %}
{{body|safe}}</main></html>"""


def page(body_tpl, **ctx):
    body = render_template_string(body_tpl, **ctx)
    return render_template_string(LAYOUT, css=CSS, body=body)


INDEX = """
<form method=get class=card style="display:flex;gap:12px;align-items:end">
 <div style="flex:1"><label>Suche</label><input name=q value="{{q}}" placeholder="Lieferant, Nummer, Notiz"></div>
 <div><label>Status</label><select name=status><option value="">alle</option>
  {% for s in STATUS %}<option {{'selected' if s==status}}>{{s}}</option>{% endfor %}</select></div>
 <button>Filtern</button></form>
<form method=post action="{{url_for('export')}}">
<table><tr><th></th><th>Datum</th><th>Lieferant</th><th>Rechnungsnr.</th><th>Kategorie</th>
<th class=r>Netto</th><th class=r>Brutto</th><th>Status</th><th>Beleg</th><th></th></tr>
{% for r in rows %}<tr>
 <td><input type=checkbox name=ids value="{{r.id}}" style="width:auto" {{'checked' if r.status!='an DATEV gesendet'}}></td>
 <td>{{r.datum}}</td><td>{{r.lieferant}}</td><td>{{r.rechnungsnr}}</td><td>{{r.kategorie}} <small>({{r.konto}})</small></td>
 <td class=r>{{'%.2f'|format(r.netto)|replace('.',',')}}</td><td class=r>{{'%.2f'|format(r.brutto)|replace('.',',')}}</td>
 <td class="st-{{ 'an' if r.status.startswith('an') else r.status }}">{{r.status}}</td>
 <td>{% if r.datei %}<a href="{{url_for('beleg',rid=r.id)}}" target=_blank>öffnen</a>{% else %}<small>fehlt</small>{% endif %}</td>
 <td><a href="{{url_for('bearbeiten',rid=r.id)}}">bearbeiten</a></td></tr>
{% else %}<tr><td colspan=10>Noch keine Rechnungen.</td></tr>{% endfor %}
<tr><th colspan=5 class=r>Summe ({{rows|length}})</th><th class=r>{{'%.2f'|format(sn)|replace('.',',')}}</th>
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
<div><label>Rechnungsdatum</label><input type=date name=datum value="{{r.datum}}" required></div>
<div><label>Lieferant</label><input name=lieferant value="{{r.lieferant}}" required></div>
<div><label>Rechnungsnummer</label><input name=rechnungsnr value="{{r.rechnungsnr}}"></div>
<div><label>Bruttobetrag (€)</label><input name=brutto value="{{'%.2f'|format(r.brutto)|replace('.',',') if r.brutto else ''}}" required></div>
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
    sql, par = "SELECT * FROM rechnungen WHERE 1=1", []
    if q:
        sql += " AND (lieferant LIKE ? OR rechnungsnr LIKE ? OR notiz LIKE ?)"
        par += [f"%{q}%"] * 3
    if status:
        sql += " AND status=?"
        par.append(status)
    rows = []
    for r in db().execute(sql + " ORDER BY datum DESC, id DESC", par):
        d = dict(r)
        d["netto"] = netto(r["brutto"], r["mwst_satz"])
        rows.append(type("R", (), d))
    return page(INDEX, rows=rows, q=q, status=status, STATUS=STATUS,
                sb=sum(r.brutto for r in rows), sn=sum(r.netto for r in rows))


def _speichern(rid=None):
    f = request.form
    try:
        brutto = float(f["brutto"].replace(".", "").replace(",", ".")) if "," in f["brutto"] \
            else float(f["brutto"])
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
    vals = (f["datum"], f["lieferant"].strip(), f["rechnungsnr"].strip(), brutto,
            float(f["mwst_satz"]), kat, konto, f["status"], f["notiz"].strip())
    if rid is None:
        db().execute("INSERT INTO rechnungen(datum,lieferant,rechnungsnr,brutto,mwst_satz,kategorie,"
                     "konto,status,notiz,datei,guid,angelegt) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
                     vals + (datei_name, str(uuid.uuid4()), datetime.now().isoformat(timespec="seconds")))
    else:
        db().execute("UPDATE rechnungen SET datum=?,lieferant=?,rechnungsnr=?,brutto=?,mwst_satz=?,"
                     "kategorie=?,konto=?,status=?,notiz=? WHERE id=?", vals + (rid,))
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
                           status="offen", notiz="", datei=None))
    return page(FORM, r=r, KAT=KATEGORIEN, STATUS=STATUS)


@app.route("/<int:rid>/bearbeiten", methods=["GET", "POST"])
def bearbeiten(rid):
    r = lade(rid)
    if request.method == "POST" and _speichern(rid):
        flash("Änderungen gespeichert.")
        return redirect(url_for("index"))
    return page(FORM, r=type("R", (), dict(r)), KAT=KATEGORIEN, STATUS=STATUS)


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
        z.writestr(f"EXTF_Buchungsstapel_{date.today():%Y%m%d}.csv", buchungsstapel_csv(rows, s))
        z.writestr("document.xml", document_xml(rows))
        for r in rows:
            if r["datei"]:
                z.write(BELEGE / r["datei"], r["datei"])
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
    app.run(host="127.0.0.1", port=5055, debug=False)
