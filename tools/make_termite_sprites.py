# Generates the termite sprites (all castes of the termite family) as text-grid Lua.
#   python3 tools/make_termite_sprites.py   ->  content/sprites/termites.lua
# Same look and conventions as tools/make_bug_sprites.py (lit ellipsoids, 4-step ramps, soft
# outline, sprites face right, rotations baked in game), kept in its own file so termites can
# be tweaked without regenerating every ant.
#
# Termites are not ants: no pinched waist, straight beaded antennae, a soft pale body you can
# see the gut through, and a long segmented abdomen. Castes differ mostly in the head.
#   ramp 1: "1".."4" + "h" (abdomen)      ramp 2: "A".."D" + "H" (head/thorax)
#   ramp 3: "P".."S" + "U" (the queen's stretched membrane, egg shells)
#   g = gut showing through the skin, w = mandibles, n/N = nasute nozzle and its glue drop,
#   W = wing pads / wing stubs, e = eyes, l = legs, L = antenna beads, o = outline
import math

LIGHT = (-0.55, -0.65, 0.55)
_l = math.sqrt(sum(c * c for c in LIGHT))
LIGHT = tuple(c / _l for c in LIGHT)
RAMP1 = ('1', '2', '3', '4', 'h')
RAMP2 = ('A', 'B', 'C', 'D', 'H')
RAMP3 = ('P', 'Q', 'R', 'S', 'U')
BODY = set('1234hABCDHPQRSUgwnNWe')

def blank(w, h): return [['.'] * w for _ in range(h)]

def put(g, x, y, ch, only_empty=False):
    x, y = int(round(x)), int(round(y))
    if 0 <= y < len(g) and 0 <= x < len(g[0]):
        if only_empty and g[y][x] != '.': return
        g[y][x] = ch

def blob(g, cx, cy, rx, ry, ramp=RAMP1, spec=True, only=None, bias=0.0):
    for y in range(len(g)):
        for x in range(len(g[0])):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            d2 = dx * dx + dy * dy
            if d2 <= 1.0 and (only is None or g[y][x] in only):
                nz = math.sqrt(max(0.0, 1 - d2))
                i = dx * LIGHT[0] + dy * LIGHT[1] + nz * LIGHT[2] + bias
                if spec and i > 0.95: ch = ramp[4]
                elif i > 0.62: ch = ramp[3]
                elif i > 0.32: ch = ramp[2]
                elif i > 0.05: ch = ramp[1]
                else: ch = ramp[0]
                g[y][x] = ch

def line(g, pts, ch, only_empty=False):
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n + 1):
            t = i / n
            put(g, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, ch, only_empty)

def outline(g, ch='o'):
    h, w = len(g), len(g[0])
    marks = []
    for y in range(h):
        for x in range(w):
            if g[y][x] == '.':
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and g[ny][nx] in BODY:
                        marks.append((x, y)); break
    for x, y in marks: g[y][x] = ch

def mirror(pts, cy): return [(x, 2 * cy - y) for x, y in pts]

GAIT = (0.0, 1.0, 0.0, -1.0)

