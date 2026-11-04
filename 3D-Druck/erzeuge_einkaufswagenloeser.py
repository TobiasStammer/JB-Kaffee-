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

STICKER_D = 25.0     # mm Durchmesser des NFC-Stickers
OBERTEIL_PLUS = 6.5  # mm: NFC-Varianten werden im oberen Teil um dieses Mass breiter (Hals/Logoteil bleiben)
BREIT_AB = 23.0      # mm von unten: ab hier wird verbreitert (Hals liegt bei ca. 21 mm)
BREIT_BIS = 36.0     # mm von unten: ab hier volle Breite (weicher Uebergang)
STICKER_SPIEL = 0.4  # mm Spiel um den Sticker (Tasche = Sticker + Spiel)
MARGIN = 1.8         # mm Mindest-Wandstaerke zwischen Tasche und Aussenkontur
LOGO2_BREITE = 19.0  # mm Logobreite im oberen Teil (NFC-unten-Varianten)
STICKER_FORMEN = {"rund25": ("kreis", 25.0), "rechteck10x20": ("rechteck", 20.0, 10.0)}
STICKER_Y = 43.0     # mm Mitte des Stickers von der Unterkante (Loch sitzt bei ca. 61,5 mm)
TASCHE_TIEFE = 0.6   # mm Tiefe der offenen Tasche (Sticker ca. 0,3-0,5 mm dick)
HOHLRAUM_Z = 1.0     # mm Boden unter dem eingeschlossenen Sticker; Druck-Pause bei dieser Hoehe
HOHLRAUM_H = 0.6     # mm Hoehe des Hohlraums (darüber bleiben DICKE-1,0-0,6 = 0,4 mm Deckel)

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


def vorschau(body, logo, loch, pfad, sticker=None):
    s = 12
    minx, miny, maxx, maxy = body.bounds
    im = Image.new("RGB", (int((maxx - minx) * s) + 40, int((maxy - miny) * s) + 40), "white")
    dr = ImageDraw.Draw(im)

    def pt(p):
        return [((x - minx) * s + 20, (maxy - y) * s + 20) for x, y in p.exterior.coords]

    dr.polygon(pt(body), fill=(200, 205, 212), outline=(40, 40, 40))
    for g in ([loch] if loch is not None else []):
        dr.polygon(pt(g), fill="white", outline=(40, 40, 40))
    if sticker is not None:
        dr.polygon(pt(sticker), fill=(235, 238, 242), outline=(180, 40, 40))
        cx, cy = sticker.centroid.x, sticker.centroid.y
        dr.text(((cx - minx) * s + 20 - 22, (maxy - cy) * s + 20 - 6), "NFC", fill=(180, 40, 40))
    geoms = logo.geoms if logo.geom_type == "MultiPolygon" else [logo]
    for g in geoms:
        dr.polygon(pt(g), fill=(51, 65, 85))
        for i in g.interiors:
            dr.polygon([((x - minx) * s + 20, (maxy - y) * s + 20) for x, y in i.coords], fill=(200, 205, 212))
    im.save(pfad)


