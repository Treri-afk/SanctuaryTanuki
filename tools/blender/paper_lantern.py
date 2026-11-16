"""Lanterne de papier suspendue (chochin) : 0,34 m de diametre x 0,57 m de haut. ORIGINE = point d'accroche (haut de
l'anneau), le modele pend vers -Z.
- corps en washi tendu sur 22 baguettes : le papier se creuse un peu entre deux baguettes (plis doux, comme une
  vraie lanterne pliante), un seul blanc casse : ce sont les formes qui font les lignes, pas des bandes de couleur ;
- calligraphie a l'encre peinte sur le papier, qui en epouse la courbure. Deux variantes :
  paper_lantern        : « 月見 » (Tsukimi) devant, « 祭 » derriere — la fete, les stands ;
  paper_lantern_shrine : « 御神燈 » (lumiere sacree) des deux cotes — les lanternes du sanctuaire, tous les jours ;
- calottes en bois laque noir (kuchiwa), liserees d'un filet dore ; le papier rentre dedans ;
- anse en fer qui enjambe la calotte du haut et porte l'anneau de suspension ; petit bouton laque dessous.
Le soir, le jeu fait luire les materiaux clairs (le papier) ; l'encre et le laque restent sombres.
Police : Hiragino Mincho (macOS). Lancer : blender --background --python tools/blender/paper_lantern.py [-- variante ...]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from trail_util import *
from glyph_util import glyph_mesh

## variante -> [(texte, hauteur de la colonne, epaisseur du trait)] pour l'avant puis l'arriere
VARIANTS = {
    "paper_lantern": [("月見", 0.235, 0.024), ("祭", 0.13, 0.03)],
    "paper_lantern_shrine": [("御神燈", 0.27, 0.02), ("御神燈", 0.27, 0.02)],
}
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
NAME = args[0] if args else "paper_lantern"
reset_scene()
N = 24                            # cotes du tour
# ---------------------------------------------------------------- dimensions (m ; z negatif = vers le bas)
RING_C, RING_R, RING_T = -0.022, 0.016, 0.0042    # anneau de suspension : centre, rayon, epaisseur
CAP_R = 0.088                     # rayon exterieur des calottes
TOP0, TOP1 = -0.082, -0.124       # calotte du haut : dessus / dessous
BOT0, BOT1 = -0.508, -0.548       # calotte du bas : dessus / dessous
ZT, ZB = -0.116, -0.516           # papier, du haut au bas (rentre de 8 mm dans chaque calotte)
RC, RMAX = 0.080, 0.170           # rayon du papier aux calottes / au ventre
RIBS = 22                         # baguettes
GROOVE = 0.0042                   # creux du papier entre deux baguettes
ZM = (ZT + ZB) / 2
HH = (ZT - ZB) / 2


def r_env(z):
    """Silhouette (sommet des baguettes) : ronde au ventre, qui se resserre en douceur vers les calottes."""
    u = max(-1.0, min(1.0, (z - ZM) / HH))
    return RC + (RMAX - RC) * (1 - u * u) ** 0.5


# ---------------------------------------------------------------- corps de papier, plisse entre les baguettes
rib_z = [ZT - (ZT - ZB) * k / RIBS for k in range(RIBS + 1)]   # la premiere et la derniere sont dans les calottes
prof = []
for k in range(RIBS):
    z0, z1 = rib_z[k], rib_z[k + 1]
    for t in (0.0, 1 / 3, 2 / 3):
        z = z0 + (z1 - z0) * t
        dip = GROOVE * math.sin(math.pi * t) ** 1.5 * min(1.0, r_env(z) / RMAX * 1.3)
        prof.append((r_env(z) - dip, z))
prof.append((r_env(ZB), ZB))
b = Mesh()
b.lathe(prof[::-1], N, "paper", cap0=True, cap1=True)


# ---------------------------------------------------------------- calligraphie posee sur le papier
def paint(m, text, a0, zc, height, bold, mat, lift=0.0034):
    verts, faces = glyph_mesh(text, height, bold)
    out = []
    for (x, y) in verts:
        z = zc + y
        r = r_env(z) + lift
        a = a0 + x / r
        out.append((r * math.cos(a), r * math.sin(a), z))
    m.add(out, faces, mat)


ink = Mesh()
FRONT, BACK = -math.pi / 2, math.pi / 2       # -Y = avant
for (txt, hgt, bold), side in zip(VARIANTS[NAME], (FRONT, BACK)):
    paint(ink, txt, side, ZM + 0.003, hgt, bold, "lacquer_black")

# ---------------------------------------------------------------- calottes laquees, filet dore
c = Mesh()
c.lathe([(0.0, TOP1), (CAP_R - 0.006, TOP1), (CAP_R, TOP1 + 0.006), (CAP_R, TOP0 - 0.008),
         (CAP_R - 0.009, TOP0), (0.045, TOP0 + 0.005), (0.0, TOP0 + 0.007)], N, "lacquer_black")
c.lathe([(0.0, BOT1 - 0.007), (0.045, BOT1 - 0.005), (CAP_R - 0.009, BOT1), (CAP_R, BOT1 + 0.008),
         (CAP_R, BOT0 - 0.006), (CAP_R - 0.006, BOT0), (0.0, BOT0)], N, "lacquer_black")
c.lathe([(0.0, BOT1 - 0.03), (0.011, BOT1 - 0.027), (0.015, BOT1 - 0.016), (0.011, BOT1 - 0.006),
         (0.0, BOT1 - 0.006)], 12, "lacquer_black")
g = Mesh()
for zc in ((TOP0 + TOP1) / 2 - 0.004, (BOT0 + BOT1) / 2 + 0.004):
    g.lathe([(CAP_R + 0.0008, zc - 0.0025), (CAP_R + 0.0018, zc), (CAP_R + 0.0008, zc + 0.0025)], N, "metal_gold",
            cap0=False, cap1=False)

# ---------------------------------------------------------------- anse en fer et anneau de suspension
h = Mesh()
apex = RING_C - RING_R                      # l'anse passe dans le bas de l'anneau
foot = TOP0 + 0.003
arc = []
for k in range(15):
    ang = math.pi * k / 14
    arc.append((-0.066 * math.cos(ang), 0.0, foot + (apex - foot) * math.sin(ang) ** 0.8))
h.tube(arc, [0.0032] * len(arc), 6, "metal")
for x in (-0.066, 0.066):                   # pattes de l'anse, plantees dans la calotte
    h.tube([(x, 0, foot + 0.004), (x, 0, foot - 0.012)], [0.0055, 0.0055], 8, "lacquer_black")
torus(h, (0, 0, RING_C), RING_R, RING_T, "metal", axis="y", nmaj=16, nmin=6)

body = b.build("lantern_body")
text = ink.build("lantern_ink")
caps = c.build("lantern_caps")
gold = g.build("lantern_gold")
hang = h.build("hanging_ring")
empty("hang_point", (0, 0, 0), size=0.05)

parts = [body, text, caps, gold, hang]
tri_report(parts)
lan = join(parts, "paper_lantern")

tfinish(NAME, expected_dims=(0.35, 0.35, 0.57), tri_limit=(400, 9000), origin="top",
        angles={"paper_lantern": math.radians(50)}, lift_preview=0.62, yaw=12, pitch=6, margin=1.1,
        extra_views=[("_b", dict(yaw=-40, pitch=-10, margin=1.1))])
