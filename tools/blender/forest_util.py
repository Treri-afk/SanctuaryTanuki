"""Helpers de l'agent foret : palette foret, lathe lobee (etages de coniferes), blobs orientables,
troncs tordus. S'appuie sur veg_utils (Builder, finish) sans toucher common.py."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from veg_utils import *

# ---------------------------------------------------------------- palette foret
PALETTE.update({
    "foliage_green":       "#3F5A32",
    "foliage_green_light": "#5C7A3A",
    "foliage_deep_green":  "#2B4129",
    "foliage_olive":       "#4C5E31",   # cedre variante b
    "foliage_dry":         "#6E5230",   # etage mourant
    "pine_green":          "#3A5238",
    "pine_green_light":    "#587448",
    "bark_cedar":          "#6B4A36",
    "bark_pine":           "#5A3F33",
    "bamboo_green":        "#7C9A4A",
    "bamboo_node":         "#5E7A38",
    "bamboo_leaf":         "#6E9444",
    "foliage_light":       "#E8AA3E",
    "foliage_deep":        "#9E3524",
})

V = Vector


def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def lathe(b, center, profile, m, sides=16, lobes=((5, 0.12, 0.0), (3, 0.07, 1.3)), droop=0.0,
          bite=None, wobble=0.0, seed=0):
    """Solide de revolution lobee. profile = [(r, z)...] de haut en bas, r=0 -> sommet unique.
    lobes = (k, amplitude relative, phase) : modulation du rayon selon l'angle.
    droop : affaissement (m) des pointes de lobes. bite = (angle, demi-largeur, facteur) : secteur arrache."""
    cx, cy, cz = center
    rmax = max(p[0] for p in profile)
    verts, faces, rings = [], [], []
    for (r, z) in profile:
        if r <= 1e-6:
            verts.append((cx, cy, cz + z))
            rings.append([len(verts) - 1])
            continue
        ring = []
        for j in range(sides):
            a = 2 * math.pi * j / sides
            mod = 1.0 + sum(amp * math.sin(k * a + ph) for k, amp, ph in lobes)
            mod *= 1.0 + wobble * math.sin(1.7 * z + seed + 2 * a)
            if bite:
                ba, hw, fac = bite
                d = abs((a - ba + math.pi) % (2 * math.pi) - math.pi)
                if d < hw:
                    mod *= fac + (1 - fac) * smoothstep(d / hw)
            rr = r * mod
            lobe = 0.5 + 0.5 * math.sin(lobes[0][0] * a + lobes[0][2]) if lobes else 0.5
            zz = z - droop * (r / rmax) ** 2 * lobe
            verts.append((cx + rr * math.cos(a), cy + rr * math.sin(a), cz + zz))
            ring.append(len(verts) - 1)
        rings.append(ring)
    for i in range(len(rings) - 1):
        a, c = rings[i], rings[i + 1]
        for j in range(sides):
            j2 = (j + 1) % sides
            if len(a) == 1 and len(c) == 1:
                continue
            if len(a) == 1:
                faces.append((a[0], c[j2], c[j]))
            elif len(c) == 1:
                faces.append((a[j], a[j2], c[0]))
            else:
                faces.append((a[j], a[j2], c[j2], c[j]))
    b.add(verts, faces, m)


def blob_rot(b, center, scale, m, rot=(0, 0, 0), subdiv=2, noise=0.08, seed=0, bottom=0.6):
    """Comme Builder.blob mais avec rotation euler (rad) appliquee apres deformation."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    from mathutils import Euler
    R = Euler(rot, "XYZ").to_matrix()
    cx, cy, cz = center
    for v in bm.verts:
        x, y, z = v.co
        k = 1.0 + noise * (math.sin(3.1 * x + seed) * math.cos(2.7 * y + seed * 1.7)
                           + 0.7 * math.sin(3.6 * z + seed * 0.6) + 0.5 * math.sin(2.3 * (x + y) + seed))
        z2 = z * (bottom if z < 0 else 1.0)
        p = R @ Vector((x * k * scale[0], y * k * scale[1], z2 * k * scale[2]))
        v.co = (cx + p.x, cy + p.y, cz + p.z)
    bm.verts.ensure_lookup_table()
    verts = [tuple(v.co) for v in bm.verts]
    faces = [tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    b.add(verts, faces, m)


def cedar_tier(b, center, R, H, m, sides=18, seed=0, bite=None, droop=0.35, lobes=None):
    """Un etage de cedre : dome pointu, bord arrondi retombant, dessous concave. center = base (z du bord bas)."""
    prof = [(0.0, H), (0.16 * R, 0.93 * H), (0.38 * R, 0.78 * H), (0.62 * R, 0.56 * H), (0.84 * R, 0.30 * H),
            (0.97 * R, 0.08 * H), (R, -0.05 * H), (0.88 * R, -0.09 * H), (0.62 * R, -0.04 * H), (0.34 * R, 0.07 * H),
            (0.0, 0.14 * H)]
    if lobes is None:
        lobes = ((5, 0.13, seed * 1.3), (3, 0.08, seed * 0.7 + 1.0), (7, 0.04, seed))
    lathe(b, center, prof, m, sides=sides, lobes=lobes, droop=droop, bite=bite, wobble=0.04, seed=seed)


def trunk_path(zs, sway=(0.0, 0.0), lean=(0.0, 0.0), freq=0.35, phase=0.0):
    """Points de tronc avec leger balancement : renvoie [(x,y,z)]."""
    pts = []
    for z in zs:
        x = lean[0] * z + sway[0] * math.sin(freq * z + phase)
        y = lean[1] * z + sway[1] * math.cos(freq * z * 0.8 + phase)
        pts.append((x, y, z))
    return pts


def roots(b, n, R0, z0, m, seed=0, length=0.9, sides=6, rr=0.2, base=(0.0, 0.0), taper=(1.0, 0.6, 0.25)):
    """Racines apparentes autour de la base."""
    for k in range(n):
        a = 2 * math.pi * k / n + 0.4 + 0.5 * math.sin(k * 2.3 + seed)
        L = length * (1.0 + 0.3 * math.sin(k * 1.7 + seed))
        ca, sa = math.cos(a), math.sin(a)
        bx, by = base
        pts = [(bx + R0 * 0.55 * ca, by + R0 * 0.55 * sa, z0 + 0.4),
               (bx + (R0 + 0.3 * L) * ca, by + (R0 + 0.3 * L) * sa, z0 + 0.14),
               (bx + (R0 + L) * ca, by + (R0 + L) * sa, 0.06)]
        b.tube(pts, [rr * t for t in taper], sides=sides, m=m)


def ground_clamp(b, z=0.0):
    """Aplatit au sol (z min = 0) les sommets qui passent sous le sol."""
    b.v = [(x, y, max(z, zz)) for (x, y, zz) in b.v]