def termite(s, head=1.0, head_len=1.0, mandible=0.0, nasus=0.0, abdomen=1.0, ab_len=1.0, leg=1.0,
            antenna=1.0, eyes=False, wingpads=False, gut=True, physo=0.0, frames=4):
    """One termite. physo > 0 swells the abdomen into a queen's egg-filled sausage (membrane
    stretched pale between dark plates)."""
    arx, ary = 3.0 * s * abdomen * ab_len, 1.9 * s * abdomen
    if physo:
        arx, ary = (3.0 + 7.0 * physo) * s, (1.9 + 2.6 * physo) * s
    ax = arx + 1.5
    # thorax: three short plates in a row, no waist (pronotum is the saddle behind the head)
    t3 = ax + arx * 0.92 + 0.7 * s
    t2 = t3 + 1.1 * s
    t1 = t2 + 1.2 * s
    hrx, hry = 1.45 * s * head * head_len, 1.3 * s * head
    hx = t1 + 0.6 * s + hrx * 0.95
    mlen = 2.2 * s * mandible
    nlen = 2.4 * s * nasus
    reach = max(hx + hrx + max(mlen, nlen) + 1, hx + (0.4 + 2.6 * antenna) * s, t2 + 4.4 * s * leg)
    w = int(math.ceil(reach)) + 3
    half = int(math.ceil(max(ary + 1, hry + 1, 4.6 * s * leg, (hry + 2.2 * s * antenna) if antenna else 0))) + 2
    h, cy = half * 2 + 1, half

    def body(g):
        if physo:
            # stretched membrane, dark sclerite plates riding on top in bands, the tip darker
            blob(g, ax, cy, arx, ary, RAMP3)
            n = int(5 + 5 * physo)
            for i in range(n):
                px = ax - arx * 0.82 + (arx * 1.62) * i / (n - 1)
                k = 1 - ((px - ax) / arx) ** 2
                blob(g, px, cy, 0.55 * s, ary * 0.42 * math.sqrt(max(0.1, k)), RAMP1, spec=False)
            blob(g, ax - arx * 0.93, cy, 0.9 * s, ary * 0.3, RAMP1, spec=False)
        else:
            blob(g, ax, cy, arx, ary, bias=0.12)
            if gut:   # the dark wood-filled gut shows through pale workers' skin
                blob(g, ax - arx * 0.1, cy + 0.3, arx * 0.5, ary * 0.32, ('g',) * 5, spec=False, only='123')
            # segment rings
            nr = 3 if s < 0.9 else 4
            for i in range(1, nr):
                bx = ax - arx + 2 * arx * i / nr
                k = math.sqrt(max(0.0, 1 - ((bx - ax) / arx) ** 2))
                line(g, [(bx, cy - ary * k * 0.85), (bx + 0.3, cy), (bx, cy + ary * k * 0.85)], '2')
        blob(g, t3, cy, 0.8 * s, 1.35 * s, RAMP2, spec=False)
        blob(g, t2, cy, 0.75 * s, 1.3 * s, RAMP2, spec=False)
        blob(g, t1, cy, 0.9 * s, 1.55 * s, RAMP2)
        if wingpads:
            for sg in (-1, 1):
                line(g, [(t2, cy + sg * 0.9 * s), (t3 - 1.6 * s * wingpads, cy + sg * 1.5 * s)], 'W')
                line(g, [(t3 + 0.2 * s, cy + sg * 0.9 * s), (t3 - 2.4 * s * wingpads, cy + sg * 1.25 * s)], 'W')
        blob(g, hx, cy, hrx, hry, RAMP2, bias=0.22)
        if mandible:  # long sabre jaws, crossing at the tips
            for sg in (-1, 1):
                line(g, [(hx + hrx * 0.8, cy + sg * hry * 0.45), (hx + hrx + mlen * 0.6, cy + sg * hry * 0.5),
                         (hx + hrx + mlen, cy - sg * 0.4)], 'w')
        if nasus:     # the nasus: a tapering snout that squirts glue
            for i in range(int(nlen * 2) + 1):
                xx = hx + hrx * 0.7 + i * 0.5
                wd = 0.9 * s * (1 - i / (nlen * 2 + 1)) * 0.9
                line(g, [(xx, cy - wd), (xx, cy + wd)], 'n')
            put(g, hx + hrx * 0.7 + nlen, cy, 'N')
        if eyes:
            for sg in (-1, 1): put(g, hx + hrx * 0.25, cy + sg * hry * 0.7, 'e')
        if not mandible and not nasus:   # stubby chewing jaws
            for sg in (-1, 1): put(g, hx + hrx + 0.3, cy + sg * 0.5 * s, 'w')

    def legs():
        st, L = 0.8 * s, leg
        return [
            lambda p: [(t1, cy - 0.8 * s), (t1 + 1.6 * s * L, cy - 2.6 * s * L), (t1 + 2.8 * s * L + p * st, cy - 3.8 * s * L)],
            lambda p: [(t2, cy - 0.8 * s), (t2 + 0.2 * s * L, cy - 3.0 * s * L), (t2 - 0.8 * s * L + p * st, cy - 4.4 * s * L)],
            lambda p: [(t3, cy - 0.8 * s), (t3 - 1.8 * s * L, cy - 2.8 * s * L), (t3 - 3.6 * s * L + p * st, cy - 4.0 * s * L)],
        ]

    def antennae(g, f):
        # straight beaded antennae (moniliform), angled forward and out, feeling about
        sway = (0.35 if f in (1, 2) else -0.2) * s
        bx, by = hx + hrx * 0.55, cy - hry * 0.75
        tx, ty = hx + (0.4 + 2.6 * antenna) * s, cy - hry - 2.0 * s * antenna + sway
        n = max(3, int(math.hypot(tx - bx, ty - by)))
        for sg in (-1, 1):
            for i in range(n + 1):
                t = i / n
                x, y = bx + (tx - bx) * t, by + (ty - by) * t
                if sg > 0: y = 2 * cy - y
                put(g, x, y, 'L' if i % 2 == 0 else 'l', True)

    out = []
    for f in range(frames):
        g = blank(w, h)
        phase = GAIT[f % 4] if frames == 4 else (1, -1)[f % 2]
        for i, lg in enumerate(legs()):
            sign = 1 if i % 2 == 0 else -1
            line(g, lg(phase * sign), 'l')
            line(g, mirror(lg(-phase * sign), cy), 'l')
        body(g)
        outline(g)
        if antenna: antennae(g, f)
        out.append([''.join(r) for r in g])
    return out

