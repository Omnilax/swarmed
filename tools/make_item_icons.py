# Generates inventory icons for items and writes content/sprites/items.lua.
#   python3 tools/make_item_icons.py                 (needs numpy)
#   python3 tools/make_item_icons.py --preview out.png [ids...]   (also needs Pillow)
# One inventory cell = 28x28 pixels (tools/icon_render.py RES). Each icon is modelled from lit 3D
# primitives (ellipsoids E, tubes T, bevelled slabs P) with real materials, so items read as
# natural objects in the dusk light rather than flat cartoon shapes. Coordinates are in cells.
import math, sys
from icon_render import Icon, RES, quantize

ICONS = []

def icon(iid, cols, rows, shape=None, seed=1):
    def deco(fn):
        ICONS.append((iid, cols, rows, shape, seed, fn))
        return fn
    return deco

pi = math.pi
import random
import numpy as np


def R(seed): return random.Random(seed)


def hairs(I, n, region, col, length=0.07, r=0.01, seed=1, angle=None, mode="on"):
    """Bristles scattered over region(x, y) -> bool inside a box (x0, y0, x1, y1)."""
    rnd = R(seed)
    test, (x0, y0, x1, y1) = region
    k = 0
    while k < n:
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        if not test(x, y): continue
        a = angle if angle is not None else rnd.uniform(0, 2 * pi)
        a += rnd.uniform(-0.4, 0.4)
        I.add(I.T([(x, y), (x + math.cos(a) * length, y + math.sin(a) * length)], [r, r * 0.4]), col, mode=mode, gloss=0.1, mottle=0.2)
        k += 1


def in_ell(cx, cy, rx, ry):
    return (lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 < 1, (cx - rx, cy - ry, cx + rx, cy + ry))


def leg(I, pts, rs, col, gloss=0.5, joint=None, **kw):
    """Jointed arthropod leg: tube segments with a swollen joint at each bend."""
    I.add(I.T(pts, rs), col, gloss=gloss, shin=22, **kw)
    for (x, y), r in zip(pts[1:-1], rs[1:-1]):
        I.add(I.E(x, y, r * 1.25, r * 1.25), joint or col, gloss=gloss, shin=22, mode="max")


def speck(I, n, region, col, size=(0.015, 0.03), seed=2, amt=1.0):
    """Paint small spots (pores, flecks, grit) without changing the shape."""
    rnd = R(seed)
    test, (x0, y0, x1, y1) = region
    k = 0
    while k < n:
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        if not test(x, y): continue
        s = rnd.uniform(*size)
        I.paint(I.E(x, y, s, s * rnd.uniform(0.6, 1)), col, amt=amt)
        k += 1

# ---------------------------------------------------------------------------------------------
# Original items

@icon("chitin_plate", 2, 2)
def chitin_plate(I):            # a beetle's wing case: a long curved shield, striated and pitted
    pts = [(0.35, 0.12), (0.75, 0.08), (1.3, 0.3), (1.75, 0.85), (1.88, 1.4), (1.7, 1.85), (1.35, 1.82), (0.85, 1.4), (0.4, 0.8), (0.22, 0.35)]
    I.add(I.P(pts, bevel=0.45, z=0.28), "#3e2616", gloss=1.2, shin=34, mottle=0.18)
    for k in range(5):
        o = (k - 2) * 0.13
        I.carve(I.T([(0.45 + o * 0.6, 0.3 - o * 0.4), (1.0 + o * 0.7, 0.85 - o * 0.6), (1.45 + o * 0.6, 1.5 - o * 0.4)], 0.018), 0.03)
    speck(I, 90, (lambda x, y: True, (0.4, 0.3, 1.7, 1.7)), "#1e120a", seed=3, size=(0.008, 0.014), amt=0.7)
    I.paint(I.T([(0.4, 0.25), (1.0, 0.7), (1.5, 1.3)], 0.2), "#6a4428", amt=0.35, soft=1)
    I.add(I.T([(0.3, 0.2), (0.9, 0.9), (1.4, 1.62), (1.62, 1.82)], 0.035), "#2a180c", mode="on", gloss=1.4, shin=30)

@icon("glass_mandible", 1, 2)
def glass_mandible(I):          # a translucent, glassy curved jaw
    pts = [(0.4, 1.9), (0.36, 1.5), (0.4, 1.1), (0.52, 0.7), (0.68, 0.38), (0.84, 0.16)]
    I.add(I.T(pts, [0.2, 0.2, 0.17, 0.13, 0.08, 0.03]), "#9cc4d8", gloss=1.6, shin=50, mottle=0.08, op=0.75)
    for y in (1.3, 1.0, 0.75):
        I.add(I.E(0.28 + (1.9 - y) * 0.08, y, 0.05, 0.035), "#d8f0ff", mode="on", gloss=1.4, shin=40, op=0.85)
    I.paint(I.T([(0.48, 1.7), (0.5, 1.0), (0.66, 0.5)], 0.03), "#e8f8ff", amt=0.6)
    I.glow(I.T([(0.42, 1.6), (0.46, 1.0)], 0.06), "#203848", 1)

@icon("static_antenna", 1, 2)
def static_antenna(I):          # an elbowed beetle antenna, crackling
    I.add(I.E(0.5, 1.82, 0.2, 0.12), "#3a2c20", gloss=0.4)
    leg(I, [(0.5, 1.78), (0.46, 1.1), (0.62, 0.8)], [0.06, 0.05, 0.05], "#5a4430")
    for i in range(7):
        t = i / 6
        I.add(I.E(0.62 + t * 0.18, 0.78 - t * 0.6, 0.075 + t * 0.02, 0.05), "#6e5236", gloss=0.6, shin=20, mode="over")
    for pts in ([(0.2, 0.3), (0.32, 0.42), (0.22, 0.55), (0.3, 0.7)], [(0.85, 0.95), (0.74, 1.1), (0.86, 1.25)]):
        I.add(I.T(pts, 0.012), "#fff6b0", emit="#fff090", gloss=0)

@icon("sugar_cube", 1, 1)
def sugar_cube(I):              # a crystalline sugar cube, top lit
    I.add(I.P([(0.18, 0.32), (0.55, 0.16), (0.86, 0.3), (0.86, 0.72), (0.5, 0.9), (0.16, 0.72)], bevel=0.06, z=0.05), "#e8e4dc", gloss=0.4, mottle=0.06)
    I.paint(I.P([(0.18, 0.32), (0.55, 0.16), (0.86, 0.3), (0.5, 0.46)]), "#fffcf4", amt=0.8)
    I.paint(I.P([(0.5, 0.46), (0.86, 0.3), (0.86, 0.72), (0.5, 0.9)]), "#a8a4a8", amt=0.6)
    I.carve(I.T([(0.5, 0.46), (0.5, 0.9)], 0.015), 0.01)
    speck(I, 30, (lambda x, y: True, (0.2, 0.25, 0.85, 0.85)), "#ffffff", seed=5, size=(0.008, 0.014))

@icon("dew_drop", 1, 1)
def dew_drop(I):
    I.add(I.F(lambda X, Y: _drop(X, Y, 0.5, 0.6, 0.29)), "#4a7ea8", gloss=1.8, shin=60, mottle=0.04, op=0.8)
    I.paint(I.E(0.58, 0.74, 0.17, 0.1), "#a8d8f8", amt=0.6, soft=1)
    I.glow(I.E(0.58, 0.74, 0.13, 0.08), "#3a5a7a", 1)
    I.add(I.E(0.39, 0.5, 0.05, 0.035, rot=-0.6), "#ffffff", mode="on", gloss=1, emit="#c0d8f0")

def _drop(X, Y, cx, cy, r):
    dx, dy = X - cx, Y - cy
    d = np.sqrt(dx * dx + dy * dy)
    tip = (dy < 0) & (np.abs(dx) < (dy + r * 1.6) * 0.62) & (dy > -r * 1.6)
    m = (d < r) | tip
    prof = np.clip(r * r - d * d, 0, None) ** 0.5
    prof = np.where(tip & (d >= r), (r * 1.6 + dy) * 0.25, prof)
    return m, np.maximum(prof, 0)

@icon("ember_gland", 1, 1)
def ember_gland(I):             # a hot, veined gland glowing from inside
    I.add(I.T([(0.5, 0.25), (0.48, 0.1)], [0.08, 0.05]), "#4a2a1c", gloss=0.3)
    I.add(I.E(0.5, 0.56, 0.34, 0.32), "#8a2a10", gloss=0.9, shin=30, mottle=0.15, emit="#3a0800")
    I.glow(I.E(0.52, 0.6, 0.24, 0.2), "#ff7a20", 0.9)
    for pts in ([(0.3, 0.45), (0.42, 0.55), (0.4, 0.75)], [(0.6, 0.3), (0.62, 0.5), (0.75, 0.62)], [(0.45, 0.35), (0.55, 0.45)]):
        I.paint(I.T(pts, 0.014), "#ffc060", amt=0.9)
        I.glow(I.T(pts, 0.014), "#ff9a30", 0.8)

@icon("grasshopper_legs", 1, 3)
def grasshopper_legs(I):        # the big jumping hind leg: herringbone femur, spined tibia
    I.add(I.E(0.5, 0.95, 0.24, 0.82, rot=-0.08), "#56722c", gloss=0.4, mottle=0.18)
    for y in np.linspace(0.3, 1.6, 12):
        I.carve(I.T([(0.34, y), (0.5, y + 0.08), (0.66, y)], 0.012), 0.025)
    I.paint(I.E(0.58, 1.3, 0.1, 0.4), "#8a3a2a", amt=0.35, soft=1)
    leg(I, [(0.52, 1.75), (0.42, 2.4), (0.36, 2.85)], [0.07, 0.05, 0.04], "#4a6224")
    for y in np.linspace(1.95, 2.75, 7):
        x = 0.52 - (y - 1.75) * 0.15
        I.add(I.T([(x + 0.04, y), (x + 0.11, y - 0.05)], [0.012, 0.004]), "#c8c090", mode="over", gloss=0.4)
    I.add(I.T([(0.36, 2.85), (0.48, 2.92), (0.6, 2.9)], 0.025), "#3a4a1c")

