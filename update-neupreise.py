#!/usr/bin/env python3
"""update-neupreise.py - zieht Neupreise (Listen-/Herstellerpreise) fuer den Reparatur-Check.

Schreibt neupreise.json (wird von build-pages.ps1 in die Seite /reparatur-check/ eingebettet).

Automatisch abgerufen (bei jedem Lauf frisch):
  Jura      <- jura-products.json      (Preise von de.jura.com, siehe build-shop*.ps1)
  Nivona    <- nivona-products.json    (Preise von nivona.com)
  De Longhi <- delonghi.com/de-de      (Produkt-Sitemap -> JSON-LD "Product/Offer")
  Siemens   <- siemens-home.bsh-group.com (Sitemap -> JSON-LD)
  Bosch     <- bosch-home.com          (Sitemap -> JSON-LD)
  Melitta   <- melitta.de              (Sitemap -> JSON-LD)
  ECM, Profitec <- diecrema.de         (Shopify products.json, UVP = compare_at_price falls vorhanden)
  Sage      <- field-coffee.de         (Shopify products.json)

Manuell gepflegt (kein sauberer Abruf moeglich, z. B. Bot-Sperre / reines JS):
  neupreise-manuell.json  -> Struktur wie unten, mit Quelle + Stand je Eintrag.

Aufruf:   python3 update-neupreise.py            (alle Quellen)
          python3 update-neupreise.py delonghi   (nur diese Quelle, Rest bleibt aus der alten Datei)
Nur Standardbibliothek. Danach:  pwsh ./build-pages.ps1  (bettet die Preise ein).
"""
import gzip, json, os, re, subprocess, sys, time, datetime, html

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "neupreise.json")
MANUAL = os.path.join(ROOT, "neupreise-manuell.json")
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/17.0 Safari/605.1.15"


def fetch(url, binary=False, retries=2):
    for i in range(retries + 1):
        r = subprocess.run(["curl", "-s", "-L", "-A", UA, "--max-time", "40", url], capture_output=True)
        if r.returncode == 0 and r.stdout:
            return r.stdout if binary else r.stdout.decode("utf-8", "replace")
        time.sleep(1.5)
    return None


def jsonld_products(page):
    out = []
    for m in re.finditer(r'<script[^>]*application/ld\+json[^>]*>(.*?)</script>', page, re.S):
        try:
            x = json.loads(m.group(1))
        except Exception:
            continue
        for it in (x if isinstance(x, list) else [x]):
            if isinstance(it, dict) and it.get("@type") == "Product":
                out.append(it)
    return out


def offer_price(prod):
    o = prod.get("offers")
    if isinstance(o, list) and o:
        o = o[0]
    if isinstance(o, dict):
        p = o.get("price") or o.get("lowPrice")
        try:
            return float(str(p).replace(",", "."))
        except Exception:
            return None
    return None


def clean(s):
    s = html.unescape(s or "")
    s = s.replace("®", "").replace("™", "").replace("®", "")
    return re.sub(r"\s+", " ", s).strip()


def add(store, brand, label, price, url, code=""):
    """gleiche Modellbezeichnung (Farbvarianten) -> niedrigster Preis"""
    if not price or price < 50:
        return
    lst = store.setdefault(brand, {})
    cur = lst.get(label)
    if cur is None or price < cur["p"]:
        lst[label] = {"m": label, "p": round(price), "u": url, "c": code, "q": "auto"}


# ---------------------------------------------------------------- Quellen
def src_jura(store):
    d = json.load(open(os.path.join(ROOT, "jura-products.json"), encoding="utf-8-sig"))
    for it in d.get("haushalt", []):
        try:
            p = float(it.get("price") or 0)
        except Exception:
            p = 0
        name = clean(re.sub(r"\s*\([^)]*\)\s*$", "", it.get("name", ""))).replace("JURA ", "")
        add(store, "Jura", name, p, it.get("url", ""))


def src_nivona(store):
    d = json.load(open(os.path.join(ROOT, "nivona-products.json"), encoding="utf-8-sig"))
    for it in d.get("machines", []):
        try:
            p = float(it.get("price") or 0)
        except Exception:
            p = 0
        name = clean(it.get("name", "")).replace("NIVONA ", "").replace("'", "")
        add(store, "Nivona", name, p, it.get("url", ""))


