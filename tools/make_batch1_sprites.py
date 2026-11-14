# Generates the sprites for the batch-1 playable bugs and writes them as text-grid Lua.
#   python3 tools/make_batch1_sprites.py [preview.png]  ->  content/sprites/batch1.lua
# Assassin bug, emperor scorpion, crab, hermit crab, dung beetle (+ its dung ball), dragonfly
# and stink bug. Same look and helpers as tools/make_bug_sprites.py (lit ellipsoids quantised
# to colour ramps, soft outline, facing right, the game bakes rotations); the helper functions
# are loaded from that script (everything above its SPRITES list) so the two stay in step,
# without running it or touching bugs.lua.
import math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(HERE, "make_bug_sprites.py")).read()
exec(_src[:_src.index("\nSPRITES = [")])
BODY.update('xXyYzZ')       # shell and ball colours count as body for the outline
BODY.difference_update('vW')  # wings stay soft-edged (no dark outline)

def fill_poly(g, pts, ch, only=None):
    """Fill a polygon (shield shapes, shell whorls)."""
    h, w = len(g), len(g[0])
    for y in range(h):
        for x in range(w):
            px, py = x + 0.0, y + 0.0
            inside = False
            j = len(pts) - 1
            for i in range(len(pts)):
                xi, yi = pts[i]; xj, yj = pts[j]
                if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi + 1e-9) + xi:
                    inside = not inside
                j = i
            if inside and (only is None or g[y][x] in only):
                g[y][x] = ch

def shade_mask(g, cx, cy, rx, ry, ramp, only):
    """Re-light the cells in `only` as one ellipsoid (gives polygon shapes a rounded look)."""
    for y in range(len(g)):
        for x in range(len(g[0])):
            if g[y][x] in only:
                dx, dy = (x - cx) / rx, (y - cy) / ry
                d2 = min(0.98, dx * dx + dy * dy)
                nz = math.sqrt(1 - d2)
                i = dx * LIGHT[0] + dy * LIGHT[1] + nz * LIGHT[2]
                g[y][x] = ramp[4] if i > 0.95 else ramp[3] if i > 0.62 else ramp[2] if i > 0.32 else ramp[1] if i > 0.05 else ramp[0]

def assassin_bug(part=None):
    """Assassin bug (white-spotted Platymeris): slim black body, folded wings with two pale
    spots, flared red-banded abdomen edges, narrow neck and head with a long curved rostrum."""
    w, h, cy = 40, 30, 15
    def deco(g):
        for x in (6, 9, 12, 15):                                     # banded connexivum
            for sg in (-1, 1):
                put(g, x, cy + sg * 4.6, 'S'); put(g, x + 1, cy + sg * 4.6, 'S')
        for yy in range(len(g)):                                     # folded hemelytra
            for xx in range(len(g[0])):
                dx, dy = (xx - 13) / 8.8, (yy - cy) / 3.6
                if dx * dx + dy * dy <= 1 and g[yy][xx] in '1234h':
                    g[yy][xx] = 'B' if abs(yy - cy) < 0.6 else ('C' if dx * dx + dy * dy < 0.5 else 'A')
        for sg in (-1, 1):
            put(g, 11, cy + sg * 2, 'b'); put(g, 12, cy + sg * 2, 'b')   # the white spots
        line(g, [(29.5, cy), (32, cy)], 'C')                         # head
        put(g, 30.6, cy - 1.4, 'e'); put(g, 30.6, cy + 1.4, 'e')
        line(g, [(32.5, cy), (35, cy + 0.3), (36.6, cy + 1)], 'w')   # rostrum
    legs = [((24, cy - 2.4), (27, cy - 7), (31, cy - 10)), ((21, cy - 3), (20.5, cy - 9), (18.5, cy - 13.5)),
            ((18.5, cy - 3), (13, cy - 9), (6, cy - 12))]
    return critter(w, h, cy, [seg(12.5, 10.0, 5.0), seg(22.5, 3.4, 4.0, RAMP2), seg(27, 1.6, 1.4, RAMP2, False),
                              seg(30.5, 2.0, 1.9, RAMP2)], legs, deco,
                   antennae([(32, cy - 1.2), (35, cy - 5), (38.5, cy - 8)], cy), part, stride=1.2)