@icon("honeydew", 1, 1)
def honeydew(I):                # a bead of sticky amber honeydew
    I.add(I.F(lambda X, Y: _drop(X, Y, 0.5, 0.6, 0.3)), "#b8700c", gloss=1.6, shin=50, op=0.9, emit="#2a1400")
    I.paint(I.E(0.56, 0.74, 0.2, 0.12), "#f0b030", amt=0.7, soft=1)
    I.glow(I.E(0.56, 0.72, 0.16, 0.1), "#a05a00", 1)
    I.add(I.E(0.4, 0.5, 0.05, 0.035, rot=-0.6), "#fff0c0", mode="on", gloss=1, emit="#b08040")

@icon("termite_mandible", 1, 3, ["X", "X", "X"])
def termite_mandible(I):        # a long saber jaw of a soldier termite
    pts = [(0.42, 2.85), (0.4, 2.3), (0.42, 1.7), (0.5, 1.1), (0.62, 0.6), (0.76, 0.25), (0.84, 0.1)]
    I.add(I.T(pts, [0.2, 0.18, 0.15, 0.12, 0.09, 0.05, 0.02]), "#7a3e18", gloss=1.0, shin=30, mottle=0.15)
    I.paint(I.T(pts[3:], 0.1), "#2e140a", amt=0.7, soft=0.6)
    for y in np.linspace(1.3, 2.4, 6):
        x = 0.42 - (y - 1.3) * 0.02
        I.add(I.T([(x - 0.1, y), (x - 0.2, y - 0.06)], [0.03, 0.008]), "#3a1c0c", mode="over", gloss=0.8)

@icon("dragonfly_wings", 3, 2, ["XX.", ".XX"])
def dragonfly_wings(I):         # two clear, net-veined wings with dark pterostigma, on a thorax stub
    for root, tip in (((1.42, 0.78), (0.1, 0.42)), ((1.58, 1.22), (2.9, 1.58))):
        dx, dy = tip[0] - root[0], tip[1] - root[1]
        L = math.hypot(dx, dy); ux, uy = dx / L, dy / L; nx, ny = -uy, ux
        if ux < 0: nx, ny = -nx, -ny
        def at(t, w): return (root[0] + dx * t + nx * w, root[1] + dy * t + ny * w)
        ts = np.linspace(0, 1, 14)
        wid = [0.08 + 0.2 * math.sin(min(1, t * 1.15) * pi) ** 0.5 for t in ts]
        outline = [at(t, -w * 0.55) for t, w in zip(ts, wid)] + [at(t, w) for t, w in reversed(list(zip(ts, wid)))]
        I.add(I.P(outline, bevel=0.05, z=0.02), "#c4d4d8", gloss=1.8, shin=50, op=0.4, mottle=0.2, mscale=0.3)
        I.paint(I.E(*at(0.8, 0.05), 0.3, 0.2), "#b0a0d0", amt=0.3, soft=1)
        veins = [I.T([at(t, -w * 0.55), at(t + 0.03, w)], 0.008) for t, w in zip(np.linspace(0.04, 0.96, 22), np.interp(np.linspace(0.04, 0.96, 22), ts, wid))]
        for f in (-0.5, -0.1, 0.3, 0.7):
            veins.append(I.T([at(t, w * f) for t, w in zip(ts, wid)], 0.006 if f < 0 else 0.005))
        veins.append(I.T([at(t, -w * 0.55) for t, w in zip(ts, wid)], 0.012))
        for v in veins:
            I.paint(v, "#1e2428", amt=0.95); I.set(v, op=1.0)
        st = I.E(*at(0.86, -0.04), 0.07, 0.03, rot=math.atan2(dy, dx))
        I.paint(st, "#1a1410"); I.set(st, op=1.0)
    I.add(I.E(1.5, 1.0, 0.2, 0.22), "#2a4a3e", gloss=1.4, shin=34)
    I.paint(I.E(1.46, 0.95, 0.08, 0.08), "#4a7a5a", amt=0.6)

@icon("scarab_shell", 3, 2, ["XXX", ".X."])
def scarab_shell(I):            # metallic green scarab elytra with a head and horn
    I.add(I.E(1.5, 0.5, 1.38, 0.44, z=0.8), "#1e5a3a", gloss=1.6, shin=40, mottle=0.2)
    I.carve(I.T([(1.5, 0.1), (1.5, 0.92)], 0.025), 0.06)
    for x in (0.6, 0.95, 2.05, 2.4):
        I.carve(I.T([(x, 0.2), (x + (x - 1.5) * 0.05, 0.8)], 0.012), 0.02)
    I.paint(I.E(1.0, 0.36, 0.5, 0.18), "#3ea070", amt=0.5, soft=1)
    I.add(I.E(1.5, 1.2, 0.36, 0.3), "#143e28", gloss=1.4, shin=30)
    I.add(I.T([(1.5, 1.2), (1.5, 1.6), (1.56, 1.88)], [0.12, 0.08, 0.025]), "#0e2a1a", gloss=1.2, shin=30)

@icon("hornet_stinger", 2, 2, ["X.", "XX"])
def hornet_stinger(I):          # banded hornet abdomen tip and its curved sting
    I.add(I.E(0.75, 1.42, 0.62, 0.42, rot=0.2), "#c08a10", gloss=0.7, shin=24, mottle=0.12)
    for k in range(3):
        I.paint(I.E(0.75 + (k - 1) * 0.36, 1.42 + (k - 1) * 0.07, 0.08, 0.42, rot=0.2), "#2a1a08", amt=0.95)
        I.carve(I.E(0.93 + (k - 1) * 0.36, 1.45 + (k - 1) * 0.07, 0.015, 0.38, rot=0.2), 0.03)
    hairs(I, 30, in_ell(0.75, 1.42, 0.55, 0.36), "#d8b070", length=0.05, r=0.006, seed=9)
    I.add(I.T([(0.3, 1.2), (0.3, 0.8), (0.38, 0.45), (0.5, 0.14)], [0.08, 0.05, 0.03, 0.008]), "#2a1a0e", gloss=1.4, shin=40)
    I.add(I.E(0.51, 0.12, 0.035, 0.035), "#c8e870", mode="on", gloss=1.4, emit="#3a5010", op=0.9)

@icon("royal_jelly", 2, 2)
def royal_jelly(I):             # a wax queen cell brimming with pearly jelly
    I.add(I.F(lambda X, Y: _hex(X, Y, 1.0, 1.0, 0.92)), "#b07a20", gloss=0.4, mottle=0.15)
    I.carve(I.F(lambda X, Y: _hex(X, Y, 1.0, 1.0, 0.74)), 0.12)
    I.add(I.E(1.0, 1.02, 0.6, 0.55, z=0.5), "#e8dcb8", base=0.02, gloss=1.4, shin=36, mottle=0.06, op=0.95)
    I.paint(I.E(0.85, 0.85, 0.3, 0.22), "#fff8e4", amt=0.7, soft=1)
    I.glow(I.E(1.05, 1.1, 0.4, 0.35), "#3a3020", 1)

def _hex(X, Y, cx, cy, r):
    dx, dy = np.abs(X - cx), np.abs(Y - cy)
    m = (dx <= r) & (dy <= r * 0.87) & (dx * 0.5 + dy * 0.87 <= r * 0.87)
    return m, np.where(m, r - np.maximum(dx, dy / 0.87) * 0 - np.maximum(dx * 0.5 + dy * 0.87, dy), 0).clip(0) * 0 + np.where(m, 0.05, 0)

@icon("firefly_lantern", 1, 2)
def firefly_lantern(I):         # firefly abdomen: dark segments and a glowing lantern
    I.add(I.E(0.5, 0.36, 0.26, 0.28), "#3a2a1e", gloss=0.6, shin=24)
    I.paint(I.E(0.5, 0.3, 0.14, 0.14), "#c04a2a", amt=0.7)
    I.add(I.E(0.5, 1.15, 0.32, 0.72), "#2e2418", gloss=0.5)
    for y in (0.75, 0.95, 1.15):
        I.carve(I.T([(0.2, y), (0.8, y)], 0.015), 0.03)
    I.add(I.E(0.5, 1.55, 0.29, 0.33), "#e8f080", mode="over", gloss=0.6, emit="#a0a020")
    I.glow(I.E(0.5, 1.55, 0.29, 0.33), "#f8ff90", 1.0)

@icon("four_leaf_clover", 1, 1)
def four_leaf_clover(I):        # a real clover: heart-shaped leaflets with pale chevrons
    for a in (0.25, 1.82, 3.39, 4.96):
        cx, cy = 0.5 + math.cos(a) * 0.2, 0.47 + math.sin(a) * 0.2
        for s in (-0.42, 0.42):
            I.add(I.E(cx + math.cos(a + s) * 0.05, cy + math.sin(a + s) * 0.05, 0.13, 0.11, rot=a + s, z=0.3), "#2e6a24", gloss=0.35, mottle=0.15, mode="max")
        I.paint(I.T([(0.5 + math.cos(a) * 0.1, 0.47 + math.sin(a) * 0.1), (cx + math.cos(a) * 0.05, cy + math.sin(a) * 0.05)], 0.035), "#9ac080", amt=0.5)
    I.add(I.T([(0.5, 0.48), (0.56, 0.7), (0.66, 0.9)], 0.025), "#3a5a20", mode="over")