def src_delonghi(store):
    sm = fetch("https://www.delonghi.com/de-de/sitemap-de-de-product-sitemap-0.xml")
    if not sm:
        print("  De'Longhi: Sitemap nicht erreichbar"); return
    urls = re.findall(r"<loc>([^<]+)</loc>", sm)
    urls = [u for u in urls if re.search(r"/(ECAM|EXAM|ESAM|EPAM|ETAM|FEB)[0-9]", u)
            and "second" not in u.lower() and "generaluberholt" not in u.lower()]
    seen = set()
    for u in urls:
        code = re.search(r"/((?:ECAM|EXAM|ESAM|EPAM|ETAM|FEB)[^/]*?)\.html", u)
        code = html.unescape(re.sub(r"%3A", ":", code.group(1))) if code else ""
        segs = code.split("+")[0].split(".")
        base = ".".join(segs[:-1]) if len(segs) > 2 and re.search(r"[A-Za-z]", segs[-1]) else ".".join(segs)
        if base in seen:
            continue
        seen.add(base)
        page = fetch(u)
        time.sleep(0.3)
        if not page:
            continue
        for pr in jsonld_products(page):
            price = offer_price(pr)
            name = clean(pr.get("name", ""))
            series = re.sub(r"\b(ECAM|EXAM|ESAM|EPAM|ETAM|FEB)[0-9A-Za-z.+:]*", "", name)
            series = re.sub(r"Kaffeevollautomat|Automatic|Espresso", "", series, flags=re.I).strip(" -")
            label = (series + " " + base.replace("ECAM", "ECAM ").replace("EXAM", "EXAM ").replace("ESAM", "ESAM ")
                     .replace("EPAM", "EPAM ").replace("ETAM", "ETAM ")).strip() if series else base
            if not series:
                fam = "Magnifica S" if re.match(r"(ECAM|ESAM)2[0-3]\.", base) else ""
                label = (fam + " " + re.sub(r"^(ECAM|ESAM)", r"\1 ", label)).strip()
            label = re.sub(r"\b(coffee maker|bean to cup coffee machine|automatische kaffeemaschine|kaffeemaschine|kaffeeautomat)\b", "",
                           label, flags=re.I)
            label = re.sub(r"\bEX ?:\d\b", "", label, flags=re.I)
            add(store, "De Longhi", re.sub(r"\s+", " ", label).strip(), price, u.split("?")[0], code)
            break


COLORS = r"(Silber|Schwarz|Edelstahl|Anthrazit|Wei[sß]|Grau|Champagner|Titan|Metallic|Dark|Inox|Blau|Rot|Gold|Bronze|Black|White|Silver)"


def src_bsh(store, brand, sitemap, filt):
    sm = fetch(sitemap)
    if not sm:
        print(f"  {brand}: Sitemap nicht erreichbar"); return
    urls = [u for u in re.findall(r"<loc>([^<]+)</loc>", sm) if "/product/kaffeemaschinen/kaffeevollautomaten" in u and filt(u)]
    seen = set()
    for u in urls:
        code = u.rstrip("/").split("/")[-1]
        if code in seen:
            continue
        seen.add(code)
        page = fetch(u)
        time.sleep(0.3)
        if not page:
            continue
        for pr in jsonld_products(page):
            price = offer_price(pr)
            name = clean(pr.get("name", ""))
            name = re.sub(r"^" + re.escape(code) + r"\s*", "", name)
            name = re.sub(r"Kaffeevollautomat\w*", "", name).strip()
            name = re.sub(r"(\s+" + COLORS + r"(\s*/\s*" + COLORS + r")*)+\s*$", "", name, flags=re.I).strip()
            name = re.sub(r"[,\s]+(Edelstahl|Klavierlack( schwarz)?|Silk|Diamond titanium|Diamond|titanium)[,\s]*", " ", name + " ", flags=re.I)
            name = re.sub(r"[,\s]+(Edelstahl|Klavierlack( schwarz)?|Silk|Diamond titanium|Diamond|titanium)\s*$", "", name.strip(), flags=re.I)
            name = re.sub(r"[\s,]+$", "", re.sub(r"\s+", " ", name)).strip()
            add(store, brand, name or code, price, u, code)
            break


def src_siemens(store):
    src_bsh(store, "Siemens", "https://www.siemens-home.bsh-group.com/de/sitemap.xml", lambda u: "/einbau" not in u)


def src_bosch(store):
    src_bsh(store, "Bosch", "https://www.bosch-home.com/de/sitemap.xml", lambda u: True)


