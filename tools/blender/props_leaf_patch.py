"""Tache de feuilles mortes a plat (~1 m x 1 m, epaisseur max 4 cm)."""
from props_util import *


def make_patch(name, seed, palette, lumps_n=3, leaves_n=40, size=1.0, preview_pitch=48):
    reset_scene()
    rnd = random.Random(seed)
    R = size * 0.5
    lumps = []
    ang0 = rnd.uniform(0, 6.28)
    for i in range(lumps_n):
        a = ang0 + 2 * math.pi * i / lumps_n + rnd.uniform(-0.4, 0.4)
        d = R * rnd.uniform(0.15, 0.5)
        lumps.append((math.cos(a) * d, math.sin(a) * d, R * rnd.uniform(0.40, 0.65), R * rnd.uniform(0.32, 0.55),
                      rnd.uniform(0.016, 0.024), rnd.choice(palette)))

    def hgt(x, y):
        h = 0.0
        for (cx, cy, rx, ry, hz, _) in lumps:
            q = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if q < 1:
                h = max(h, hz * (1 - q) ** 0.55)
        return h

    base = Mesh()
    for i, (cx, cy, rx, ry, hz, m) in enumerate(lumps):
        base.blob((cx, cy, hz * 0.18), (rx, ry, hz * 0.95), m, subdiv=1, noise=0.12, seed=seed + i * 3.1,
                  bottom=0.18, quat=Quaternion((0, 0, 1), rnd.uniform(0, 3.14)))
    leaves = Mesh()
    n = 0
    tries = 0
    while n < leaves_n and tries < 400:
        tries += 1
        a = rnd.uniform(0, 6.28)
        r = math.sqrt(rnd.random()) * R * 1.05
        x, y = math.cos(a) * r * 0.95, math.sin(a) * r
        h = hgt(x, y)
        if h < 0.006 and rnd.random() < 0.6:
            continue
        kind = "star" if rnd.random() < 0.2 else "lens"
        L = rnd.uniform(0.09, 0.14)
        tilt = Vector((rnd.uniform(-0.14, 0.14), rnd.uniform(-0.14, 0.14), 1.0)).normalized()
        z = min(h * 0.85 + rnd.uniform(0.004, 0.009), 0.024)
        z = max(z, 0.5 * L * math.sqrt(1 - tilt.z ** 2) + 0.003)
        add_leaf(leaves, (x, y, z), tilt, rnd.uniform(0, 6.28), L, L * (0.6 if kind == "lens" else 0.9),
                 rnd.choice(palette), kind=kind, t=0.0035, curl=0.006)
        n += 1
    base.build(name + "_base")
    leaves.build(name + "_leaves")
    pfinish(name, expected_dims=(1.0, 1.0, 0.04), tri_limit=(20, 800),
            angles={name + "_base": math.radians(60), name + "_leaves": math.radians(60)},
            yaw=25, pitch=preview_pitch, margin=1.0)