def emperor_scorpion(part=None):
    """Emperor scorpion: big glossy blue-black body, huge bumpy pincers and a thick tail."""
    w, h, cy = 46, 40, 20
    def deco(g):
        tail = [(6.5, cy, 2.4), (3.5, cy - 2, 2.3), (2.4, cy - 5.6, 2.2), (3.4, cy - 9.2, 2.1), (6.2, cy - 11.8, 2.0)]
        for (x, y, r) in tail: blob(g, x, y, r, r)
        blob(g, 10, cy - 13, 1.9, 1.6, RAMP2)
        line(g, [(11.6, cy - 13), (13.4, cy - 11.8)], 'w')
        for x in (11, 15.5, 20):
            line(g, [(x, cy - 4.2), (x + 0.4, cy), (x, cy + 4.2)], '1')
        for sg in (-1, 1):
            line(g, [(28.5, cy + sg * 2.5), (32, cy + sg * 5.5), (34.5, cy + sg * 7.5)], 'B')
            blob(g, 38, cy + sg * 8.2, 4.2, 3.0, RAMP2)
            for (bx, by) in ((36.5, 7.2), (38.5, 9.4), (40, 7.6)):
                put(g, bx, cy + sg * by, 'S')                         # granules on the claw
            line(g, [(41, cy + sg * 9), (44.4, cy + sg * 8)], 'D')
            line(g, [(41, cy + sg * 7), (44, cy + sg * 6.6)], 'w')
        put(g, 29, cy - 1, 'e'); put(g, 29, cy + 1, 'e')
    legs = [((26, cy - 3.5), (26, cy - 9), (29, cy - 13)), ((23.5, cy - 4), (22.5, cy - 10), (23, cy - 15.5)),
            ((21, cy - 4.4), (18, cy - 10), (16.5, cy - 15.5)), ((18, cy - 4.2), (13.5, cy - 9), (10, cy - 14))]
    return critter(w, h, cy, [seg(11.5, 4.2, 4.3), seg(16.5, 4.6, 4.9), seg(21.5, 4.4, 5.0), seg(26.5, 4.0, 4.2, RAMP2)],
                   legs, deco, None, part)

def crab(part=None):
    """Red rock crab: a wide, lumpy carapace, two strong black-tipped claws and four pairs of
    walking legs splayed out to the sides, eyes on short stalks."""
    w, h, cy = 36, 40, 20
    def deco(g):
        for (x, y) in ((12, cy - 5), (14, cy + 4), (10, cy + 1), (16, cy - 1), (11, cy + 7), (13, cy - 8)):
            put(g, x, y, 'S')                                        # pale knobbles
        for sg in (-1, 1):
            line(g, [(21, cy + sg * 7), (24.5, cy + sg * 9.5), (27, cy + sg * 10)], 'B')
            blob(g, 29.5, cy + sg * 9.6, 3.6, 2.6, RAMP2)
            line(g, [(31.5, cy + sg * 10.6), (34.4, cy + sg * 9.8)], 's')       # black fingertips
            line(g, [(31.5, cy + sg * 8.6), (34, cy + sg * 8.6)], 's')
            line(g, [(21, cy + sg * 1.6), (23, cy + sg * 2.2)], 'l')
            put(g, 23.5, cy + sg * 2.4, 'e')
        line(g, [(21.6, cy - 0.6), (21.6, cy + 0.6)], 'A')
    legs = [((17, cy - 8.5), (17, cy - 13), (19, cy - 17)), ((14, cy - 10), (13, cy - 15), (13.5, cy - 19)),
            ((11, cy - 10), (9, cy - 15), (8, cy - 18.5)), ((8, cy - 8.5), (5, cy - 12.5), (2.5, cy - 15))]
    return critter(w, h, cy, [seg(13, 8.6, 11.2)], legs, deco, None, part, stride=1.4)

