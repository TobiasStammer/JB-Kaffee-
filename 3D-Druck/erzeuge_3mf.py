"""Fasst Koerper + Logo-Einlage zu einer 3MF-Datei fuer den Zweifarbdruck zusammen.
Die 3MF enthaelt EIN Objekt mit zwei Teilen (Koerper, Logo), die im Slicer je einem Filament zugewiesen werden.
Aufruf: python erzeuge_3mf.py   (benoetigt trimesh; liest die STL-Dateien aus diesem Ordner)
"""
import os
import zipfile

import trimesh

HERE = os.path.dirname(os.path.abspath(__file__))
FARBEN = {"koerper": "#C8CDD4FF", "logo": "#2F3E52FF"}


def mesh_xml(oid, name, m, pindex):
    v = "".join('<vertex x="%.5f" y="%.5f" z="%.5f"/>' % tuple(p) for p in m.vertices)
    t = "".join('<triangle v1="%d" v2="%d" v3="%d"/>' % tuple(f) for f in m.faces)
    return ('<object id="%d" name="%s" type="model" pid="1" pindex="%d"><mesh><vertices>%s</vertices><triangles>%s</triangles></mesh></object>'
            % (oid, name, pindex, v, t))


def schreibe_3mf(pfad, koerper, logo, name):
    modell = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<model unit="millimeter" xml:lang="de-DE" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">'
        '<metadata name="Title">%s</metadata>'
        '<resources>'
        '<basematerials id="1"><base name="Koerper" displaycolor="%s"/><base name="Logo" displaycolor="%s"/></basematerials>'
        '%s%s'
        '<object id="3" name="%s" type="model"><components><component objectid="2"/><component objectid="4"/></components></object>'
        '</resources><build><item objectid="3"/></build></model>'
    ) % (name, FARBEN["koerper"], FARBEN["logo"],
         mesh_xml(2, "Koerper", koerper, 0), mesh_xml(4, "Logo", logo, 1), name)
    rels = ('<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/></Relationships>')
    ctype = ('<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
             '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
             '<Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/></Types>')
    with zipfile.ZipFile(pfad, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", ctype)
        z.writestr("_rels/.rels", rels)
        z.writestr("3D/3dmodel.model", modell)


def main():
    for nm in ("rechteck10x20", "rund25"):
        pk = os.path.join(HERE, "einkaufswagenloeser_JB_NFC_%s_logo-ueber-sticker.stl" % nm)
        pl = os.path.join(HERE, "einkaufswagenloeser_JB_NFC_%s_logo-einlage.stl" % nm)
        if not (os.path.exists(pk) and os.path.exists(pl)):
            continue
        k = trimesh.load(pk)
        l = trimesh.load(pl)
        out = os.path.join(HERE, "einkaufswagenloeser_JB_NFC_%s_2farben.3mf" % nm)
        schreibe_3mf(out, k, l, "Einkaufswagenloeser JB NFC %s" % nm)
        print(os.path.basename(out), "%.0f kB" % (os.path.getsize(out) / 1024), "Teile:", len(k.faces), len(l.faces))


if __name__ == "__main__":
    main()