@icon("leech", 1, 2)
def leech(I):                   # a glossy segmented leech, curled
    pts = [(0.5 + math.sin(t * 4.6) * 0.18, 0.15 + t * 1.65) for t in np.linspace(0, 1, 14)]
    rs = [0.08 + 0.12 * math.sin(t * pi) ** 0.6 for t in np.linspace(0, 1, 14)]
    I.add(I.T(pts, rs), "#2e2430", gloss=1.4, shin=34, mottle=0.12)
    for (x, y) in pts[1:-1]:
        I.carve(I.E(x, y, 0.2, 0.012), 0.012)
    I.paint(I.T(pts, [r * 0.3 for r in rs]), "#8a6a3a", amt=0.5)
    I.add(I.E(pts[-1][0], pts[-1][1], 0.1, 0.07), "#3a2c38", mode="max", gloss=1.2)

@icon("dung_ball", 2, 2)
def dung_ball(I):               # a rolled ball of dung with straw and grit
    I.add(I.E(1.0, 1.0, 0.86, 0.84), "#4e3a22", gloss=0.08, mottle=0.3, mscale=0.12, grain=0.03, gscale=0.05)
    rnd = R(6)
    for _ in range(16):
        x, y, a = rnd.uniform(0.35, 1.65), rnd.uniform(0.35, 1.65), rnd.uniform(0, pi)
        if (x - 1) ** 2 + (y - 1) ** 2 > 0.55: continue
        I.add(I.T([(x, y), (x + math.cos(a) * 0.25, y + math.sin(a) * 0.25)], 0.018), "#9a8048", mode="on", gloss=0.2)
    speck(I, 50, in_ell(1, 1, 0.8, 0.8), "#241a10", seed=7, amt=0.7)

@icon("mantis_forelimb", 2, 3, ["X.", "X.", "XX"])
def mantis_forelimb(I):         # raptorial foreleg folded at the knee, rows of spines
    I.add(I.E(0.5, 1.4, 0.26, 1.2), "#4c7a2a", gloss=0.45, mottle=0.15)
    I.carve(I.T([(0.6, 0.4), (0.62, 2.3)], 0.02), 0.03)
    for y in np.linspace(0.6, 2.3, 9):
        I.add(I.T([(0.72, y), (0.86, y - 0.06)], [0.025, 0.006]), "#d0d8a0", mode="over", gloss=0.5)
    I.paint(I.E(0.55, 1.5, 0.08, 0.2), "#1a1a1a", amt=0.8)        # eyespot
    I.paint(I.E(0.55, 1.5, 0.04, 0.1), "#e8e0a0", amt=0.8)
    leg(I, [(0.6, 2.62), (1.4, 2.6), (1.88, 2.52)], [0.12, 0.08, 0.05], "#4c7a2a")
    for x in np.linspace(0.9, 1.75, 7):
        I.add(I.T([(x, 2.5), (x + 0.04, 2.4)], [0.02, 0.005]), "#d0d8a0", mode="over")

@icon("silk_bundle", 3, 3, [".X.", "XXX", ".X."])
def silk_bundle(I):             # prey wrapped up tight: lumpy silk with loose strands over it
    I.add(I.E(1.5, 1.5, 0.5, 1.36), "#bcb8ac", gloss=0.5, mottle=0.15)
    I.add(I.E(1.5, 1.5, 1.36, 0.5), "#bcb8ac", gloss=0.5, mottle=0.15, mode="max")
    I.add(I.E(1.5, 1.5, 0.6, 0.6), "#c4c0b4", gloss=0.5, mottle=0.15, mode="max")
    rnd = R(21)
    for _ in range(70):
        a = rnd.uniform(0, pi); c = (1.5 + rnd.uniform(-0.6, 0.6), 1.5 + rnd.uniform(-0.6, 0.6))
        l = rnd.uniform(0.6, 1.4)
        pts = [(c[0] - math.cos(a) * l, c[1] - math.sin(a) * l), (c[0] + rnd.uniform(-0.08, 0.08), c[1] + rnd.uniform(-0.08, 0.08)), (c[0] + math.cos(a) * l, c[1] + math.sin(a) * l)]
        I.raise_(I.T(pts, 0.016), 0.012)
        I.paint(I.T(pts, 0.007), rnd.choice(["#f4f2ec", "#e0dcd2", "#d0ccc0"]), amt=0.7)
    I.paint(I.E(1.5, 1.5, 0.35, 0.3), "#5a4a3a", amt=0.3, soft=1)

@icon("bombardier_gland", 2, 1)
def bombardier_gland(I):        # twin reservoirs feeding a boiling reaction chamber
    for cx in (0.55, 1.45):
        I.add(I.E(cx, 0.5, 0.36, 0.33), "#7a2c14", gloss=1.0, shin=30, mottle=0.15)
        I.paint(I.E(cx - 0.08, 0.42, 0.18, 0.14), "#b85020", amt=0.5, soft=1)
    I.add(I.E(1.0, 0.56, 0.17, 0.16), "#d8a040", gloss=1.2, emit="#a04010")
    I.glow(I.E(1.0, 0.56, 0.13, 0.12), "#ffd080", 1)
    for x, y in ((0.4, 0.3), (1.6, 0.36), (0.62, 0.7)):
        I.add(I.E(x, y, 0.04, 0.04), "#ffe0a0", mode="on", emit="#ff9a40", gloss=1)

# ---------------------------------------------------------------------------------------------
# Microbes and fungi

@icon("tardigrade", 1, 1)
def tardigrade(I):              # a plump, wrinkled water bear seen from above, eight clawed stubs
    for x in (0.24, 0.42, 0.6, 0.78):
        for side in (-1, 1):
            I.add(I.E(x, 0.5 + side * 0.24, 0.07, 0.09), "#9a8268", gloss=0.2)
            for c in (-0.03, 0.03):
                I.add(I.T([(x + c, 0.5 + side * 0.31), (x + c * 1.5, 0.5 + side * 0.38)], [0.01, 0.004]), "#3a2e24", mode="over")
    I.add(I.E(0.5, 0.5, 0.4, 0.22, z=0.9), "#b8a284", gloss=0.35, shin=16, mottle=0.12, grain=0.008)
    I.add(I.E(0.88, 0.5, 0.08, 0.1), "#c4ae90", mode="max", gloss=0.3)
    for x in (0.28, 0.42, 0.56, 0.7):
        I.carve(I.T([(x, 0.3), (x + 0.02, 0.7)], 0.012), 0.025)
    I.paint(I.E(0.5, 0.52, 0.3, 0.1), "#7a6a48", amt=0.25, soft=1)
    for y in (0.44, 0.56): I.paint(I.E(0.88, y, 0.015, 0.015), "#1a1410")

@icon("nematode", 1, 2)
def nematode(I):                # a translucent roundworm in a loose coil
    pts = [(0.5 + math.sin(t * 9) * 0.26 * (0.5 + 0.5 * math.sin(t * 3 + 1)), 0.15 + t * 1.7) for t in np.linspace(0, 1, 40)]
    I.add(I.T(pts, 0.045), "#d8ccb4", gloss=1.0, shin=30, mottle=0.06, op=0.85)
    I.paint(I.T(pts[4:-4], 0.014), "#8a6a4a", amt=0.7)

@icon("bacterial_bloom", 2, 2, ["XX", "X."])
def bacterial_bloom(I):         # a slimy biofilm with rods and colonies, like a smear under glass
    I.add(I.F(lambda X, Y: ((((X - 1.0) / 0.95) ** 2 + ((Y - 0.5) / 0.44) ** 2 < 1) | (((X - 0.5) / 0.44) ** 2 + ((Y - 1.0) / 0.95) ** 2 < 1),
                            0.03 + 0.0 * X)), "#3e5a24", gloss=0.9, shin=24, mottle=0.35, mscale=0.2, op=0.9)
    rnd = R(12)
    for _ in range(70):
        x, y = rnd.uniform(0.1, 1.9), rnd.uniform(0.1, 1.9)
        if not ((x > 0.95 and y < 0.95) or x < 0.95): continue
        if x > 0.95 and y > 0.95: continue
        if rnd.random() < 0.45:
            r = rnd.uniform(0.03, 0.08)
            I.add(I.E(x, y, r, r * 0.9), rnd.choice(["#9ac040", "#c8d860", "#6a9a30"]), mode="on", gloss=1.2, shin=30, op=0.95)
        else:
            a = rnd.uniform(0, pi)
            I.add(I.T([(x, y), (x + math.cos(a) * 0.09, y + math.sin(a) * 0.09)], 0.016), "#b8d070", mode="on", gloss=1, shin=30)

@icon("slime_mold", 2, 3, ["X.", "XX", ".X"])
def slime_mold(I):              # yellow Physarum: a branching net of veins with fanned fronts
    rnd = R(5)
    def branch(x, y, a, l, r, depth):
        x2, y2 = x + math.cos(a) * l, y + math.sin(a) * l
        mx, my = (x + x2) / 2 + rnd.uniform(-0.05, 0.05), (y + y2) / 2 + rnd.uniform(-0.05, 0.05)
        I.add(I.T([(x, y), (mx, my), (x2, y2)], [r, r * 0.85, r * 0.75]), "#d0a814", mode="max", gloss=1.4, shin=34, mottle=0.2)
        if depth > 0:
            for d in (-0.55, 0.5):
                branch(x2, y2, a + d + rnd.uniform(-0.25, 0.25), l * 0.72, r * 0.72, depth - 1)
        else:
            I.add(I.E(x2, y2, 0.06, 0.05, rot=a), "#e8c430", mode="max", gloss=1.2, op=0.9)
    branch(1.0, 1.5, -2.1, 0.42, 0.075, 4)
    branch(1.0, 1.5, 1.05, 0.42, 0.075, 4)
    branch(1.0, 1.5, -0.4, 0.25, 0.05, 2)
    I.add(I.E(1.0, 1.5, 0.13, 0.11), "#e0b820", gloss=1.4, shin=34, mode="max")