def hermit_crab(part=None):
    """Purple pincher hermit crab: a big coiled sea-snail shell behind, a purple-red body in
    front with one oversized left claw and a small right one, eyestalks and feelers."""
    w, h, cy = 40, 32, 16
    def deco(g):
        blob(g, 10, cy, 9.5, 8.8, ('x', 'X', 'y', 'Y', 'z'))           # the shell
        for k in range(26):                                           # spiral whorl
            a = k / 26 * math.pi * 3.2
            r = 1.0 + k * 0.29
            put(g, 9 + math.cos(a) * r, cy - 1 + math.sin(a) * r * 0.9, 'Z')
        line(g, [(17, cy - 5), (19.5, cy), (17, cy + 5)], 'X')       # the shell's lip
        # big claw (left, top) and small claw (right, bottom)
        line(g, [(23, cy - 3), (26, cy - 6)], 'B')
        blob(g, 29, cy - 6.2, 3.8, 2.8, RAMP2)
        for (bx, by) in ((27.5, -7.5), (29.5, -5), (30.5, -7.8)): put(g, bx, cy + by, 'S')
        line(g, [(32, cy - 6.6), (34.6, cy - 6)], 'D')
        line(g, [(23, cy + 2.5), (25, cy + 4)], 'B')
        blob(g, 27, cy + 4.4, 2.2, 1.6, RAMP2)
        line(g, [(28.6, cy + 4.6), (30.4, cy + 4.2)], 'D')
        for sg in (-1, 1):
            line(g, [(24, cy + sg * 0.8), (27, cy + sg * 1.4)], 'l')
            put(g, 27.5, cy + sg * 1.6, 'e')
    legs = [((21, cy - 3.4), (23, cy - 8), (26.5, cy - 11)), ((19.5, cy - 3.6), (19.5, cy - 9), (21, cy - 13))]
    return critter(w, h, cy, [seg(21.5, 4.0, 3.8, RAMP2)], legs, deco,
                   antennae([(27, cy - 1), (32, cy - 3), (37.5, cy - 5)], cy), part, stride=1.3)

def dung_beetle(part=None):
    """Dung beetle: a round, glossy black beetle with a toothed shovel of a head and broad,
    spiny digging forelegs."""
    w, h, cy = 32, 30, 15
    def deco(g):
        line(g, [(3.5, cy), (14.5, cy)], 's')
        for k in (-3.6, -1.8, 1.8, 3.6):                              # elytral striae
            line(g, [(4.5, cy + k * 1.2), (13.5, cy + k)], 'A', True)
        for sg in (-1, 1):
            put(g, 22, cy + sg * 2.6, 'e')
        for (x, y) in ((25.5, -2.4), (26.2, -0.8), (26.2, 0.8), (25.5, 2.4)):
            put(g, x, cy + y, 'D')                                   # clypeal teeth
    legs = [((19.5, cy - 4), (23, cy - 8.5), (26.5, cy - 10)), ((14.5, cy - 7), (14.5, cy - 11), (12.5, cy - 13.5)),
            ((9.5, cy - 7), (6, cy - 10.5), (3, cy - 12.5))]
    def extra(g, f):
        for y in range(len(g)):                                       # spiny forelegs
            for x in range(len(g[0])):
                if g[y][x] == 'l' and x > 20 and (x + y) % 2 == 0: g[y][x] = 'm'
    return critter(w, h, cy, [seg(9.5, 7.6, 7.4), seg(18.4, 3.4, 6.2, RAMP2), seg(23.2, 2.6, 4.2, RAMP2)], legs, deco,
                   extra, part)

def dung_ball():
    """The dung ball: a lumpy brown sphere flecked with straw."""
    w = h = 15
    g = blank(w, h)
    blob(g, 7, 7, 6.6, 6.6, ('x', 'X', 'y', 'Y', 'z'), spec=False)
    for (x, y) in ((4, 5), (9, 4), (6, 9), (10, 9), (3, 8), (8, 11), (7, 2)):
        put(g, x, y, 'Z')
        put(g, x + 1, y + (1 if x % 2 else 0), 'X')
    line(g, [(5, 3), (7, 4)], 'S'); line(g, [(9, 7), (11, 6)], 'S'); line(g, [(4, 10), (5, 11)], 'S')
    outline(g)
    return [[''.join(r) for r in g]]