def src_melitta(store):
    idx = fetch("https://www.melitta.de/sitemap.xml") or ""
    gz = re.search(r"https[^<]+\.gz", idx)
    if not gz:
        print("  Melitta: Sitemap nicht erreichbar"); return
    raw = fetch(gz.group(0), binary=True)
    try:
        sm = gzip.decompress(raw).decode("utf-8", "replace")
    except Exception:
        print("  Melitta: Sitemap nicht lesbar"); return
    urls = [u for u in re.findall(r"<loc>([^<]+)</loc>", sm)
            if re.search(r"melitta\.de/kaffeevollautomaten/[^/]+/[^/]+$", u)
            and not re.search(r"/(ersatzteile|maschinenpflege|service|zur-kaufberatung|refurbished)/|starterset", u)]
    seen = set()
    for u in urls:
        model = u.split("/")[-2]
        if model in seen:
            continue
        seen.add(model)
        page = fetch(u)
        time.sleep(0.3)
        if not page:
            continue
        for pr in jsonld_products(page):
            add(store, "Melitta", clean(pr.get("name", "")), offer_price(pr), u)
            break


def shopify(store, brand, url, keep, label_fn):
    raw = fetch(url)
    try:
        prods = json.loads(raw)["products"]
    except Exception:
        print(f"  {brand}: products.json nicht lesbar"); return
    for pr in prods:
        if not keep(pr):
            continue
        v = pr["variants"][0]
        try:
            price = float(v.get("compare_at_price") or v["price"])
        except Exception:
            continue
        add(store, brand, label_fn(pr["title"]), price, url.split("/collections/")[0] + "/products/" + pr["handle"])


def src_ecm(store):
    shopify(store, "ECM", "https://www.diecrema.de/collections/ecm-siebtrager/products.json?limit=250",
            lambda p: p.get("product_type") == "Espressomaschine" and p["title"].startswith("ECM"),
            lambda t: re.sub(r"^ECM\s+", "", t))


def src_profitec(store):
    shopify(store, "Profitec", "https://www.diecrema.de/collections/profitec/products.json?limit=250",
            lambda p: p.get("product_type") == "Espressomaschine" and p["title"].startswith("Profitec"),
            lambda t: re.sub(r"^Profitec\s+", "", t))


def src_sage(store):
    shopify(store, "Sage", "https://field-coffee.de/collections/sage/products.json?limit=250",
            lambda p: re.search(r"\bSES\d{3}\b", p["title"]) is not None,
            lambda t: re.sub(r"\s+with Cold Extraction", "", re.sub(r"^Sage\s+", "", t)))


SOURCES = {"jura": src_jura, "nivona": src_nivona, "delonghi": src_delonghi,
           "siemens": src_siemens, "bosch": src_bosch, "melitta": src_melitta,
           "ecm": src_ecm, "profitec": src_profitec, "sage": src_sage}
BRAND_OF = {"jura": "Jura", "nivona": "Nivona", "delonghi": "De Longhi", "siemens": "Siemens",
            "bosch": "Bosch", "melitta": "Melitta", "ecm": "ECM", "profitec": "Profitec", "sage": "Sage"}


def main():
    want = [a.lower() for a in sys.argv[1:]] or list(SOURCES)
    old = {}
    if os.path.exists(OUT):
        old = json.load(open(OUT, encoding="utf-8")).get("marken", {})
    store = {}
    for k in want:
        if k not in SOURCES:
            print("unbekannte Quelle:", k); continue
        print("->", k)
        SOURCES[k](store)
        print("   ", len(store.get(BRAND_OF[k], {})), "Modelle")
    marken = {}
    # nicht neu abgerufene Marken aus der alten Datei behalten
    for b, lst in old.items():
        if not any(BRAND_OF.get(k) == b for k in want):
            marken[b] = [x for x in lst if x.get("q") == "auto"]
    for b, d in store.items():
        marken[b] = list(d.values())
    # manuelle Eintraege dazu
    if os.path.exists(MANUAL):
        man = json.load(open(MANUAL, encoding="utf-8-sig"))
        for b, lst in man.get("marken", {}).items():
            marken.setdefault(b, [])
            marken[b] = [x for x in marken[b] if x.get("q") == "auto"] + [dict(x, q="manuell") for x in lst]
    for b in marken:
        marken[b].sort(key=lambda x: (x["p"], x["m"]))
    out = {"stand": datetime.date.today().isoformat(),
           "hinweis": "Aktuelle Listen-/Herstellerpreise als Richtwert. Bei aelteren Geraeten zaehlt der damalige Preis - bitte im Check anpassen.",
           "marken": marken}
    json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("geschrieben:", OUT, "-", sum(len(v) for v in marken.values()), "Modelle in", len(marken), "Marken")


if __name__ == "__main__":
    main()
