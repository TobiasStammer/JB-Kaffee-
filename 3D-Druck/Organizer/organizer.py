"""Parametrische Schrank-Organizer-Boxen (offene Schubfaecher) -> STL.
Koordinaten: x = Breite, y = Tiefe (0 = Front), z = Hoehe. Einheit mm.
Aufruf: python organizer.py            (erzeugt alle Standard-Module)
        python organizer.py 306 92     (Breite, Hoehe)
"""
import sys, os, numpy as np, trimesh as tm

T = 2.4          # Wandstaerke
FLOOR = 2.4      # Bodenstaerke
D = 248.0        # Tiefe der Box (max. fuer 256-mm-Druckbett inkl. Schildhalter)
LW, LH = 60.0, 20.0   # Beschriftungsschild (Papier) in mm
COVER, SLOT = 0.8, 1.0

def box(x0, x1, y0, y1, z0, z1):
    b = tm.creation.box(extents=(x1-x0, y1-y0, z1-z0))
    b.apply_translation(((x0+x1)/2, (y0+y1)/2, (z0+z1)/2))
    return b

def ell_y(cx, cz, a, b, y0, y1):
    c = tm.creation.cylinder(radius=1, height=y1-y0, sections=64)
    c.apply_transform(tm.transformations.rotation_matrix(np.pi/2, (1, 0, 0)))  # Achse -> y
    c.apply_scale((a, 1, b))
    c.apply_translation((cx, (y0+y1)/2, cz))
    return c

def make(W, H, label=True):
    shell = box(0, W, 0, D, 0, H)
    shell = shell.difference(box(T, W-T, T, D-T, FLOOR, H+1))
    # Greifmulde vorn
    scoop = min(H*0.40, 45.0)
    a = min(W*0.22, 50.0)
    shell = shell.difference(ell_y(W/2, H, a, scoop, -1, T+1))
    if label:
        hw, hh = LW+8, LH+6
        zt = H - scoop - 6            # Oberkante Schildhalter
        zb = zt - hh
        if zb < 4: zb = 4; zt = zb+hh
        x0 = (W-hw)/2
        t = COVER+SLOT
        holder = box(x0, x0+hw, -t, 0.01, zb, zt)
        # Einschubtasche von oben (Papier zwischen Deckblech und Frontwand)
        slot = box((W-LW-1)/2, (W+LW+1)/2, -SLOT, 0.0, zb+2, zt+1)
        holder = holder.difference(slot)
        # Sichtfenster
        win = box((W-LW+4)/2, (W+LW-4)/2, -t-1, -SLOT+0.01, zb+5, zt-5)
        holder = holder.difference(win)
        shell = shell.union(holder)
    return shell

def export(W, H, outdir):
    m = make(W, H)
    assert m.is_watertight, "nicht wasserdicht"
    name = f"Fach_B{int(W)}_H{int(H)}.stl"
    m.export(os.path.join(outdir, name))
    print(name, m.bounds[1]-m.bounds[0], "watertight", m.is_watertight)

if __name__ == "__main__":
    out = os.path.dirname(os.path.abspath(__file__))
    if len(sys.argv) == 3:
        export(float(sys.argv[1]), float(sys.argv[2]), out)
    else:
        # Breiten teilen 750 mm gleichmaessig: 5x148, 3x247 (je ~6-10 mm Luft)
        # Hoehen: 92 / 108 flach (2 bzw. 3 uebereinander), 185 (20er-Fach), 320 (35er-Fach)
        for W in (148, 247):
            for H in (92, 108, 185, 320):
                export(W, H, out)