def dragonfly(part=None):
    """Emperor dragonfly: green thorax, long sky-blue abdomen with a black dorsal stripe,
    huge wraparound eyes and two pairs of clear veined wings held out flat to the sides."""
    w, h, cy = 46, 44, 22
    def body(g):
        if part != "legs":
            # wings: forewings then hindwings (only on the flat sprite: in game the 3D model's
            # wings are drawn by the flight move, see content/attacks/flight.lua)
            for (wx, ww, wy) in (((28.2, 2.5, 1), (22.2, 2.9, 1)) if part is None else ()):
                for sg in (-1, 1):
                    for yy in range(len(g)):
                        for xx in range(len(g[0])):
                            dx, dy = (xx - wx + (abs(yy - cy) - 11) * 0.08) / ww, (yy - (cy + sg * 11)) / 10.4
                            if dx * dx + dy * dy <= 1 and abs(yy - cy) > 1.4:
                                g[yy][xx] = 'W' if dx * dx + dy * dy > 0.72 else ('v' if (xx + yy * 2) % 5 else 'W')
                    put(g, wx + 1.0, cy + sg * 18.5, 'S')                # pterostigma
            blob(g, 25, cy, 3.6, 2.8)                                    # thorax
            for i in range(9):                                           # abdomen segments
                x = 20 - i * 2.2
                blob(g, x, cy, 1.4, 1.1 if i > 0 else 1.5, RAMP2, spec=i % 2 == 0)
            line(g, [(2.5, cy), (20, cy)], 'A')
            for i in range(8): put(g, 19 - i * 2.2, cy, 's')
            blob(g, 30, cy, 2.2, 3.2, ('e', 'e', 'E', 'E', 'b'))        # eyes
            put(g, 31.6, cy, 'w')
    legs = [((27, cy - 1.5), (29, cy - 3.2), (31, cy - 3.6)), ((25.5, cy - 2), (26, cy - 4), (27.5, cy - 4.8)),
            ((24, cy - 2), (23, cy - 4), (24, cy - 5))]
    def legs_fn():
        out = []
        for (r, k, t) in legs:
            out.append(lambda p, r=r, k=k, t=t: [r, (k[0] + 0.2 * p, k[1]), (t[0] + 0.4 * p, t[1])])
        return out
    return walk_frames(w, h, cy, legs_fn, body, None, part=part)

def stink_bug(part=None):
    """Brown marmorated stink bug: a mottled shield-shaped body with a pale-edged triangular
    scutellum, banded antennae and checkered abdomen edges."""
    w, h, cy = 34, 30, 15
    def body(g):
        fill_poly(g, [(3, cy - 4), (6, cy - 7.6), (16, cy - 8.4), (21, cy - 9.6), (24, cy - 4), (27, cy - 2), (27.5, cy),
                      (27, cy + 2), (24, cy + 4), (21, cy + 9.6), (16, cy + 8.4), (6, cy + 7.6), (3, cy + 4), (2, cy)], '2')
        shade_mask(g, 14, cy, 13, 9.6, RAMP1, '2')
        fill_poly(g, [(19.5, cy - 4.5), (19.5, cy + 4.5), (9, cy)], 'B')        # scutellum
        shade_mask(g, 15, cy, 7, 5, RAMP2, 'B')
        for (x, y) in ((14, -6), (8, -5), (11, 4), (17, 6), (6, 2), (22, -2), (23, 2), (13, -2.5), (25, 0.5)):
            put(g, x, cy + y, 'S')                                     # marmorated speckles
        for x in (4, 7.5, 11, 14.5):                                   # checkered edges
            for sg in (-1, 1):
                put(g, x, cy + sg * (5.8 + x * 0.12), 'b')
        line(g, [(19.5, cy - 4.5), (9, cy), (19.5, cy + 4.5)], 'm')
        put(g, 26, cy - 1.8, 'e'); put(g, 26, cy + 1.8, 'e')
        put(g, 28.2, cy, 'w')
    legs = [((22, cy - 3), (25, cy - 7), (28, cy - 10)), ((17, cy - 4), (16.5, cy - 9), (14, cy - 12.5)),
            ((12, cy - 4), (8, cy - 9), (4.5, cy - 11.5))]
    def legs_fn():
        out = []
        for (r, k, t) in legs:
            out.append(lambda p, r=r, k=k, t=t: [r, (k[0] + 0.4 * p, k[1]), (t[0] + p, t[1])])
        return out
    ant = antennae([(27.5, cy - 1.6), (30, cy - 5), (32.5, cy - 8)], cy)
    def extra(g, f):
        ant(g, f)
        for y in range(len(g)):                                       # banded antennae
            for x in range(len(g[0])):
                if g[y][x] == 'l' and x > 28 and (x + y) % 3 == 0: g[y][x] = 'b'
    return walk_frames(w, h, cy, legs_fn, body, extra, part=part)