def egg_clutch(frames=2):
    """A little heap of shiny termite eggs. The second frame wobbles (something inside moves)."""
    out = []
    eggs = [(4.5, 4.0, 1.9, 1.3), (8.0, 3.4, 1.9, 1.3), (6.3, 6.6, 1.9, 1.3), (9.7, 6.4, 1.8, 1.25), (3.2, 7.0, 1.7, 1.2)]
    for f in range(frames):
        g = blank(14, 11)
        for i, (x, y, rx, ry) in enumerate(eggs):
            j = 0.35 if (f == 1 and i % 2 == 0) else 0
            blob(g, x + j, y - j, rx, ry, RAMP3)
        outline(g)
        out.append([''.join(r) for r in g])
    return out

SOFT = "b0"
def pal(o, l, L, e, w, r1, r2, r3=None, **more):
    p = dict(o=o + SOFT, l=l, L=L, e=e, w=w)
    p.update({k: v for k, v in zip("1234h", r1)})
    p.update({k: v for k, v in zip("ABCDH", r2)})
    if r3: p.update({k: v for k, v in zip("PQRSU", r3)})
    p.update(more)
    return p

PALE = ("#4a3c2c", "#7a6a50", "#a8987a", "#cbbd9c", "#f4ead2")     # soft cream body
CREAM_HEAD = ("#5a4628", "#8a6e42", "#b49260", "#d4b47e", "#fff0c8")
MEMBRANE = ("#8a7a60", "#b4a486", "#d8cbb0", "#efe6d2", "#ffffff")