@icon("amoeba", 1, 1)
def amoeba(I):                  # a glassy cell with pseudopods, nucleus and vacuoles
    I.add(I.E(0.5, 0.5, 0.28, 0.25), "#8aa8a8", gloss=1.4, shin=36, op=0.75, mottle=0.1)
    for a, l in ((0.3, 0.38), (2.2, 0.34), (3.6, 0.4), (5.0, 0.3)):
        I.add(I.T([(0.5, 0.5), (0.5 + math.cos(a) * l, 0.5 + math.sin(a) * l)], [0.14, 0.06]), "#8aa8a8", mode="max", gloss=1.4, shin=36, op=0.75)
    I.add(I.E(0.55, 0.52, 0.09, 0.08), "#5a4a6a", mode="on", gloss=0.6, op=0.9)
    I.paint(I.E(0.55, 0.52, 0.03, 0.03), "#2a2034")
    for x, y in ((0.38, 0.42), (0.6, 0.36), (0.42, 0.62)):
        I.paint(I.E(x, y, 0.03, 0.03), "#c8e8e0", amt=0.8)

@icon("rotifer", 1, 1)
def rotifer(I):                 # a vase-shaped rotifer with two wheels of cilia
    I.add(I.E(0.5, 0.6, 0.18, 0.24), "#9ab0a0", gloss=1.2, shin=30, op=0.8)
    I.add(I.T([(0.5, 0.8), (0.5, 0.95)], [0.05, 0.02]), "#8aa090", gloss=1, op=0.8)
    I.paint(I.E(0.5, 0.62, 0.08, 0.12), "#a0a050", amt=0.6)
    for cx in (0.36, 0.64):
        I.add(I.E(cx, 0.3, 0.12, 0.08), "#b0c4b0", mode="max", gloss=1, op=0.85)
        for k in range(10):
            a = pi + k / 9 * pi
            I.add(I.T([(cx + math.cos(a) * 0.11, 0.3 + math.sin(a) * 0.07), (cx + math.cos(a) * 0.17, 0.3 + math.sin(a) * 0.12)], 0.006), "#e8fff0", mode="over", emit="#506050")

@icon("gut_flora", 2, 1)
def gut_flora(I):               # a loop of gut, its wall thin enough to see the colonies inside
    I.add(I.T([(0.15, 0.6), (0.5, 0.3), (1.0, 0.55), (1.5, 0.35), (1.85, 0.55)], 0.2), "#9a4a44", gloss=1.0, shin=24, mottle=0.15, op=0.9)
    for x in np.linspace(0.25, 1.75, 9):
        I.carve(I.E(x, 0.48, 0.015, 0.2), 0.02)
    speck(I, 40, (lambda x, y: True, (0.15, 0.3, 1.85, 0.7)), "#c8e070", seed=13, size=(0.012, 0.022))
    I.glow(I.T([(0.3, 0.5), (1.0, 0.5), (1.7, 0.45)], 0.08), "#304010", 0.8)

@icon("gnat_swarm", 1, 1)
def gnat_swarm(I):              # three gnats with smoky, glinting wings
    for (x, y, a) in ((0.28, 0.3, 0.4), (0.72, 0.4, -0.3), (0.42, 0.74, 0.9)):
        for s in (-1, 1):
            I.add(I.E(x + math.cos(a + s * 2.3) * 0.1, y + math.sin(a + s * 2.3) * 0.1, 0.13, 0.05, rot=a + s * 2.3, z=0.2), "#a0aab4", gloss=1.6, shin=40, op=0.5)
        I.add(I.T([(x - math.cos(a) * 0.12, y - math.sin(a) * 0.12), (x + math.cos(a) * 0.06, y + math.sin(a) * 0.06)], [0.04, 0.035]), "#2a221c", mode="over", gloss=0.8, shin=24)
        I.add(I.E(x + math.cos(a) * 0.09, y + math.sin(a) * 0.09, 0.04, 0.04), "#3a1a14", mode="over", gloss=0.8)
        for s in (-1, 1):
            I.add(I.T([(x, y), (x + math.cos(a + s * 1.4) * 0.09, y + math.sin(a + s * 1.4) * 0.09)], 0.005), "#1a1410", mode="over")

@icon("cordyceps", 1, 3, ["X", "X", "X"])
def cordyceps(I):               # an orange fruiting club grown out of a dead ant's head
    I.add(I.E(0.5, 2.6, 0.3, 0.26), "#2a1a12", gloss=0.8, shin=26)
    I.add(I.E(0.5, 2.88, 0.2, 0.1), "#1e140e", gloss=0.6, mode="max")
    for s in (-1, 1):
        I.add(I.T([(0.5 + s * 0.12, 2.42), (0.5 + s * 0.3, 2.2), (0.5 + s * 0.4, 2.3)], 0.022), "#2a1a12", gloss=0.6)
        I.paint(I.E(0.5 + s * 0.17, 2.55, 0.05, 0.05), "#5a3a20")
    I.add(I.T([(0.5, 2.45), (0.46, 1.9), (0.54, 1.3), (0.5, 0.9)], [0.07, 0.06, 0.055, 0.06]), "#c87a28", gloss=0.2, mottle=0.2)
    I.add(I.E(0.5, 0.55, 0.15, 0.42), "#d8701c", gloss=0.25, mottle=0.25, grain=0.02, gscale=0.03)
    speck(I, 40, in_ell(0.5, 0.55, 0.13, 0.4), "#8a3a10", seed=11, size=(0.01, 0.018))

@icon("fly_agaric", 2, 2)
def fly_agaric(I):
    I.add(I.T([(1.0, 1.9), (1.02, 1.1)], [0.26, 0.19]), "#d8cfbc", gloss=0.05, mottle=0.08)
    I.add(I.E(1.0, 1.3, 0.3, 0.08, z=0.8), "#cfc4ac", mode="on", gloss=0.05)
    I.add(I.E(1.0, 1.88, 0.34, 0.1), "#c4b49a", mode="max", gloss=0.05)
    I.add(I.E(1.0, 0.72, 0.88, 0.52, z=0.9), "#a8241a", base=0.2, gloss=0.5, shin=20, mottle=0.2)
    I.paint(I.E(1.0, 0.45, 0.45, 0.25), "#c8401e", amt=0.6, soft=1)
    I.paint(I.E(1.0, 1.05, 0.8, 0.18), "#5a1008", amt=0.5, soft=1)
    rnd = R(4)
    for _ in range(18):
        a, r = rnd.uniform(0, 2 * pi), rnd.uniform(0.05, 0.74)
        x, y = 1.0 + math.cos(a) * r, 0.66 + math.sin(a) * r * 0.55
        I.add(I.E(x, y, rnd.uniform(0.04, 0.07), rnd.uniform(0.035, 0.055)), "#e6dcc6", mode="on", gloss=0.05, mottle=0.2)

@icon("puffball", 1, 1)
def puffball(I):                # a cracked puffball breathing a puff of spores
    I.add(I.E(0.5, 0.58, 0.36, 0.32), "#c8b894", gloss=0.1, mottle=0.15, grain=0.02, gscale=0.03)
    I.carve(I.T([(0.45, 0.3), (0.5, 0.36), (0.56, 0.3)], 0.03), 0.04)
    I.paint(I.E(0.5, 0.33, 0.06, 0.04), "#4a3a24")
    speck(I, 30, in_ell(0.5, 0.58, 0.32, 0.28), "#8a7a5a", seed=9, size=(0.01, 0.02), amt=0.6)
    rnd = R(2)
    for _ in range(14):
        I.add(I.E(0.5 + rnd.uniform(-0.15, 0.15), 0.2 - rnd.uniform(0, 0.15), 0.025, 0.025), "#a89a78", gloss=0, op=0.5, emit="#2a2418")

@icon("lichen", 2, 1)
def lichen(I):                  # leafy grey-green lichen rosettes on a chip of bark
    I.add(I.P([(0.05, 0.35), (0.6, 0.15), (1.5, 0.2), (1.95, 0.4), (1.9, 0.75), (1.1, 0.88), (0.2, 0.8)], bevel=0.08, z=0.06), "#3a2a1c", gloss=0.05, mottle=0.3, grain=0.02)
    for x in np.linspace(0.15, 1.85, 9): I.carve(I.T([(x, 0.2), (x + 0.1, 0.85)], 0.012), 0.03)
    rnd = R(8)
    for _ in range(22):
        x, y = rnd.uniform(0.2, 1.8), rnd.uniform(0.3, 0.72)
        r = rnd.uniform(0.05, 0.12)
        I.add(I.E(x, y, r, r * 0.8, rot=rnd.uniform(0, pi), z=0.4), rnd.choice(["#8aa080", "#9ab088", "#7a9478", "#b0a860"]), mode="on", gloss=0.1, mottle=0.2)

@icon("mycelium", 1, 4)
def mycelium(I):                # a rope of white fungal threads with small knots
    for k in range(6):
        pts = [(0.5 + math.sin(y * 2.4 + k) * (0.1 + 0.03 * k), y) for y in np.linspace(0.1, 3.9, 30)]
        I.add(I.T(pts, 0.025), "#d8d0c0", mode="max", gloss=0.3, mottle=0.1, op=0.95)
    rnd = R(3)
    for _ in range(40):
        y = rnd.uniform(0.2, 3.8); x = 0.5 + rnd.uniform(-0.1, 0.1)
        a = rnd.uniform(0, 2 * pi)
        I.add(I.T([(x, y), (x + math.cos(a) * 0.2, y + math.sin(a) * 0.12)], 0.008), "#e8e2d4", mode="max", gloss=0.2, op=0.8)
    for y in (0.8, 1.9, 3.0):
        I.add(I.E(0.5, y, 0.1, 0.08), "#c8b8a0", mode="on", gloss=0.2)

# ---------------------------------------------------------------------------------------------
# Bug parts