SHELL = dict(x="#4a3420", X="#7a5a38", y="#a8865a", Y="#cdb084", z="#f4e4c0", Z="#3a2614")
DUNG = dict(x="#24160c", X="#3a2614", y="#56391e", Y="#6e4c2a", z="#a08060", Z="#1a0e06")
CHARS = [
    ("assassin_bug", assassin_bug, 12, 22, dict(o="#050303" + SOFT, l="#1a1212", t="#0a0606", T="#806868", e="#a02010", w="#2a1814", s="#0a0606",
        S="#d03018", b="#f0ece0", m="#3a2a2a",
        **ramp("#100808", "#1e1010", "#301a1a", "#462828", "#b09090"), **ramp2("#0c0a0a", "#1a1616", "#2a2424", "#3e3636", "#c0b4b4"))),
    ("emperor_scorpion", emperor_scorpion, 8, 14, dict(o="#030306" + SOFT, l="#141620", t="#08080e", T="#7a86a0", e="#4a1010", w="#a07040",
        S="#3a4058", **ramp("#06060c", "#0e1018", "#181c2a", "#262c40", "#a8b8e8"), **ramp2("#08080e", "#121420", "#1e2234", "#30364e", "#c0ccf0"))),
    ("crab", crab, 10, 18, dict(o="#0a0302" + SOFT, l="#a8361a", t="#5a1a0c", T="#f8a880", e="#080404", s="#140806", S="#f0c0a0",
        **ramp("#6a1608", "#962410", "#c0381a", "#e05a2a", "#ffc8a0"), **ramp2("#701808", "#a02a12", "#c8401c", "#e86a34", "#ffd0b0"))),
    ("hermit_crab", hermit_crab, 10, 18, dict(o="#060304" + SOFT, l="#8a2a4a", t="#4a1428", T="#f0a0c0", e="#080406", S="#ffd8e8",
        **SHELL, **ramp("#4a1430", "#6a1e44", "#8e2c5a", "#b04070", "#ffb0d0"), **ramp2("#5a1430", "#802040", "#a83054", "#d04a6c", "#ffc0d0"))),
    ("dung_beetle", dung_beetle, 10, 18, dict(o="#030303" + SOFT, l="#141210", m="#3a3428", t="#0a0806", T="#8a8270", e="#3a2a10", s="#060606",
        **ramp("#060606", "#101012", "#1c1c20", "#2c2c34", "#c0c4d8"), **ramp2("#080806", "#14130e", "#222018", "#36342a", "#d0ccb8"))),
    ("dragonfly", dragonfly, 30, 30, dict(o="#020604" + SOFT, l="#1a2014", t="#0a0e08", T="#8a9a70", e="#1a5a3a", E="#3aa070", b="#c0ffe0", w="#0a1a10",
        s="#0a2440", S="#3a2a10", v="#e0f0ff" + "28", W="#b0c8e0" + "70",
        **ramp("#1a4a14", "#286a1c", "#3a8e26", "#58b034", "#d0ffb0"), **ramp2("#0e3a6a", "#16528e", "#2070b4", "#3a94d8", "#c8ecff"))),
    ("stink_bug", stink_bug, 10, 18, dict(o="#050402" + SOFT, l="#4a3a28", t="#2a2014", T="#c0a888", e="#1a0a06", w="#2a1c10", m="#d8c8a0",
        b="#e8e0c8", S="#2a1c10", **ramp("#2e2214", "#4a3820", "#6a5232", "#8a6e46", "#e0c8a0"), **ramp2("#3a2c1a", "#564228", "#76603c", "#967c52", "#e8d4b0"))),
]