def weich(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def nfc_unten(name, form, body, loch, achse, out):
    """Sticker im runden Kopf (unten), Logo im oberen Teil. Der Kopf wird nur so weit vergroessert wie noetig."""
    from shapely import segmentize
    from shapely.geometry import LineString, Point, box

    minx, miny, maxx, maxy = body.bounds
    bs = segmentize(Polygon(body.exterior), 0.3)

    def breite(y):
        return body.intersection(LineString([(minx - 5, y), (maxx + 5, y)])).length

    prof = [(miny + 3 + 0.25 * i, 0) for i in range(0, 4 * 37)]
    prof = [(y, breite(y)) for y, _ in prof]
    yc = max([p for p in prof if p[0] < miny + 18], key=lambda p: p[1])[0]
    yn = min([p for p in prof if yc + 3 < p[0] < yc + 25], key=lambda p: p[1])[0]

    def gross(S, D):
        k = D / (yn - yc)

        def f(x, y):
            if y <= yc:
                return (achse + (x - achse) * S, yc + (y - yc) * S)
            if y <= yn:
                u = (y - yc) / (yn - yc)
                ff = S + (1 - S) * weich(u)
                return (achse + (x - achse) * ff, yc + (y - yc) * (1 + k))
            return (x, y + D)

        dy = yc * (S - 1)
        kontur = Polygon([f(x, y) for x, y in bs.exterior.coords])
        kontur = affinity.translate(kontur, 0, dy)
        lochn = affinity.translate(loch, 0, D + dy)
        return Polygon(kontur.exterior, [lochn.exterior.coords]), lochn, yn + D + dy

    def pocket_poly(cx, cy, quer):
        if form[0] == "kreis":
            return Point(cx, cy).buffer((form[1] + STICKER_SPIEL) / 2, 64)
        w, h = form[1] + STICKER_SPIEL, form[2] + STICKER_SPIEL
        if not quer:
            w, h = h, w
        return box(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)

    best = None
    for si in range(0, 41):
        S = 1.0 + 0.02 * si
        for D in (0.0, 2.0, 4.0, 6.0):
            kb, lochn, yneck = gross(S, D)
            cand = None
            for yi in range(0, int((yc * S + 4 - 3) * 4)):
                yp = 3 + yi * 0.25   # Sticker bleibt im runden Kopf
                for quer in ((True, False) if form[0] == "rechteck" else (True,)):
                    pk = pocket_poly(achse, yp, quer)
                    if kb.contains(pk):
                        m = min(kb.exterior.distance(pk), lochn.distance(pk))
                        if cand is None or m > cand[0]:
                            cand = (m, pk)
            if cand and cand[0] >= MARGIN:
                best = (S, D, kb, lochn, yneck, cand[1], cand[0])
                break
        if best:
            break
    if not best:
        sys.exit("Keine passende Kopfgroesse gefunden (%s)" % name)
    S, D, kb, lochn, yneck, pk, m = best

    # Logo in den oberen Teil
    logo = lade_logo()
    f_ = LOGO2_BREITE / (logo.bounds[2] - logo.bounds[0])
    logo = affinity.scale(logo, f_, f_, origin=(0, 0))
    lh = logo.bounds[3] - logo.bounds[1]
    unten = max(pk.bounds[3], yneck) + 3.0
    oben = lochn.bounds[1] - 3.0
    logo = affinity.translate(logo, achse, (unten + oben) / 2)
    assert kb.contains(logo.buffer(1.5)), "Logo passt oben nicht (%s)" % name
    assert not pk.buffer(1.0).intersects(logo)
    kminx, kminy, kmaxx, kmaxy = kb.bounds
    print("%s: Kopf x%.2f, Hals +%.0f mm -> %.1f x %.1f mm, Wand %.1f mm, Logo %.1f mm hoch" % (name, S, D, kmaxx - kminx, kmaxy - kminy, m, lh))

    boden = trimesh.creation.extrude_polygon(kb, DICKE - TIEFE)
    teile = kb.difference(logo.buffer(SPIEL))
    teile = list(teile.geoms) if teile.geom_type == "MultiPolygon" else [teile]
    deckel = [trimesh.creation.extrude_polygon(t, TIEFE) for t in teile]
    for mm in deckel:
        mm.apply_translation([0, 0, DICKE - TIEFE])
    koerper = trimesh.boolean.union([boden] + deckel, engine="manifold")

    def prisma(z0, z1):
        pr = trimesh.creation.extrude_polygon(pk, z1 - z0)
        pr.apply_translation([0, 0, z0])
        return pr

    offen = trimesh.boolean.difference([koerper, prisma(DICKE - TASCHE_TIEFE, DICKE + 0.5)], engine="manifold")
    zu = trimesh.boolean.difference([koerper, prisma(HOHLRAUM_Z, HOHLRAUM_Z + HOHLRAUM_H)], engine="manifold")
    offen.export(os.path.join(out, "einkaufswagenloeser_JB_NFC-unten_%s_offene-tasche.stl" % name))
    zu.export(os.path.join(out, "einkaufswagenloeser_JB_NFC-unten_%s_eingeschlossen.stl" % name))
    print("   watertight: offen %s, eingeschlossen %s" % (offen.is_watertight, zu.is_watertight))
    vorschau(kb, logo, lochn, os.path.join(out, "vorschau_NFC-unten_%s.png" % name), pk)


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
    print("Körper watertight:", koerper.is_watertight, "Volumen %.0f mm³" % koerper.volume, "Einlage watertight:", einlage.is_watertight)

    for nm, fm in STICKER_FORMEN.items():
        nfc_unten(nm, fm, body, loch, achse, out)
    vorschau(body, logo, loch, os.path.join(out, "vorschau.png"))


if __name__ == "__main__":
    main()
