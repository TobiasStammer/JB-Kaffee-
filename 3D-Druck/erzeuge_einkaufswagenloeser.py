"""Erzeugt druckbare STL-Dateien fuer einen Einkaufswagenloeser (Form nach TR-280, ohne Flaschenoeffner)
mit eingelassenem JB-Logo. Quellen: TR-280_Standvorlage.pdf (Stanzkontur), JB_Firmenlogo.pdf (Vektorlogo).
Aufruf: python erzeuge_einkaufswagenloeser.py   (benoetigt pymupdf, shapely, trimesh, mapbox_earcut, manifold3d, pillow)
"""
import os
import sys
import warnings

warnings.filterwarnings("ignore")
import pymupdf
import trimesh
from PIL import Image, ImageDraw
from shapely import affinity
from shapely.geometry import Polygon
from shapely.ops import unary_union

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = r"Z:\Grafiken\Einkaufswagenlöser\TR-280_Standvorlage.pdf"
LOGO_PDF = r"Z:\Grafiken\Logo\JB_Firmenlogo.pdf"

DICKE = 2.0          # mm Gesamtdicke (passt in Muenzschlitze, 1 EUR = 2,33 mm)
TIEFE = 0.6          # mm Tiefe der Logo-Vertiefung
LOGO_BREITE = 17.0   # mm Breite des Logos
SPIEL = 0.0          # mm Spiel der Logo-Einlage (Zweifarbdruck), 0 = bündig

MM = 25.4 / 72.0


def flatten(items):
    """Pfad-Elemente der PDF-Zeichnung in Ringe (Punktlisten, pt) umwandeln."""
    rings, cur = [], []
    for it in items:
        k = it[0]
        if k == "l":
            pts = [it[1], it[2]]
        elif k == "c":
            p0, p1, p2, p3 = it[1:5]
            pts = []
            for i in range(0, 21):
                t = i / 20
                a = (1 - t) ** 3
                b = 3 * (1 - t) ** 2 * t
                c = 3 * (1 - t) * t ** 2
                d = t ** 3
                pts.append((a * p0.x + b * p1.x + c * p2.x + d * p3.x, a * p0.y + b * p1.y + c * p2.y + d * p3.y))
            pts = [pymupdf.Point(*q) for q in pts]
        elif k == "re":
            r = it[1]
            pts = [pymupdf.Point(r.x0, r.y0), pymupdf.Point(r.x1, r.y0), pymupdf.Point(r.x1, r.y1), pymupdf.Point(r.x0, r.y1), pymupdf.Point(r.x0, r.y0)]
        elif k == "qu":
            q = it[1]
            pts = [q.ul, q.ur, q.lr, q.ll, q.ul]
        else:
            continue
        if cur and (abs(cur[-1][0] - pts[0].x) > 0.01 or abs(cur[-1][1] - pts[0].y) > 0.01):
            rings.append(cur)
            cur = []
        if not cur:
            cur.append((pts[0].x, pts[0].y))
        for q in pts[1:]:
            cur.append((q.x, q.y))
    if cur:
        rings.append(cur)
    return rings


def rings_to_poly(rings):
    """Ringe per gerade-ungerade Regel zu einem Polygon (Loecher durch XOR)."""
    res = None
    for r in rings:
        if len(r) < 3:
            continue
        p = Polygon(r).buffer(0)
        res = p if res is None else res.symmetric_difference(p)
    return res


def lade_kontur():
    page = pymupdf.open(TEMPLATE)[0]
    best = None
    for d in page.get_drawings():
        r = d["rect"]
        # Stanzkontur der "Vorderseite": 25 x 66 mm, magenta Strich, links auf der Seite
        if d.get("color") and abs(r.width * MM - 25) < 0.6 and abs(r.height * MM - 66) < 0.6 and r.x0 < 200 and d.get("fill"):
            best = d
            break
    if best is None:
        sys.exit("Stanzkontur nicht gefunden")
    poly = rings_to_poly(flatten(best["items"]))
    poly = affinity.scale(poly, MM, -MM, origin=(0, 0))
    minx, miny, _, _ = poly.bounds
    return affinity.translate(poly, -minx, -miny)


def ohne_flaschenoeffner(poly):
    """Kerbe entfernen: unbeschädigte Haelfte (linke Seite) an der Mittelachse spiegeln."""
    outer = Polygon(poly.exterior)
    loecher = list(poly.interiors)
    minx, miny, maxx, maxy = outer.bounds
    achse = None
    if loecher:
        h = Polygon(loecher[0]).centroid
        achse = h.x
    else:
        achse = (minx + maxx) / 2
    links = outer.intersection(Polygon([(minx - 5, miny - 5), (achse, miny - 5), (achse, maxy + 5), (minx - 5, maxy + 5)]))
    rechts = affinity.scale(links, -1, 1, origin=(achse, 0))
    sym = unary_union([links, rechts]).buffer(0.01).buffer(-0.01)
    if sym.geom_type != "Polygon":
        sym = max(sym.geoms, key=lambda g: g.area)
    return Polygon(sym.exterior), achse