@icon("spider_fang", 1, 2)
def spider_fang(I):             # a hairy chelicera base and its glossy curved fang
    I.add(I.E(0.5, 1.45, 0.34, 0.42), "#2e221c", gloss=0.25, mottle=0.2)
    hairs(I, 40, in_ell(0.5, 1.45, 0.3, 0.38), "#7a6250", length=0.07, r=0.008, seed=3, angle=pi / 2)
    pts = [(0.5, 1.12), (0.52, 0.8), (0.58, 0.5), (0.68, 0.28), (0.8, 0.14)]
    I.add(I.T(pts, [0.17, 0.15, 0.11, 0.07, 0.025]), "#1a1210", base=0.05, gloss=1.6, shin=40, mottle=0.1)
    I.paint(I.T(pts[:3], 0.12), "#4a2a1a", amt=0.4, soft=1)
    I.add(I.E(0.84, 0.13, 0.045, 0.045), "#8ac850", mode="on", gloss=1.5, shin=40, op=0.85, emit="#2a4a10")

@icon("cicada_shell", 2, 2)
def cicada_shell(I):            # an empty, papery cicada skin split down the back
    for side in (-1, 1):
        for y, ln in ((0.85, 0.42), (1.15, 0.48), (1.45, 0.42)):
            leg(I, [(1.0 + side * 0.3, y), (1.0 + side * (0.3 + ln * 0.6), y - 0.1), (1.0 + side * (0.3 + ln), y + 0.18)], [0.05, 0.04, 0.025], "#a06a2a", gloss=0.8)
    I.add(I.E(1.0, 1.2, 0.36, 0.56), "#a8702c", gloss=0.9, shin=26, mottle=0.15, op=0.9)
    for y in np.linspace(1.1, 1.65, 6): I.carve(I.T([(0.7, y), (1.3, y)], 0.012), 0.02)
    I.add(I.E(1.0, 0.55, 0.34, 0.24), "#b07a34", gloss=0.9, shin=26, op=0.9)
    for s in (-1, 1): I.add(I.E(1.0 + s * 0.3, 0.5, 0.1, 0.1), "#c89048", mode="max", gloss=1.2, op=0.9)
    I.carve(I.T([(1.0, 0.4), (1.0, 1.2)], 0.035), 0.12)
    I.paint(I.T([(1.0, 0.42), (1.0, 1.18)], 0.03), "#2a1408")

@icon("moth_wing", 2, 2, ["XX", "X."])
def moth_wing(I):               # a dusty moth forewing and hindwing: scales, bands and an eyespot
    fore = [(0.1, 0.12), (1.0, 0.1), (1.9, 0.22), (1.86, 0.62), (1.4, 0.82), (0.9, 0.9), (0.3, 0.8)]
    hind = [(0.1, 0.6), (0.85, 0.85), (0.9, 1.4), (0.7, 1.85), (0.3, 1.8), (0.08, 1.2)]
    I.add(I.P(hind, bevel=0.12, z=0.03), "#4a3628", gloss=0.05, mottle=0.3, grain=0.006)
    I.add(I.P(fore, bevel=0.12, z=0.03), "#5a4432", base=0.03, gloss=0.05, mottle=0.35, grain=0.006)
    for k in range(4):
        x = 0.45 + k * 0.38
        I.paint(I.T([(x, 0.14), (x - 0.12, 0.45), (x + 0.02, 0.84)], 0.03), "#2a1c12", amt=0.7)
    I.paint(I.T([(0.15, 0.6), (1.85, 0.4)], 0.05), "#8a7456", amt=0.45)
    I.paint(I.E(0.5, 1.35, 0.22, 0.2), "#140c08")
    I.paint(I.E(0.5, 1.35, 0.16, 0.14), "#9a6a2a")
    I.paint(I.E(0.5, 1.35, 0.08, 0.07), "#100806")
    I.paint(I.E(0.46, 1.31, 0.03, 0.025), "#e8d8a8")
    speck(I, 120, (lambda x, y: True, (0.15, 0.15, 1.85, 1.8)), "#1e140c", seed=5, size=(0.006, 0.012), amt=0.6)
    for t in np.linspace(0, 1, 30):
        x, y = 1.9 - t * 0.5, 0.24 + t * 0.4
        I.add(I.T([(x, y), (x + 0.05, y + 0.02)], 0.006), "#6a5a46", mode="over", op=0.7)

@icon("alarm_pheromone", 1, 1)
def alarm_pheromone(I):         # a bead of red alarm scent in a gland sac, giving off fumes
    I.add(I.E(0.5, 0.6, 0.3, 0.28), "#8a1810", gloss=1.4, shin=40, mottle=0.1, op=0.9, emit="#2a0400")
    I.glow(I.E(0.55, 0.66, 0.2, 0.18), "#c03018", 0.8)
    I.add(I.T([(0.5, 0.34), (0.48, 0.22)], [0.07, 0.05]), "#5a4030", gloss=0.4)
    for pts in ([(0.5, 0.2), (0.42, 0.1), (0.5, 0.02)], [(0.5, 0.2), (0.62, 0.12), (0.7, 0.04)]):
        I.add(I.T(pts, 0.02), "#d06a50", op=0.5, gloss=0, emit="#401008")

@icon("strider_legs", 1, 3)
def strider_legs(I):            # two hair-thin water strider legs, velvety and jointed
    leg(I, [(0.3, 0.1), (0.36, 1.1), (0.26, 2.1), (0.3, 2.85)], [0.03, 0.03, 0.022, 0.015], "#3a3a40", gloss=0.6)
    leg(I, [(0.68, 0.15), (0.62, 1.25), (0.74, 2.2), (0.7, 2.9)], [0.03, 0.03, 0.022, 0.015], "#2e2e34", gloss=0.6)
    hairs(I, 40, (lambda x, y: True, (0.2, 0.2, 0.8, 2.8)), "#8a8a98", length=0.04, r=0.004, seed=4, mode="over")

@icon("click_beetle_hinge", 1, 1)
def click_beetle_hinge(I):      # a whole little click beetle, its pronotum ending in sharp rear corners
    I.add(I.E(0.5, 0.64, 0.17, 0.3, flat=0.2), "#3e2a1c", gloss=0.9, shin=28, mottle=0.1)
    I.carve(I.T([(0.5, 0.42), (0.5, 0.92)], 0.012), 0.03)
    for x in (0.4, 0.6): I.carve(I.T([(x, 0.45), (x + (x - 0.5) * 0.3, 0.86)], 0.007), 0.012)
    I.add(I.P([(0.3, 0.42), (0.34, 0.2), (0.5, 0.14), (0.66, 0.2), (0.7, 0.42), (0.62, 0.38), (0.38, 0.38)], bevel=0.08, z=0.08), "#4a3222", base=0.04, gloss=1.0, shin=30)
    hairs(I, 24, (lambda x, y: True, (0.36, 0.18, 0.64, 0.38)), "#9a7a50", length=0.025, r=0.004, seed=5, angle=pi / 2)
    I.add(I.E(0.5, 0.11, 0.09, 0.06), "#2e1e14", gloss=0.8, mode="max")
    for s in (-1, 1):
        I.add(I.T([(0.5 + s * 0.06, 0.08), (0.5 + s * 0.16, 0.02)], 0.01), "#3e2a1c", mode="over")

@icon("cockroach_heart", 1, 1)
def cockroach_heart(I):         # a dark muscular heart chamber with its aorta and slit valves
    I.add(I.T([(0.5, 0.06), (0.52, 0.3)], [0.06, 0.08]), "#7a3036", gloss=1.0, shin=30)
    I.add(I.T([(0.52, 0.2), (0.75, 0.12), (0.9, 0.16)], 0.045), "#6a2a30", gloss=1.0, mode="max")
    I.add(I.E(0.48, 0.6, 0.3, 0.32, rot=-0.3), "#6a1a20", gloss=1.4, shin=36, mottle=0.15)
    for (x, y) in ((0.36, 0.5), (0.5, 0.66), (0.62, 0.5)):
        I.carve(I.E(x, y, 0.06, 0.015, rot=0.4), 0.03)
    for pts in ([(0.3, 0.42), (0.42, 0.62), (0.4, 0.82)], [(0.6, 0.38), (0.56, 0.6), (0.66, 0.78)]):
        I.paint(I.T(pts, 0.012), "#3a4a7a", amt=0.6)
    I.paint(I.E(0.4, 0.5, 0.12, 0.08), "#a84048", amt=0.4, soft=1)

@icon("rhino_horn", 2, 2, ["X.", "XX"])
def rhino_horn(I):              # the head horn of a rhinoceros beetle, rising from its pronotum
    I.add(I.E(1.05, 1.5, 0.85, 0.36), "#2a1a12", gloss=1.4, shin=36, mottle=0.12)
    pts = [(0.62, 1.4), (0.55, 1.0), (0.52, 0.6), (0.6, 0.3), (0.78, 0.14)]
    I.add(I.T(pts, [0.2, 0.15, 0.11, 0.07, 0.03]), "#3a2416", gloss=1.2, shin=30, mottle=0.12)
    I.paint(I.T(pts[1:], 0.04), "#7a5232", amt=0.4)
    for y in np.linspace(0.5, 1.3, 6): I.carve(I.E(0.55, y, 0.12, 0.012), 0.012)
    I.add(I.T([(1.45, 1.75), (1.6, 1.9)], 0.03), "#1a100a", gloss=0.8)

@icon("mosquito_proboscis", 1, 2)
def mosquito_proboscis(I):      # a mosquito head: compound eyes, plumed antennae and the needle
    I.add(I.E(0.5, 1.62, 0.24, 0.2), "#4a4038", gloss=0.6, shin=24)
    for s in (-1, 1):
        I.add(I.E(0.5 + s * 0.13, 1.6, 0.11, 0.13), "#2a2a30", mode="max", gloss=1.2, shin=30, grain=0.012, gscale=0.02)
        I.add(I.T([(0.5 + s * 0.06, 1.45), (0.5 + s * 0.3, 1.05)], 0.012), "#6a5a4a", mode="over")
        for t in np.linspace(0.1, 0.9, 6):
            x, y = 0.5 + s * (0.06 + 0.24 * t), 1.45 - 0.4 * t
            I.add(I.T([(x - 0.06, y), (x + 0.06, y)], 0.006), "#8a7a6a", mode="over")
    I.add(I.T([(0.5, 1.45), (0.5, 0.4), (0.5, 0.14)], [0.03, 0.02, 0.008]), "#2a2420", gloss=1, mode="over")
    I.add(I.E(0.5, 0.12, 0.05, 0.06), "#8a1010", mode="over", gloss=1.6, shin=40, emit="#200000")