SPRITES = [
    # Workers: blind, pale, gut showing through.
    ("termite_worker", 14, pal("#0e0a06", "#9a8a6a", "#b8a888", "#000000", "#6a4a24", PALE, CREAM_HEAD, g="#3a2a1a"),
        termite(s=0.85, antenna=0.9)),
    # Soldiers: a long armoured amber head with black sabre jaws.
    ("termite_soldier", 14, pal("#0e0804", "#9a8a6a", "#b8a888", "#000000", "#120806", PALE,
        ("#5a2408", "#8a3c10", "#b65e1c", "#d8822e", "#ffd090"), g="#3a2a1a"),
        termite(s=0.9, head=1.25, head_len=1.6, mandible=1.1, antenna=0.75)),
    # Nasutes: a dark pear-shaped head drawn out into a glue nozzle, no jaws.
    ("termite_nasute", 14, pal("#0a0604", "#8a7a5a", "#a89878", "#000000", "#2a1a10",
        ("#3e3226", "#625240", "#8a7860", "#ac9a80", "#e8dcc4"),
        ("#120a06", "#24160c", "#3c2818", "#58402a", "#c8a882"), n="#2c1c10", N="#f0e8a0", g="#2a1e14"),
        termite(s=0.82, head=1.3, nasus=1.1, antenna=0.75)),
    # Neotenics (brood makers): plump, yellower, eyes and little wing pads, swelling with eggs.
    ("termite_neotenic", 10, pal("#100a04", "#a08a5a", "#c0a878", "#1a0e06", "#6a4a24",
        ("#5a4424", "#8e7038", "#bc9a52", "#dcbc70", "#fff4c0"), ("#5a3c1c", "#86602c", "#ae8240", "#d0a45a", "#ffe0a0"),
        MEMBRANE, W="#6a4a2a", g="#4a3418"),
        termite(s=0.95, abdomen=1.25, ab_len=1.15, eyes=True, wingpads=0.7, gut=False, physo=0.18, leg=0.95)),
    # The king: a dark chestnut former alate, wing stubs at his shoulders.
    ("termite_king", 10, pal("#080402", "#5a3a20", "#7a5434", "#050302", "#2a1408",
        ("#1e0e06", "#341a0c", "#4e2a14", "#6a3c1e", "#d0a07a"), ("#24120a", "#3c1e10", "#5a2e18", "#7a4224", "#e0b088"),
        W="#a08868", g="#100804"),
        termite(s=1.05, abdomen=1.05, eyes=True, wingpads=0.5, gut=False, leg=1.05, antenna=1.0)),
    # The queen: tiny chestnut front end, an enormous egg-swollen abdomen.
    ("termite_queen", 6, pal("#0a0604", "#5a3a20", "#7a5434", "#050302", "#2a1408",
        ("#3a200e", "#5a3418", "#7a4a24", "#9a6232", "#e0b088"), ("#24120a", "#3c1e10", "#5a2e18", "#7a4224", "#e0b088"),
        MEMBRANE, W="#a08868", g="#100804"),
        termite(s=1.2, physo=1.0, eyes=True, wingpads=0.4, gut=False, leg=0.85, antenna=0.9, frames=2), {"directions": 16}),
    ("termite_eggs", 3, pal("#1a1408", "#000000", "#000000", "#000000", "#000000", PALE, CREAM_HEAD,
        ("#9a8c70", "#c4b698", "#e4d8bc", "#f6eedc", "#ffffff")), egg_clutch(), {"rotate": False}),
]

out = ["-- Termite sprites (generated by tools/make_termite_sprites.py, safe to hand-edit).",
       "-- Face right; the game bakes rotations so they turn toward where they move.",
       "-- Ramps: 1..4/h abdomen, A..D/H head and thorax, P..S/U membrane and eggs, o = soft outline,",
       "-- l = legs, L = antenna beads, g = gut, w = jaws, n/N = nasute nozzle, W = wing pads, e = eyes.",
       "return {"]
for entry in SPRITES:
    sid, fps, p, frames = entry[:4]
    opts = entry[4] if len(entry) > 4 else {}
    out.append("    {")
    out.append(f'        id = "{sid}",')
    out.append(f"        fps = {fps},")
    if "directions" in opts: out.append(f"        directions = {opts['directions']},")
    if opts.get("rotate") is False: out.append("        rotate = false,")
    out.append("        palette = { " + ", ".join(f'["{k}"] = "{v}"' for k, v in p.items()) + " },")
    out.append("        frames = {")
    for fr in frames:
        out.append("            {")
        for r in fr: out.append(f'                "{r}",')
        out.append("            },")
    out.append("        },")
    out.append("    },")
out.append("}")
open("content/sprites/termites.lua", "w").write("\n".join(out) + "\n")
print("wrote", len(SPRITES))