def lade_logo():
    page = pymupdf.open(LOGO_PDF)[0]
    for d in page.get_drawings():
        r = d["rect"]
        if d.get("fill") == (1.0, 1.0, 1.0) and 200 < r.width < 240 and 120 < r.height < 140:
            poly = rings_to_poly(flatten(d["items"]))
            poly = affinity.scale(poly, MM, -MM, origin=(0, 0))
            minx, miny, maxx, maxy = poly.bounds
            poly = affinity.translate(poly, -(minx + maxx) / 2, -(miny + maxy) / 2)
            return poly
    sys.exit("Logo nicht gefunden")


def vorschau(body, logo, loch, pfad):
    s = 12
    minx, miny, maxx, maxy = body.bounds
    im = Image.new("RGB", (int((maxx - minx) * s) + 40, int((maxy - miny) * s) + 40), "white")
    dr = ImageDraw.Draw(im)

    def pt(p):
        return [((x - minx) * s + 20, (maxy - y) * s + 20) for x, y in p.exterior.coords]

    dr.polygon(pt(body), fill=(200, 205, 212), outline=(40, 40, 40))
    for g in ([loch] if loch is not None else []):
        dr.polygon(pt(g), fill="white", outline=(40, 40, 40))
    geoms = logo.geoms if logo.geom_type == "MultiPolygon" else [logo]
    for g in geoms:
        dr.polygon(pt(g), fill=(51, 65, 85))
        for i in g.interiors:
            dr.polygon([((x - minx) * s + 20, (maxy - y) * s + 20) for x, y in i.coords], fill=(200, 205, 212))
    im.save(pfad)


def main():
    orig = lade_kontur()
    body, achse = ohne_flaschenoeffner(orig)
    loch = Polygon(list(orig.interiors)[0]) if list(orig.interiors) else None
    if loch is not None:
        body_mit_loch = Polygon(body.exterior, [loch.exterior.coords])
    else:
        body_mit_loch = body
    minx, miny, maxx, maxy = body.bounds
    print("Maße Körper: %.1f x %.1f mm, Achse x=%.2f, Loch: %s" % (maxx - minx, maxy - miny, achse,
          ("Ø %.1f mm" % ((loch.bounds[2] - loch.bounds[0])) if loch is not None else "keins")))

    # Logo in den unteren, runden Teil setzen
    logo = lade_logo()
    f = LOGO_BREITE / (logo.bounds[2] - logo.bounds[0])
    logo = affinity.scale(logo, f, f, origin=(0, 0))
    unten = miny + 10.3                       # Mittelpunkt des unteren, runden Teils
    logo = affinity.translate(logo, achse, unten)
    assert body_mit_loch.contains(logo.buffer(1.5)), "Logo passt nicht in den Körper"

    # Netze
    boden = trimesh.creation.extrude_polygon(body_mit_loch, DICKE - TIEFE)
    rand = body_mit_loch.difference(logo.buffer(SPIEL))
    teile = list(rand.geoms) if rand.geom_type == "MultiPolygon" else [rand]
    deckel = [trimesh.creation.extrude_polygon(t, TIEFE) for t in teile]
    for m in deckel:
        m.apply_translation([0, 0, DICKE - TIEFE])
    koerper = trimesh.boolean.union([boden] + deckel, engine="manifold")
    teile = list(logo.geoms) if logo.geom_type == "MultiPolygon" else [logo]
    einlagen = [trimesh.creation.extrude_polygon(t, TIEFE) for t in teile]
    for m in einlagen:
        m.apply_translation([0, 0, DICKE - TIEFE])
    einlage = trimesh.util.concatenate(einlagen)

    out = os.path.join(HERE)
    koerper.export(os.path.join(out, "einkaufswagenloeser_JB_koerper.stl"))
    einlage.export(os.path.join(out, "einkaufswagenloeser_JB_logo-einlage.stl"))
    kombi = trimesh.util.concatenate([koerper, einlage])
    print("Körper watertight:", koerper.is_watertight, "Volumen %.0f mm³" % koerper.volume, "Einlage watertight:", einlage.is_watertight)
    vorschau(body, logo, loch, os.path.join(out, "vorschau.png"))


if __name__ == "__main__":
    main()