@icon("woodlouse_shell", 3, 1, ["XXX"])
def woodlouse_shell(I):         # the banded grey armour of a woodlouse, half rolled
    I.add(I.E(1.5, 0.5, 1.38, 0.4, z=0.8), "#5a5a62", gloss=0.6, shin=24, mottle=0.18)
    for x in np.linspace(0.35, 2.65, 11):
        I.carve(I.T([(x, 0.14), (x + 0.03, 0.86)], 0.025), 0.05)
        I.paint(I.T([(x + 0.05, 0.16), (x + 0.07, 0.84)], 0.02), "#8a8a94", amt=0.4)
    speck(I, 60, in_ell(1.5, 0.5, 1.3, 0.35), "#c8c0a8", seed=14, size=(0.01, 0.018), amt=0.5)
    I.paint(I.E(1.5, 0.3, 1.2, 0.08), "#7a7a84", amt=0.3, soft=1)

@icon("earthworm", 3, 2, ["XX.", ".XX"])
def earthworm(I):               # a moist pink earthworm in a lazy S, with its saddle
    pts = []
    for t in np.linspace(0, 1, 30):
        x = 0.2 + t * 2.6
        y = 0.5 + 1.0 * (0.5 - 0.5 * math.cos(min(1, max(0, (t - 0.3) / 0.4)) * pi))
        pts.append((x, y))
    I.add(I.T(pts, [0.1 + 0.05 * math.sin(t * pi) for t in np.linspace(0, 1, 30)]), "#b46a62", gloss=1.4, shin=30, mottle=0.12)
    for (x, y) in pts[1:-1]: I.carve(I.E(x, y, 0.012, 0.16), 0.012)
    I.add(I.T(pts[8:12], 0.15), "#c47a6a", mode="max", gloss=1.0, shin=24)
    I.glow(I.T(pts, 0.03), "#3a1414", 0.6)

# ---------------------------------------------------------------------------------------------
# Plants

@icon("acorn_cap", 1, 1)
def acorn_cap(I):               # a scaly acorn cup with its woody stalk
    I.add(I.E(0.5, 0.55, 0.38, 0.32, flat=0.3), "#6a4a26", gloss=0.15, mottle=0.2)
    for row in range(5):
        y = 0.32 + row * 0.1
        w = 0.36 * math.sqrt(max(0, 1 - ((y - 0.55) / 0.34) ** 2))
        for x in np.linspace(0.5 - w, 0.5 + w, max(2, int(w * 22))):
            I.add(I.E(x + (0.02 if row % 2 else 0), y, 0.035, 0.03), "#8a6436", mode="on", gloss=0.2, mottle=0.25)
    I.add(I.T([(0.5, 0.24), (0.55, 0.1), (0.62, 0.06)], 0.035), "#4a321a", gloss=0.1, mode="over")

@icon("pine_needle", 1, 2)
def pine_needle(I):             # a pair of pine needles from a papery sheath
    I.add(I.T([(0.45, 1.75), (0.32, 1.0), (0.2, 0.15)], [0.035, 0.03, 0.01]), "#2e5a2e", gloss=1.0, shin=30, mottle=0.12)
    I.add(I.T([(0.52, 1.75), (0.64, 1.0), (0.78, 0.18)], [0.035, 0.03, 0.01]), "#264e28", gloss=1.0, shin=30, mottle=0.12)
    I.add(I.T([(0.48, 1.88), (0.48, 1.68)], [0.06, 0.05]), "#7a5a3a", gloss=0.1, mottle=0.3)

@icon("maple_seed", 2, 1)
def maple_seed(I):              # a samara: seed bulb and a thin, veined wing
    I.add(I.P([(0.3, 0.5), (0.7, 0.18), (1.4, 0.1), (1.9, 0.22), (1.85, 0.45), (1.2, 0.6), (0.5, 0.68)], bevel=0.08, z=0.025), "#a8783c", gloss=0.2, mottle=0.25, op=0.85)
    for k in range(10):
        I.paint(I.T([(0.4, 0.55), (0.8 + k * 0.11, 0.14 + k * 0.015)], 0.008), "#6a4220", amt=0.7)
    I.add(I.E(0.32, 0.55, 0.22, 0.18), "#7a5028", gloss=0.3, mottle=0.2)
    I.paint(I.E(0.28, 0.52, 0.1, 0.08), "#9a6a38", amt=0.5)

@icon("moss_clump", 2, 1)
def moss_clump(I):              # a cushion of moss with spore stalks
    rnd = R(5)
    I.add(I.E(1.0, 0.68, 0.92, 0.26), "#2e4a1a", gloss=0.05, mottle=0.3)
    for _ in range(120):
        x, y = rnd.uniform(0.15, 1.85), rnd.uniform(0.48, 0.88)
        if ((x - 1) / 0.9) ** 2 + ((y - 0.68) / 0.24) ** 2 > 1: continue
        I.add(I.E(x, y, 0.035, 0.03), rnd.choice(["#3e6a22", "#4a7a28", "#2e5a1a", "#5a8a30"]), mode="on", gloss=0.1)
    for x in (0.4, 0.75, 1.15, 1.5):
        top = (x + rnd.uniform(0.02, 0.08), 0.12)
        I.add(I.T([(x, 0.55), top], 0.012), "#8a4a1a", mode="over", gloss=0.4)
        I.add(I.E(top[0], top[1], 0.03, 0.05, rot=0.3), "#a86a2a", mode="over", gloss=0.6)

@icon("rose_thorn", 1, 1)
def rose_thorn(I):              # a hooked red-brown thorn on a sliver of green stem
    I.add(I.T([(0.0, 0.72), (1.0, 0.68)], 0.12), "#3e5a26", gloss=0.4, mottle=0.2)
    I.add(I.T([(0.45, 0.66), (0.5, 0.42), (0.6, 0.24), (0.76, 0.14)], [0.16, 0.08, 0.04, 0.008]), "#7a2a1c", base=0.05, gloss=1.0, shin=30, mottle=0.15)
    I.paint(I.T([(0.45, 0.66), (0.5, 0.45)], 0.12), "#4a5a24", amt=0.5, soft=1)

@icon("nettle_leaf", 2, 1)
def nettle_leaf(I):             # a serrated nettle leaf bristling with stinging hairs
    pts = []
    for t in np.linspace(0, 1, 26):
        x = 0.1 + t * 1.8
        w = 0.36 * math.sin(t * pi) ** 0.8 * (1 + 0.15 * (1 if int(t * 25) % 2 else -1))
        pts.append((x, 0.5 - w))
    pts += [(x, 1.0 - y) for (x, y) in reversed(pts)]
    I.add(I.P(pts, bevel=0.1, z=0.04), "#2e5a26", gloss=0.35, mottle=0.2)
    I.carve(I.T([(0.1, 0.5), (1.9, 0.5)], 0.02), 0.03)
    for x in np.linspace(0.35, 1.6, 6):
        for s in (-1, 1): I.carve(I.T([(x, 0.5), (x + 0.22, 0.5 + s * 0.26)], 0.012), 0.02)
    hairs(I, 50, (lambda x, y: True, (0.2, 0.25, 1.8, 0.75)), "#d8e8c0", length=0.04, r=0.004, seed=6, mode="on")

@icon("burdock_burr", 1, 1)
def burdock_burr(I):            # a ball of hooked bracts that catches on everything
    I.add(I.E(0.5, 0.5, 0.2, 0.2), "#4a3a1e", gloss=0.2, mottle=0.25)
    rnd = R(14)
    for _ in range(60):
        a = rnd.uniform(0, 2 * pi); el = rnd.uniform(-0.7, 0.9)
        r = 0.36 * math.cos(el * 0.9)
        e = (0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r)
        hook = (e[0] + math.cos(a + 1.9) * 0.035, e[1] + math.sin(a + 1.9) * 0.035)
        I.add(I.T([(0.5 + math.cos(a) * 0.1, 0.5 + math.sin(a) * 0.1), e, hook], [0.014, 0.008, 0.004]),
              rnd.choice(["#8a7a40", "#7a6a34", "#a08a4a", "#6a5a2a"]), mode="on", base=-0.02 + 0.05 * el, gloss=0.6)
    I.add(I.E(0.5, 0.44, 0.06, 0.05), "#9a6888", mode="on", gloss=0.1)

@icon("dandelion_puff", 1, 2)
def dandelion_puff(I):          # a dandelion clock: seeds on fine stalks, a hollow stem
    I.add(I.T([(0.52, 1.95), (0.5, 0.7)], [0.035, 0.03]), "#5a7a3a", gloss=0.4)
    rnd = R(9)
    for k in range(60):
        a = rnd.uniform(0, 2 * pi); l = rnd.uniform(0.3, 0.42)
        x, y = 0.5 + math.cos(a) * l, 0.46 + math.sin(a) * l
        I.add(I.T([(0.5, 0.46), (x, y)], 0.004), "#c8c4b4", mode="over", op=0.75, gloss=0)
        for b in range(5):
            ba = a + (b - 2) * 0.35
            I.add(I.T([(x, y), (x + math.cos(ba) * 0.05, y + math.sin(ba) * 0.05)], 0.003), "#f0ece0", mode="over", op=0.6, gloss=0)
    I.add(I.E(0.5, 0.46, 0.07, 0.07), "#6a5a34", mode="over", gloss=0.2)
    speck(I, 20, in_ell(0.5, 0.46, 0.065, 0.065), "#2a2010", seed=4, size=(0.006, 0.01))

