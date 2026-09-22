#!/usr/bin/env python3
"""Fluent Form #2 (Wartungserinnerung): Nutzung (privat/gewerblich) + Monat/Jahr als Auswahl.
Rollback: scratchpad/wartung-form-v1-backup.json ueber POST /fluentform/v1/forms/2 (formFields) zurueckspielen."""
import copy, datetime, json, urllib.request, base64, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
kv = {}
for l in open(os.path.join(ROOT, "kaffeetechniker-integration.env"), encoding="utf-8"):
    l = l.strip()
    if l and not l.startswith("#") and "=" in l:
        k, v = l.split("=", 1); kv[k.strip()] = v.strip()
base = kv["WP_URL"].rstrip("/")
tok = base64.b64encode(f"{kv['WP_APP_USER']}:{kv['WP_APP_PASSWORD'].replace(' ', '')}".encode()).decode()

def call(path, method="GET", body=None):
    r = urllib.request.Request(base + path, method=method, data=json.dumps(body).encode() if body is not None else None,
                               headers={"Authorization": "Basic " + tok, "Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(r, timeout=60))

form = call("/wp-json/fluentform/v1/forms/2")
ff = json.loads(form["form_fields"])
by = {f["attributes"].get("name"): f for f in ff["fields"]}
name, email, hers, cons = by["name"], by["email"], by["hersteller"], by["einwilligung"]

REQ = lambda msg: {"required": {"message": msg, "value": True}}
radio = {
    "index": 3, "element": "input_radio",
    "attributes": {"type": "radio", "name": "nutzung", "value": ""},
    "settings": {"container_class": "", "label": "Wie wird das Gerät genutzt?", "admin_field_label": "Nutzung", "label_placement": "",
                 "display_type": "", "help_message": "Gewerblich genutzte Geräte sollten jährlich gewartet werden, private alle zwei Jahre.",
                 "validation_rules": REQ("Bitte auswählen"), "conditional_logics": [],
                 "advanced_options": [{"label": "Privathaushalt", "value": "privat", "calc_value": "", "image": "", "id": 1},
                                      {"label": "Gewerblich (Büro, Gastronomie)", "value": "gewerblich", "calc_value": "", "image": "", "id": 2}]},
    "editor_options": {"title": "Radio Field", "icon_class": "ff-edit-radio", "element": "input-radio", "template": "inputRadio"},
    "uniqElKey": "el_nutzung"}

def select(idx, nm, label, ph, opts, key):
    f = copy.deepcopy(hers)
    f["index"] = idx
    f["attributes"] = {"value": "", "name": nm, "id": "", "class": "", "placeholder": ph, "multiple": False}
    f["settings"]["label"] = label
    f["settings"]["admin_field_label"] = label
    f["settings"]["help_message"] = ""
    f["settings"]["advanced_options"] = [{"value": v, "label": l} for v, l in opts]
    f["settings"]["validation_rules"] = REQ("Bitte auswählen")
    f["uniqElKey"] = key
    return f

MON = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
y = datetime.date.today().year
monat = select(4, "wartung_monat", "Letzte Wartung oder Kauf – Monat", "Monat wählen", [(f"{i+1:02d}", m) for i, m in enumerate(MON)], "el_wmonat")
jahr = select(5, "wartung_jahr", "Letzte Wartung oder Kauf – Jahr", "Jahr wählen", [(str(j), str(j)) for j in range(y, y - 15, -1)], "el_wjahr")
monat["settings"]["help_message"] = "Wenn unbekannt: das ungefähre Kaufdatum."
cons["index"] = 6
cons["attributes"]["value"] = []   # Einwilligung darf nicht vorangekreuzt sein (DSGVO)
cons["settings"]["advanced_options"][0]["label"] = ("Ich möchte per E-Mail an die nächste Wartung erinnert werden. Die Daten werden nur dafür genutzt; "
    "die Erinnerung kann jederzeit über den Link in der E-Mail beendet werden.")
for i, f in enumerate((name, email, hers)):
    f["index"] = i
ff["fields"] = [name, email, hers, radio, monat, jahr, cons]
res = call("/wp-json/fluentform/v1/forms/2", "POST", {"title": "Wartungserinnerung", "formFields": json.dumps(ff, ensure_ascii=False)})
print("Formular gespeichert:", res.get("title") if isinstance(res, dict) else res)

# Benachrichtigung an die Werkstatt + Bestaetigung (ohne falsches "in zwei Jahren")
notif = call("/wp-json/fluentform/v1/settings/2?meta_key=notifications")[0]
v = notif["value"]
v["message"] = ("<p>Neue Anmeldung zur Wartungserinnerung:</p><p><b>Name:</b> {inputs.name}<br><b>E-Mail:</b> {inputs.email}<br>"
                "<b>Kaffeemaschine:</b> {inputs.hersteller}<br><b>Nutzung:</b> {inputs.nutzung}<br>"
                "<b>Letzte Wartung / Kauf:</b> {inputs.wartung_monat}/{inputs.wartung_jahr}</p>"
                "<p>Fällig: 2 Jahre (privat) bzw. 1 Jahr (gewerblich) nach der letzten Wartung.</p>")
call("/wp-json/fluentform/v1/settings/2", "POST", {"form_id": 2, "meta_key": "notifications", "meta_id": notif["id"], "value": json.dumps(v, ensure_ascii=False)})
fs = call("/wp-json/fluentform/v1/settings/2?meta_key=formSettings")[0]
c = fs["value"]
c["confirmation"]["messageToShow"] = ("Vielen Dank! Wir haben Ihre Anmeldung zur Wartungserinnerung erhalten und erinnern Sie rechtzeitig vor der nächsten Wartung. "
                                      "Tipp: Tragen Sie sich den Termin oben zusätzlich in Ihren eigenen Kalender ein.")
call("/wp-json/fluentform/v1/settings/2", "POST", {"form_id": 2, "meta_key": "formSettings", "meta_id": fs["id"], "value": json.dumps(c, ensure_ascii=False)})
chk = json.loads(call("/wp-json/fluentform/v1/forms/2")["form_fields"])
for f in chk["fields"]:
    print(" ", f["attributes"].get("name"), "|", f["settings"].get("label"))
