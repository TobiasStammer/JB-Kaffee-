"""Winkelverbinder 90 Grad fuer 2 Holzstaebe (Rundstab 18 mm). Ausgabe: STL (mm)."""
import trimesh, numpy as np
from trimesh.creation import cylinder, icosphere

STAB = 18.0        # Stabdurchmesser
SPIEL = 0.3        # Passungsspiel (Loch = 18.3); bei engem Drucker 0.2, locker 0.4
WAND = 4.0         # Wandstaerke
TIEFE = 35.0       # Einstecktiefe
RI = (STAB + SPIEL) / 2
RA = RI + WAND
SEG = 96

def zyl(r, l, achse):
    c = cylinder(radius=r, height=l, sections=SEG)
    # Zylinder von 0..l entlang Achse
    c.apply_translation([0, 0, l / 2])
    if achse == 'x':
        c.apply_transform(trimesh.transformations.rotation_matrix(np.pi/2, [0,1,0]))
    else:
        c.apply_transform(trimesh.transformations.rotation_matrix(-np.pi/2, [1,0,0]))
    return c

L = TIEFE + RA                      # Aussenlaenge ab Eckpunkt
aussen = trimesh.boolean.union([zyl(RA, L, 'x'), zyl(RA, L, 'y'),
                                icosphere(subdivisions=4, radius=RA)], engine='manifold')
# Loecher: von den Enden her TIEFE tief
loch_x = zyl(RI, TIEFE, 'x'); loch_x.apply_translation([L - TIEFE, 0, 0])
loch_y = zyl(RI, TIEFE, 'y'); loch_y.apply_translation([0, L - TIEFE, 0])
# kleine Fase am Eingang
teil = trimesh.boolean.difference([aussen, loch_x, loch_y], engine='manifold')
# flach auf Druckbett legen (Z=0 = Unterseite), Verbinder liegt in der XY-Ebene
teil.apply_translation([0, 0, -teil.bounds[0][2]])
teil.export('holzstab_winkelverbinder_18mm.stl')
print(teil.is_watertight, teil.bounds, round(teil.volume/1000,1), 'cm3')