@icon("pine_cone", 2, 2)
def pine_cone(I):               # an egg-shaped cone of woody, overlapping scales
    I.add(I.E(1.0, 1.0, 0.62, 0.86), "#3a2414", gloss=0.1)
    for row in range(10):
        y = 0.25 + row * 0.165
        half = 0.62 * math.sqrt(max(0, 1 - ((y - 1.0) / 0.86) ** 2))
        n = max(1, int(half / 0.12))
        for i in range(n + 1):
            x = 1.0 - half + (2 * half) * (i + (0.5 if row % 2 else 0)) / (n + 1)
            I.add(I.E(x, y + 0.04, 0.11, 0.09), "#7a5230", mode="on", gloss=0.3, shin=16, mottle=0.25)
            I.paint(I.E(x, y + 0.1, 0.08, 0.025), "#a07848", amt=0.6)
    I.add(I.T([(1.0, 0.14), (1.06, 0.02)], 0.04), "#4a3018", mode="over")

@icon("venus_flytrap", 3, 2, ["X.X", "XXX"])
def venus_flytrap(I):           # two open traps, red inside, lashes along the rims
    I.add(I.T([(1.5, 1.95), (1.5, 1.45)], 0.07), "#4a6a2a", gloss=0.1)
    I.add(I.P([(0.2, 1.4), (1.5, 1.15), (2.8, 1.4), (2.6, 1.75), (1.5, 1.6), (0.4, 1.75)], bevel=0.12, z=0.08), "#3e5e24", gloss=0.2)
    I.carve(I.T([(0.3, 1.5), (2.7, 1.5)], 0.02), 0.03)
    for cx in (0.5, 2.5):
        I.add(I.E(cx, 0.75, 0.38, 0.62, z=0.35), "#5a7a2c", gloss=0.35, shin=16, mottle=0.18)
        I.paint(I.E(cx, 0.78, 0.27, 0.5), "#8a1c1a", amt=0.95, soft=0.3)
        I.paint(I.E(cx, 0.8, 0.16, 0.35), "#5e0e12", amt=0.6, soft=1)
        speck(I, 14, in_ell(cx, 0.8, 0.2, 0.42), "#c06048", seed=int(cx * 10), size=(0.01, 0.016), amt=0.7)
        for i in range(10):
            y = 0.2 + i * 0.12
            for side in (-1, 1):
                ex = cx + side * 0.38 * math.sqrt(max(0, 1 - ((y - 0.75) / 0.62) ** 2))
                I.add(I.T([(ex, y), (ex + side * 0.13, y - 0.03)], [0.016, 0.006]), "#b8c070", gloss=0.2)

@icon("aloe_leaf", 1, 3)
def aloe_leaf(I):               # a thick aloe leaf with toothed edges, cut to show the gel
    pts = [(0.5, 0.05)]
    for t in np.linspace(0.05, 1, 12):
        pts.append((0.5 + 0.32 * min(1, t * 2.2), 0.05 + t * 2.8))
    pts += [(1 - x, y) for (x, y) in reversed(pts[1:])]
    I.add(I.P(pts, bevel=0.3, z=0.2), "#4a7a5a", gloss=0.5, shin=20, mottle=0.18)
    speck(I, 40, (lambda x, y: True, (0.25, 0.4, 0.75, 2.7)), "#a8c8a0", seed=7, size=(0.012, 0.02), amt=0.6)
    for t in np.linspace(0.15, 0.95, 9):
        y = 0.05 + t * 2.8
        for s in (-1, 1):
            I.add(I.T([(0.5 + s * 0.31 * min(1, t * 2.2), y), (0.5 + s * 0.4 * min(1, t * 2.2), y - 0.04)], [0.02, 0.004]), "#d8c890", mode="over")
    I.add(I.E(0.5, 2.85, 0.3, 0.08), "#c8e0b0", mode="over", gloss=1.4, shin=30, op=0.9, emit="#203020")

@icon("chili_pepper", 1, 2)
def chili_pepper(I):            # a glossy, wrinkled red chili with a green calyx
    pts = [(0.5 + math.sin(t * 2.4) * 0.14, 0.32 + t * 1.55) for t in np.linspace(0, 1, 12)]
    I.add(I.T(pts, [0.17 * (1 - t * 0.85) + 0.01 for t in np.linspace(0, 1, 12)]), "#a81810", gloss=1.6, shin=40, mottle=0.12)
    I.carve(I.T(pts[1:8], 0.02), 0.02)
    I.add(I.E(0.5, 0.3, 0.17, 0.08), "#3e6a24", mode="max", gloss=0.4)
    I.add(I.T([(0.5, 0.26), (0.56, 0.08), (0.68, 0.04)], 0.035), "#4a7a2c", mode="over", gloss=0.3)

@icon("coffee_bean", 1, 1)
def coffee_bean(I):             # a dark roasted bean with its centre cut
    I.add(I.E(0.5, 0.5, 0.28, 0.38, rot=0.45, flat=0.25), "#4a2a16", gloss=0.6, shin=24, mottle=0.12)
    I.carve(I.T([(0.37, 0.18), (0.47, 0.42), (0.53, 0.6), (0.63, 0.82)], 0.025), 0.06)
    I.paint(I.T([(0.37, 0.18), (0.47, 0.42), (0.53, 0.6), (0.63, 0.82)], 0.012), "#c8a070", amt=0.5)

@icon("walnut_shell", 2, 2)
def walnut_shell(I):            # a deeply wrinkled walnut, seam down the middle
    I.add(I.E(1.0, 1.0, 0.78, 0.86), "#8a6234", gloss=0.12, mottle=0.2)
    I.carve(I.T([(1.0, 0.15), (1.0, 1.85)], 0.03), 0.08)
    I.raise_(I.T([(1.0, 0.15), (1.0, 1.85)], 0.06), 0.03)
    rnd = R(19)
    for _ in range(40):
        x, y = rnd.uniform(0.35, 1.65), rnd.uniform(0.3, 1.7)
        if ((x - 1) / 0.72) ** 2 + ((y - 1) / 0.8) ** 2 > 1: continue
        pts = [(x, y)]
        for _ in range(3):
            pts.append((pts[-1][0] + rnd.uniform(-0.12, 0.12), pts[-1][1] + rnd.uniform(-0.08, 0.12)))
        I.carve(I.T(pts, 0.02), 0.05)

@icon("cactus_spine", 1, 2, ["X", "X"])
def cactus_spine(I):            # a long pale spine from a woolly areole
    I.add(I.E(0.5, 1.7, 0.26, 0.2), "#a8a090", gloss=0, mottle=0.2, grain=0.02, gscale=0.02)
    hairs(I, 40, in_ell(0.5, 1.7, 0.24, 0.17), "#e0dcd0", length=0.05, r=0.006, seed=8)
    I.add(I.T([(0.5, 1.6), (0.53, 0.8), (0.56, 0.06)], [0.05, 0.03, 0.004]), "#d8cca0", mode="over", gloss=1.0, shin=30)
    I.paint(I.T([(0.5, 1.5), (0.53, 1.2)], 0.04), "#8a6a4a", amt=0.6, soft=1)
    for a in (-0.5, 0.5):
        I.add(I.T([(0.5, 1.62), (0.5 + math.sin(a) * 0.4, 1.62 - math.cos(a) * 0.5)], [0.025, 0.004]), "#c8bc94", mode="over", gloss=0.8)

# ---------------------------------------------------------------------------------------------
# Natural finds

@icon("amber", 2, 1)
def amber(I):                   # a polished resin nugget, deep and clear, a gnat sealed inside
    I.add(I.E(1.0, 0.5, 0.9, 0.4, rot=0.05, z=0.8), "#6a2e04", gloss=2.0, shin=70, mottle=0.25, op=0.92)
    I.paint(I.E(1.15, 0.62, 0.55, 0.24), "#a85a0a", amt=0.6, soft=1)
    I.glow(I.E(1.2, 0.64, 0.45, 0.2), "#4a2000", 1)
    I.paint(I.E(1.05, 0.5, 0.05, 0.13), "#140802")
    I.paint(I.E(1.05, 0.38, 0.04, 0.04), "#140802")
    for s in (-1, 1):
        I.paint(I.E(1.05 + s * 0.13, 0.43, 0.13, 0.045, rot=s * 0.5), "#4a2a0c", amt=0.8)
        for k in (-0.06, 0.02, 0.08):
            I.paint(I.T([(1.05, 0.5 + k), (1.05 + s * 0.14, 0.6 + k)], 0.006), "#140802", amt=0.9)
    speck(I, 14, in_ell(1.0, 0.5, 0.8, 0.32), "#d89a40", seed=3, size=(0.006, 0.012), amt=0.7)

@icon("quartz_crystal", 1, 2)
def quartz_crystal(I):          # a clear hexagonal point: bright facet, shaded facet, cloudy base
    faces = [([(0.2, 1.88), (0.2, 0.62), (0.42, 0.62), (0.42, 1.92)], "#dce6f2"),
             ([(0.42, 1.92), (0.42, 0.62), (0.62, 0.62), (0.62, 1.9)], "#7a869c"),
             ([(0.62, 1.9), (0.62, 0.62), (0.8, 0.62), (0.8, 1.86)], "#343c50"),
             ([(0.2, 0.62), (0.5, 0.1), (0.42, 0.62)], "#ffffff"),
             ([(0.42, 0.62), (0.5, 0.1), (0.62, 0.62)], "#a0aec4"),
             ([(0.62, 0.62), (0.5, 0.1), (0.8, 0.62)], "#4a5468")]
    for pts, col in faces:
        I.add(I.P(pts, bevel=0.015, z=0.005), col, base=0.05, gloss=1.2, shin=80, mottle=0.05)
    I.paint(I.E(0.5, 1.82, 0.32, 0.14), "#c8ccd4", amt=0.5, soft=1)
    I.paint(I.T([(0.28, 1.45), (0.34, 1.05)], 0.008), "#ffffff", amt=0.8)
    I.paint(I.T([(0.5, 1.3), (0.56, 1.0)], 0.006), "#e0e8f8", amt=0.6)

