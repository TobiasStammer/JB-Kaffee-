"""Startet die Rechnungs-App im eigenen Fenster (ohne Konsole, ohne Adressleiste).

Ablauf: Server im Hintergrund starten -> warten bis er antwortet -> Edge/Chrome im App-Modus
oeffnen -> beim Schliessen des Fensters alles beenden.
"""
import ctypes
import os
import socket
import subprocess
import sys
import threading
import time
import traceback
from pathlib import Path

BASE = Path(__file__).resolve().parent
os.chdir(BASE)
sys.path.insert(0, str(BASE))
PORT = 5055
URL = f"http://127.0.0.1:{PORT}/"
NOWIN = getattr(subprocess, "CREATE_NO_WINDOW", 0)


def meldung(text, titel="Rechnungen & DATEV"):
    ctypes.windll.user32.MessageBoxW(0, text, titel, 0x10)


def port_offen():
    with socket.socket() as s:
        s.settimeout(0.3)
        return s.connect_ex(("127.0.0.1", PORT)) == 0


def pakete_pruefen():
    try:
        import flask, pypdf, PIL  # noqa: F401,E401
    except ImportError:
        subprocess.run([sys.executable, "-m", "pip", "install", "-q", "flask", "pypdf", "pillow"],
                       creationflags=NOWIN, check=False)


def browser_finden():
    kandidaten = [
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    ]
    return next((k for k in kandidaten if Path(k).exists()), None)


def server_aktuell():
    """True, wenn der laufende Server dieselbe app.py-Version hat wie die Datei auf der Platte."""
    try:
        import urllib.request
        with urllib.request.urlopen(URL + "__stand", timeout=3) as r:
            return r.read().decode().strip() == str(os.path.getmtime(BASE / "app.py"))
    except Exception:  # noqa: BLE001  (alte Version ohne /__stand oder keine Antwort)
        return False


def alten_server_beenden():
    ps = (f"Get-NetTCPConnection -LocalPort {PORT} -State Listen -ErrorAction SilentlyContinue | "
          "ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }")
    subprocess.run(["powershell", "-NoProfile", "-Command", ps], creationflags=NOWIN, check=False)
    for _ in range(50):
        if not port_offen():
            return
        time.sleep(0.1)


def main():
    pakete_pruefen()
    if port_offen() and not server_aktuell():
        alten_server_beenden()
    if not port_offen():
        import app as A
        from werkzeug.serving import make_server
        A.init_db()
        try:
            Path(A.STANDARD_ORDNER).mkdir(parents=True, exist_ok=True)
        except OSError:
            pass
        threading.Thread(target=A._waechter, daemon=True).start()
        server = make_server("127.0.0.1", PORT, A.app, threaded=True)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        for _ in range(300):
            if port_offen():
                break
            time.sleep(0.1)
    browser = browser_finden()
    if not browser:
        os.startfile(URL)  # Notnagel: normaler Browser; Server laeuft weiter
        while True:
            time.sleep(60)
    profil = BASE / "data" / "fensterprofil"
    profil.mkdir(parents=True, exist_ok=True)
    subprocess.Popen([browser, f"--app={URL}", f"--user-data-dir={profil}", "--window-size=1280,900",
                      "--no-first-run", "--no-default-browser-check"])
    # Edge uebergibt das Fenster evtl. an einen schon laufenden Prozess und kehrt sofort zurueck.
    # Darum nicht auf Popen warten, sondern pruefen, ob noch ein Edge mit unserem Profil laeuft.
    ps = ("(Get-CimInstance Win32_Process -Filter \"Name='msedge.exe' OR Name='chrome.exe'\" | "
          "Where-Object { $_.CommandLine -like '*fensterprofil*' -and $_.CommandLine -notlike '*--type=*' }"
          " | Measure-Object).Count")
    gesehen, leer = False, 0
    start = time.time()
    while True:
        time.sleep(3)
        try:
            n = int(subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True,
                                   text=True, creationflags=NOWIN).stdout.strip() or 0)
        except Exception:  # noqa: BLE001
            n = 1
        if n:
            gesehen, leer = True, 0
        else:
            leer += 1
            if (gesehen and leer >= 2) or (not gesehen and time.time() - start > 30):
                os._exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception:  # noqa: BLE001
        (BASE / "data").mkdir(exist_ok=True)
        (BASE / "data" / "fehler.log").write_text(traceback.format_exc(), encoding="utf-8")
        meldung("Die App konnte nicht gestartet werden.\nDetails: data\\fehler.log")