SPRITES = []
for cid, fn, fps, lfps, pal in CHARS:
    SPRITES.append((cid, fps, pal, fn()))
    SPRITES.append((cid + "_legs", lfps, cid, fn("legs")))
    SPRITES.append((cid + "_body", fps, cid, fn("body")))
SPRITES.append(("dung_ball", 1, dict(o="#0a0604" + SOFT, S="#c8a860", **DUNG), dung_ball()))

RIGS = {}
for c in CHARS:
    c[1]("legs")
    r = RIG["last"]
    cx, cyy = (r["w"] - 1) / 2, (r["h"] - 1) / 2
    RIGS[c[0] + "_legs"] = [[(round(x - cx, 2), round(y - cyy, 2)) for (x, y) in leg] for leg in r["legs"]]

PAL = {e[0]: e[2] for e in SPRITES if isinstance(e[2], dict)}

out = ["-- Batch-1 playable bug sprites (generated by tools/make_batch1_sprites.py, safe to hand-edit).",
       "-- Face right; the game bakes rotations. Ramps: 1..4/h and A..D/H (dark..light/gloss),",
       "-- o = soft outline, l = legs, e = eyes, v/W = wings, x..z/Z = shell and dung.",
       "return {"]
for sid, fps, pal, frames in SPRITES:
    out.append("    {")
    out.append(f'        id = "{sid}",')
    out.append(f"        fps = {fps},")
    if sid in RIGS:
        legs = ", ".join("{ " + ", ".join(f"{x}, {y}" for x, y in leg) + " }" for leg in RIGS[sid])
        out.append(f"        rig = {{ {legs} }},")
    if isinstance(pal, str):
        out.append("        iso = true,")
        pal = PAL[pal]
    out.append("        palette = { " + ", ".join(f'["{k}"] = "{v}"' for k, v in pal.items()) + " },")
    out.append("        frames = {")
    for fr in frames:
        out.append("            {")
        for r in fr: out.append(f'                "{r}",')
        out.append("            },")
    out.append("        },")
    out.append("    },")
out.append("}")
open(os.path.join(HERE, "..", "content", "sprites", "batch1.lua"), "w").write("\n".join(out) + "\n")
print("wrote", len(SPRITES))

if len(sys.argv) > 1:
    # quick 8x preview of the whole sprites (first frame) and the bodies
    from PIL import Image
    S, bg = 8, (150, 144, 132)
    shown = [s for s in SPRITES if not s[0].endswith("_legs")]
    W = sum(len(s[3][0][0]) + 2 for s in shown) * S
    H = max(len(s[3][0]) for s in shown) * S + 2 * S
    img = Image.new("RGB", (W, H), bg)
    x0 = 0
    for sid, fps, pal, frames in shown:
        pal = PAL[pal] if isinstance(pal, str) else pal
        for ry, row in enumerate(frames[0]):
            for rx, ch in enumerate(row):
                if ch == '.': continue
                col = pal[ch]
                c = [int(col[i:i + 2], 16) for i in (1, 3, 5)]
                a = int(col[7:9], 16) / 255 if len(col) >= 9 else 1
                c = tuple(int(c[i] * a + bg[i] * (1 - a)) for i in range(3))
                for dy in range(S):
                    for dx in range(S):
                        img.putpixel((x0 + rx * S + dx, S + ry * S + dy), c)
        x0 += (len(frames[0][0]) + 2) * S
    img.save(sys.argv[1])