@icon("snail_shell", 2, 2)
def snail_shell(I):             # a banded snail shell, its spiral climbing to the apex
    I.add(I.E(1.0, 1.0, 0.86, 0.84), "#9a6c3a", gloss=0.7, shin=24, mottle=0.12)
    pts = [(1.0 + math.cos(t) * (0.06 + t * 0.055), 1.0 + math.sin(t) * (0.06 + t * 0.055)) for t in np.linspace(0, 4.2 * pi, 80)]
    I.carve(I.T(pts, 0.025), 0.06)
    band = [(1.0 + math.cos(t) * (0.1 + t * 0.055), 1.0 + math.sin(t) * (0.1 + t * 0.055)) for t in np.linspace(0.5, 4.0 * pi, 70)]
    I.paint(I.T(band, 0.03), "#4a2e18", amt=0.7)
    for k in range(14):
        a = k / 14 * 2 * pi
        I.carve(I.T([(1.0 + math.cos(a) * 0.4, 1.0 + math.sin(a) * 0.4), (1.0 + math.cos(a + 0.2) * 0.82, 1.0 + math.sin(a + 0.2) * 0.82)], 0.01), 0.015)
    I.raise_(I.E(1.0, 1.0, 0.35, 0.35), 0.1)

@icon("feather", 1, 3)
def feather(I):                 # a barred brown contour feather with a pale rachis
    pts = []
    for t in np.linspace(0, 1, 16):
        w = 0.36 * math.sin(t * pi) ** 0.55
        pts.append((0.5 - w - (t - 0.5) * 0.06, 0.12 + t * 2.6))
    pts += [(1.0 - x + 0.0, y) for (x, y) in reversed(pts)]
    I.add(I.P(pts, bevel=0.15, z=0.03), "#7a6450", gloss=0.2, mottle=0.2, grain=0.006, gscale=0.02)
    for y in np.linspace(0.3, 2.6, 11):
        I.paint(I.T([(0.15, y + 0.12), (0.5, y), (0.85, y + 0.12)], 0.05), "#3a2c20", amt=0.6)
    for y in np.linspace(0.2, 2.65, 40):
        for s in (-1, 1): I.carve(I.T([(0.5, y), (0.5 + s * 0.4, y + 0.14)], 0.004), 0.008)
    I.add(I.T([(0.5, 0.12), (0.5, 2.9)], [0.01, 0.03]), "#e0d4b8", mode="on", gloss=0.6)

@icon("salt_crystal", 1, 1)
def salt_crystal(I):            # a cluster of clear cubic salt crystals
    def cube(cx, cy, s, b):
        I.add(I.P([(cx - s, cy - s * 0.5), (cx, cy - s), (cx + s, cy - s * 0.5), (cx + s, cy + s * 0.6), (cx, cy + s * 1.1), (cx - s, cy + s * 0.6)], bevel=0.015, z=0.02),
              "#c8c8d0", base=b, gloss=1.4, shin=50, mottle=0.05, op=0.92)
        I.paint(I.P([(cx - s, cy - s * 0.5), (cx, cy - s), (cx + s, cy - s * 0.5), (cx, cy)]), "#f8f8ff", amt=0.8)
        I.paint(I.P([(cx, cy), (cx + s, cy - s * 0.5), (cx + s, cy + s * 0.6), (cx, cy + s * 1.1)]), "#6a6c7a", amt=0.7)
        I.paint(I.P([(cx - s, cy - s * 0.5), (cx, cy), (cx, cy + s * 1.1), (cx - s, cy + s * 0.6)]), "#a8aab4", amt=0.6)
    cube(0.34, 0.6, 0.22, 0.0); cube(0.68, 0.66, 0.19, 0.02); cube(0.54, 0.3, 0.17, 0.04)

@icon("trilobite", 2, 2)
def trilobite(I):               # a trilobite fossil weathering out of a slab of shale
    I.add(I.P([(0.08, 0.3), (0.5, 0.06), (1.6, 0.1), (1.92, 0.5), (1.85, 1.7), (1.2, 1.94), (0.2, 1.8)], bevel=0.1, z=0.08), "#5e584c", gloss=0.1, mottle=0.25, grain=0.015, gscale=0.03)
    I.add(I.E(1.0, 0.55, 0.5, 0.3, flat=0.2), "#6e6250", mode="on", gloss=0.3, mottle=0.15)
    I.add(I.E(1.0, 1.15, 0.4, 0.62, flat=0.4), "#6e6250", mode="on", gloss=0.3, mottle=0.15)
    for y in np.linspace(0.75, 1.65, 10): I.carve(I.T([(0.62, y), (1.38, y)], 0.015), 0.035)
    for x in (0.86, 1.14): I.carve(I.T([(x, 0.7), (x, 1.68)], 0.015), 0.035)
    I.raise_(I.E(1.0, 0.5, 0.12, 0.22), 0.05)
    for s in (-1, 1): I.raise_(I.E(1.0 + s * 0.28, 0.52, 0.07, 0.06), 0.05)
    I.add(I.E(1.0, 1.8, 0.12, 0.06), "#6e6250", mode="on", gloss=0.3)

@icon("honeycomb", 2, 3, ["XX", "XX", ".X"])
def honeycomb(I):               # a broken slab of wax comb, cells capped or brimming
    I.add(I.P([(0.06, 0.08), (1.94, 0.06), (1.94, 2.92), (1.08, 2.94), (1.06, 1.9), (0.06, 1.94)], bevel=0.12, z=0.12), "#9a6a1c", gloss=0.35, mottle=0.15)
    s = 0.27
    for row in range(13):
        for col in range(9):
            cx, cy = col * s + (s * 0.5 if row % 2 else 0) + 0.12, row * s * 0.87 + 0.14
            if cx > 1.86 or cy > 2.86 or (cx < 1.14 and cy > 1.84): continue
            f = I.F(lambda X, Y, cx=cx, cy=cy: _hexd(X, Y, cx, cy, s * 0.43))
            kind = (row * 7 + col * 3) % 6
            if kind == 0:
                I.carve(f, 0.12); I.paint(f, "#3a2006", amt=0.8)
            elif kind < 4:
                I.carve(f, 0.06); I.paint(f, "#d89418", amt=0.95); I.set(f, gloss=1.8, shin=50)
            else:
                I.raise_(f, 0.02); I.paint(f, "#c8a060", amt=0.7)

def _hexd(X, Y, cx, cy, r):
    dx, dy = np.abs(X - cx), np.abs(Y - cy)
    m = (dx * 0.87 + dy * 0.5 <= r * 0.87) & (dy <= r * 0.87)
    return m, np.where(m, 1.0, 0.0)

@icon("fulgurite", 2, 3, ["X.", "XX", "X."])
def fulgurite(I):               # a branching tube of lightning-fused sand, glassy where broken
    main = [(0.45, 0.1), (0.55, 0.6), (0.42, 1.15), (0.58, 1.7), (0.46, 2.3), (0.52, 2.9)]
    I.add(I.T(main, [0.13, 0.15, 0.13, 0.16, 0.13, 0.11]), "#7a6a54", gloss=0.2, mottle=0.25, grain=0.04, gscale=0.025)
    br = [(0.55, 1.4), (1.0, 1.3), (1.45, 1.55), (1.85, 1.45)]
    I.add(I.T(br, [0.1, 0.09, 0.08, 0.06]), "#7a6a54", mode="max", gloss=0.2, mottle=0.25, grain=0.04, gscale=0.025)
    for (x, y) in ((0.45, 0.1), (1.85, 1.45), (0.52, 2.9)):
        I.add(I.E(x, y, 0.07, 0.05), "#c8d8e0", mode="on", gloss=1.8, shin=50, op=0.85, emit="#304050")


def build(only=None):
    out = ["-- Inventory icons (generated by tools/make_item_icons.py; edit the generator, not this file).",
           f"-- One inventory cell = {RES}x{RES} pixels. Item defs use icon = \"icon_<item id>\" by default.",
           "return {"]
    previews = []
    for iid, cols, rows, shape, seed, fn in ICONS:
        if only and iid not in only: continue
        I = Icon(cols, rows, shape, seed)
        fn(I)
        grid, pal = quantize(I.render())
        previews.append((iid, grid, pal))
        out.append("    {")
        out.append(f'        id = "icon_{iid}",')
        out.append("        rotate = false,")
        out.append("        palette = { " + ", ".join(f'["{k}"] = "{v}"' for k, v in pal.items()) + " },")
        out.append("        frames = { {")
        for r in grid: out.append(f'            "{r}",')
        out.append("        } },")
        out.append("    },")
    out.append("}")
    return out, previews


def preview(path, previews, scale=5):
    from PIL import Image
    bg = (34, 30, 30)
    cw, ch = 3 * RES * scale + 16, 3 * RES * scale + 16
    per = 5
    img = Image.new("RGB", (cw * per, ch * ((len(previews) + per - 1) // per)), bg)
    for n, (iid, grid, pal) in enumerate(previews):
        ox, oy = (n % per) * cw + 8, (n // per) * ch + 8
        tile = Image.new("RGBA", (len(grid[0]), len(grid)), (0, 0, 0, 0))
        for y, r in enumerate(grid):
            for x, c in enumerate(r):
                if c == '.': continue
                v = pal[c].lstrip('#')
                a = int(v[6:8], 16) if len(v) > 6 else 255
                tile.putpixel((x, y), (int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16), a))
        cell = Image.new("RGBA", tile.size, (56, 50, 48, 255))
        cell.alpha_composite(tile)
        img.paste(cell.resize((tile.width * scale, tile.height * scale), Image.NEAREST), (ox, oy))
    img.save(path)


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "--preview":
        _, prev = build(set(args[2:]) or None)
        preview(args[1], prev)
        print("preview", len(prev))
    else:
        lines, prev = build()
        open("content/sprites/items.lua", "w").write("\n".join(lines) + "\n")
        print("wrote", len(prev))
