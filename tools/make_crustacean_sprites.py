# Generates the crustacean enemy sprites (shrimp, krill and plankton) as text-grid Lua.
#   python3 tools/make_crustacean_sprites.py   ->  content/sprites/crustaceans.lua
# Same look as tools/make_hymenoptera_sprites.py (lit ellipsoids quantised to colour ramps, soft
# outline, facing right, the game bakes the rotations), with what crustaceans need on top:
#   - a segmented shrimp body: carapace with a rostrum spike, a tapering tail of segments and a
#     tail fan (t / T), whip antennae (a) that sway, swimmerets and walking legs (l) that paddle
#   - see-through shells: ramp colours carry alpha for glass shrimp, water fleas and copepods
#   - glow spots (g / G) for krill photophores and the sea firefly's blue light
#   - three colour ramps 1..4/h, A..D/H and 5..8/j, so stripes and bands are easy
# Its own script (helpers copied) so it never clashes with the other sprite generators.
import math, random

LIGHT = (-0.55, -0.65, 0.55)
_l = math.sqrt(sum(c * c for c in LIGHT))
LIGHT = tuple(c / _l for c in LIGHT)
RAMP1 = ('1', '2', '3', '4', 'h')
RAMP2 = ('A', 'B', 'C', 'D', 'H')
RAMP3 = ('5', '6', '7', '8', 'j')
RAMPS = {1: RAMP1, 2: RAMP2, 3: RAMP3}
SHELL = '1234hABCDH5678j'
BODY = set(SHELL + 'eEgGtTsk')

def blank(w, h): return [['.'] * w for _ in range(h)]

def put(g, x, y, ch, only=None):
    x, y = int(round(x)), int(round(y))
    if 0 <= y < len(g) and 0 <= x < len(g[0]):
        if only is not None and g[y][x] not in only: return
        g[y][x] = ch

def shade(dx, dy, d2, ramp, spec=True, bias=0.0):
    nz = math.sqrt(max(0.0, 1 - d2))
    i = dx * LIGHT[0] + dy * LIGHT[1] + nz * LIGHT[2] + bias
    if spec and i > 0.95: return ramp[4]
    if i > 0.62: return ramp[3]
    if i > 0.32: return ramp[2]
    if i > 0.05: return ramp[1]
    return ramp[0]

def blob(g, cx, cy, rx, ry, ramp=RAMP1, spec=True, bias=0.0):
    for y in range(len(g)):
        for x in range(len(g[0])):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            d2 = dx * dx + dy * dy
            if d2 <= 1.0: g[y][x] = shade(dx, dy, d2, ramp, spec, bias)

def line(g, pts, ch, only=None):
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n + 1):
            t = i / n
            put(g, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, ch, only)

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

def both(g, pts, ch, cy, only=None):
    line(g, pts, ch, only); line(g, mirror(pts, cy), ch, only)

def eye(g, x, y, r, glint=True):
    for yy in range(len(g)):
        for xx in range(len(g[0])):
            if ((xx - x) / r) ** 2 + ((yy - y) / r) ** 2 <= 1: g[yy][xx] = 'e'
    if glint: put(g, x - r * 0.3, y - r * 0.3, 'E')

# ---- shrimp and krill --------------------------------------------------------------------------
def shrimp(sid, s, segs=6, cw=1.0, tw=1.0, fan=1.0, ant=1.0, rost=1.0, eyes=1.0, legs=1.0,
           seg_ramp=None, cara=1, glow=None, spots=None, stripe=None, frames=4, krill=False, gut=False):
    """One shrimp (or krill) from above, facing right. Sizes are in units of s (about a pixel).
    segs abdomen segments, cw carapace width, tw tail width, fan tail-fan size, ant antenna
    length, rost rostrum length, eyes eye size, legs leg length; seg_ramp(i) picks a ramp per
    segment (bands), cara the carapace ramp, glow = list of segment indexes with a photophore,
    spots = ramp char sprinkled on the shell, stripe = a ramp char run down the back."""
    rng = random.Random(sid)
    crx, cry = 2.4 * s, 1.55 * s * cw           # carapace
    seg_len = 1.05 * s
    tail_len = segs * seg_len
    fan_len = 1.8 * s * fan
    m = 2
    fan_x0 = m
    tail_x0 = fan_x0 + fan_len
    cx = tail_x0 + tail_len + crx * 0.75
    head_x = cx + crx
    rost_len = 2.2 * s * rost
    ant_len = 6.5 * s * ant
    w = int(math.ceil(head_x + rost_len + 2.5 * s * ant)) + 3
    half = int(math.ceil(max(cry + 2.0 * s * legs, 2.0 * s * fan + 1, cry + 2.8 * s * ant + 0.8 * s, cry + 1))) + 2
    h, cy = half * 2 + 1, half

    def body(g, f):
        flex = math.sin(f / frames * 2 * math.pi) * 0.25 * s
        # tail fan: telson down the middle and two uropods either side, see-through edges
        fy = cy + flex
        for yy in range(len(g)):
            for xx in range(len(g[0])):
                t = (xx - fan_x0) / max(0.1, fan_len)          # 0 at the tip, 1 at the root
                if 0 <= t <= 1:
                    halfw = (2.0 - 1.25 * t) * s * fan * tw
                    dy = yy - fy
                    if abs(dy) <= halfw:
                        g[yy][xx] = 'T' if abs(dy) > halfw * 0.6 or t < 0.18 else 't'
        # abdomen segments, back to front, each a little wider and lit like a shell plate
        for i in range(segs):
            k = (i + 0.5) / segs
            sx = tail_x0 + (i + 0.5) * seg_len
            sy = cy + flex * (1 - k)
            ry = (0.95 + 0.55 * k) * s * tw * (0.9 + 0.1 * cw)
            ramp = RAMPS[seg_ramp(i) if seg_ramp else 1]
            blob(g, sx, sy, seg_len * 0.62, ry, ramp)
        # carapace over the front
        blob(g, cx, cy, crx, cry, RAMPS[cara])
        # plate seams between segments
        for i in range(1, segs):
            sx = tail_x0 + i * seg_len
            for yy in range(len(g)):
                xx = int(round(sx))
                if 0 <= xx < len(g[0]) and g[yy][xx] in SHELL and rng.random() < 0.85:
                    c = g[yy][xx]
                    r = RAMP1 if c in RAMP1 else RAMP2 if c in RAMP2 else RAMP3
                    g[yy][xx] = r[max(0, r.index(c) - 1)]
        if stripe:
            line(g, [(tail_x0 + 0.5, cy + flex), (cx + crx * 0.7, cy)], stripe, SHELL)
        if spots:
            for yy in range(len(g)):
                for xx in range(len(g[0])):
                    if g[yy][xx] in SHELL and rng.random() < 0.12: g[yy][xx] = spots
        if glow:
            for i in glow:
                sx = tail_x0 + (i + 0.5) * seg_len if i >= 0 else cx - crx * 0.4
                put(g, sx, cy + (flex * (1 - (i + 0.5) / segs) if i >= 0 else 0), 'G')
        # the gut line, faint, along the middle (shows through see-through shells)
        if gut: line(g, [(tail_x0 + seg_len, cy + flex * 0.6), (cx - crx * 0.3, cy)], 'k', '1234')
        # eyes on stalks at the front corners
        er = max(0.6, 0.55 * s * eyes)
        for sg in (-1, 1):
            ex, ey = head_x - crx * 0.15, cy + sg * (cry * 0.75 + er * 0.4)
            line(g, [(head_x - crx * 0.5, cy + sg * cry * 0.4), (ex, ey)], 's')
            eye(g, ex, ey, er)
        # rostrum spike forward
        if rost:
            line(g, [(head_x - 0.5, cy), (head_x + rost_len, cy - 0.2 * s)], 's')

    def appendages(g, f):
        ph = f / frames * 2 * math.pi
        # three pairs of walking legs under the carapace, a fringe of swimmerets under the tail;
        # they paddle in a wave from back to front
        for i in range(3):
            bx = cx + crx * (0.45 - 0.45 * i)
            sw = math.sin(ph + i * 1.3) * 0.5 * s
            for sg in (-1, 1):
                by = cy + sg * cry * 0.7
                line(g, [(bx, by), (bx + 0.3 * s + sw, by + sg * 1.3 * s * legs), (bx - 0.2 * s + sw, by + sg * 1.9 * s * legs)], 'l', '.')
        for i in range(segs - 1):
            k = (i + 0.5) / segs
            bx = tail_x0 + (i + 0.6) * seg_len
            sw = math.sin(ph * 2 + i * 0.9) * 0.4 * s
            for sg in (-1, 1):
                by = cy + sg * (0.95 + 0.55 * k) * s * tw * 0.8
                line(g, [(bx, by), (bx - 0.3 * s + sw, by + sg * 0.9 * s * legs)], 'l', '.')
        # whip antennae: out from the head and sweeping back past the body; short antennules forward
        sway = math.sin(ph) * 0.7 * s
        for sg in (-1, 1):
            root = (head_x - 0.3 * s, cy + sg * cry * 0.45)
            if krill:
                pts = [root, (head_x + 1.6 * s * ant, cy + sg * (cry + 0.6 * s * ant)),
                       (head_x + ant_len * 0.55, cy + sg * (cry + 1.4 * s * ant) + sway)]
            else:
                pts = [root, (head_x + 1.2 * s, cy + sg * (cry + 1.0 * s)),
                       (cx - crx * 0.2, cy + sg * (cry + 2.1 * s * ant) + sway * 0.5),
                       (tail_x0 + tail_len * (1 - 0.7 * ant), cy + sg * (cry + 2.6 * s * ant) + sway)]
            line(g, pts, 'a', '.o')
            line(g, [root, (head_x + 1.4 * s * ant, cy + sg * 0.6 * s), (head_x + 2.2 * s * ant, cy + sg * (0.9 * s + sway * 0.3))], 'a', '.o')

    out = []
    for f in range(frames):
        g = blank(w, h)
        appendages(g, f)
        body(g, f)
        outline(g)
        out.append([''.join(r) for r in g])
    return out

# ---- plankton ----------------------------------------------------------------------------------
def copepod(sid, s, frames=4, tail=1.0, ant=1.0):
    """A copepod: a teardrop body, one red eye at the front, long antennae swept out like oars
    (they stroke back and snap forward), a forked tail with long bristles."""
    out = []
    for f in range(frames):
        stroke = (0.0, 0.55, 1.0, 0.4)[f % 4]
        bl = 4.8 * s
        w = int(bl + 7 * s * tail + 3 * s) + 4
        half = int(6.2 * s * ant) + 2
        h, cy = half * 2 + 1, half
        g = blank(w, h)
        tail_len = 2.8 * s * tail
        x0 = 2 + tail_len
        hx = x0 + bl * 0.62
        # antennae: long, from the head, swept out and back by the stroke
        for sg in (-1, 1):
            a = (0.25 + 0.95 * stroke)          # angle back from straight out
            L = 5.8 * s * ant
            tip = (hx - math.sin(a) * L, cy + sg * math.cos(a) * L)
            mid = (hx + 0.3 * s - math.sin(a) * L * 0.4, cy + sg * (math.cos(a) * L * 0.45 + 0.6 * s))
            line(g, [(hx + 0.6 * s, cy + sg * 0.6 * s), mid, tip], 'a')
            put(g, tip[0], tip[1], 'T')
        # the tail fork and its bristles
        for sg in (-1, 1):
            line(g, [(x0, cy), (x0 - tail_len * 0.6, cy + sg * 0.8 * s), (2, cy + sg * 1.4 * s)], 't')
            put(g, 1, cy + sg * 1.6 * s, 'T'); put(g, 2, cy + sg * 2.0 * s, 'T')
        # body: a tapering run of plates, round head at the front
        for i in range(4):
            k = i / 3
            blob(g, x0 + bl * 0.15 * i, cy, 0.8 * s, (0.55 + 0.35 * k) * s, RAMP2)
        blob(g, hx, cy, bl * 0.42, 1.45 * s, RAMP1)
        line(g, [(x0 + 0.5, cy), (hx - 0.5 * s, cy)], 'k', SHELL)       # gut
        put(g, hx + bl * 0.3, cy, 'g')                                   # the single eye
        put(g, x0 + bl * 0.35, cy, 'G', SHELL)                           # an egg sac / oil drop
        outline(g)
        out.append([''.join(r) for r in g])
    return out

def water_flea(sid, s, frames=4):
    """A water flea (Daphnia): a round see-through shell with the gut and a dark eye showing
    through, a spine at the back and two big branched antennae that row it along in hops."""
    out = []
    for f in range(frames):
        stroke = (0.0, 0.6, 1.0, 0.5)[f % 4]
        rx, ry = 2.6 * s, 2.2 * s
        w = int(rx * 2 + 4.5 * s + 2 * s) + 5
        half = int(ry + 3.4 * s) + 2
        h, cy = half * 2 + 1, half
        g = blank(w, h)
        x0 = 2 + 2.0 * s
        bx = x0 + rx
        hx = bx + rx * 0.75
        # rowing antennae, each with two branches
        for sg in (-1, 1):
            a = 0.3 + 1.0 * stroke
            root = (hx, cy + sg * 0.9 * s)
            elbow = (hx + 0.6 * s - math.sin(a) * 1.4 * s, cy + sg * (1.6 * s + math.cos(a) * 1.2 * s))
            line(g, [root, elbow], 'a')
            for br in (-0.35, 0.35):
                L = 2.4 * s
                tip = (elbow[0] - math.sin(a + br) * L, elbow[1] + sg * math.cos(a + br) * L)
                line(g, [elbow, tip], 'a')
                put(g, tip[0], tip[1], 'T')
        # the tail spine
        line(g, [(bx - rx + 0.5, cy), (2, cy + 0.4 * s)], 't')
        blob(g, bx, cy, rx, ry, RAMP1)
        blob(g, hx, cy, 1.0 * s, 1.0 * s, RAMP2)                          # head
        # the gut curling through the body, eggs in the brood pouch, the eye
        line(g, [(hx - 0.4 * s, cy), (bx, cy + 0.5 * s), (bx - rx * 0.6, cy)], 'k', SHELL)
        for ex, ey in ((bx - rx * 0.25, cy - ry * 0.45), (bx + rx * 0.05, cy - ry * 0.5)):
            put(g, ex, ey, 'G', SHELL)
        eye(g, hx + 0.5 * s, cy, max(0.6, 0.55 * s))
        outline(g)
        out.append([''.join(r) for r in g])
    return out

def ostracod(sid, s, frames=4):
    """A sea firefly (ostracod): a bean of a shell, two valves with a seam down the middle, a
    pair of paddle antennae poking out the front, and a blue glow at its heart."""
    out = []
    for f in range(frames):
        stroke = (0.0, 0.6, 1.0, 0.5)[f % 4]
        rx, ry = 2.4 * s, 1.75 * s
        w = int(rx * 2 + 3.5 * s) + 5
        half = int(ry + 2.6 * s) + 2
        h, cy = half * 2 + 1, half
        g = blank(w, h)
        bx = 2 + rx
        for sg in (-1, 1):
            a = 0.2 + 0.9 * stroke
            root = (bx + rx * 0.8, cy + sg * 0.6 * s)
            tip = (root[0] + math.cos(a) * 2.6 * s, root[1] + sg * math.sin(a) * 2.6 * s)
            line(g, [root, tip], 'a')
            put(g, tip[0], tip[1], 'T')
        blob(g, bx, cy - 0.15 * s, rx, ry, RAMP1, bias=0.05)
        line(g, [(bx - rx + 0.5, cy), (bx + rx - 0.5, cy)], 'k', SHELL)   # the seam
        for gx, gy in ((bx - 0.2 * s, cy - 0.6 * s), (bx + 0.4 * s, cy + 0.6 * s), (bx - 0.8 * s, cy + 0.5 * s)):
            put(g, gx, gy, 'G', SHELL)
        put(g, bx + 0.2 * s, cy - 0.5 * s, 'g', SHELL)
        eye(g, bx + rx * 0.55, cy - 0.7 * s, max(0.5, 0.4 * s), glint=False)
        outline(g)
        out.append([''.join(r) for r in g])
    return out

# ---- palettes ----------------------------------------------------------------------------------
SOFT = "b0"
def ramp(chars, cols): return dict(zip(chars, cols))
def P(o, l, a, s, r1, r2=None, r3=None, tail=("#e0c0b0", "#c09080"), e="#0a0606", E="#ffffff",
      glow=("#a0f0ff", "#4ac8ff"), gut="#6a3a2a"):
    d = dict(o=o + SOFT, l=l, a=a, s=s, e=e, E=E, t=tail[0], T=tail[1], g=glow[0], G=glow[1], k=gut)
    d.update(ramp(RAMP1, r1)); d.update(ramp(RAMP2, r2 or r1)); d.update(ramp(RAMP3, r3 or r2 or r1))
    return d

def alpha(r, a): return tuple(c + a for c in r)

GLASS = ("#7a9098", "#9ab4bc", "#bcd4d8", "#dceef0", "#ffffff")
CHERRY = ("#5a0a10", "#8a1418", "#b82424", "#e0443a", "#ffb0a0")
BLUE = ("#0a1a4a", "#12307a", "#1e4ca8", "#3a74d0", "#c0dcff")
TIGER_A = ("#5a4a3a", "#7a6a54", "#9a8a70", "#b8aa8e", "#f0e8d8")
TIGER_B = ("#1a1410", "#2a2018", "#3a2e22", "#4e4030", "#a09080")
CLEAN_R = ("#5a0a0a", "#8a1410", "#b82018", "#e03a28", "#ffb090")
CLEAN_W = ("#9a9490", "#c0bab4", "#e0dad4", "#f4f0ec", "#ffffff")
PINK = ("#6a1a20", "#9a2a30", "#c84a48", "#e8746a", "#ffd0c0")
LANTERN = ("#1a2a4a", "#2a4470", "#3a6498", "#5a8ac0", "#d0e8ff")
COPE = ("#7a3a0a", "#a85a14", "#d0801e", "#eca440", "#fff0c0")
COPE_T = ("#5a2a08", "#844010", "#a85a18", "#c87a28", "#f0c080")
FLEA = ("#4a6a30", "#6a8a44", "#8aaa5c", "#aac87a", "#e8ffd0")
FIREFLY = ("#0a1a2a", "#14304a", "#1e4a6a", "#2e6a8a", "#a8e0ff")

SPRITES = []
SMALL = {"pink_krill", "lantern_krill", "copepod", "water_flea", "sea_firefly"}
def add(sid, fps, pal, frames, **opts): SPRITES.append((sid, fps, pal, frames, opts))

def alt(a, b, every=1):
    return lambda i: a if (i // every) % 2 == 0 else b

# shrimp
add("glass_shrimp", 12, P("#2a3a40", "#c8dce060", "#d8e8ec90", "#a8c0c8c0", alpha(GLASS, "90"), alpha(GLASS, "70"),
        tail=("#dceef060", "#bcd4d890"), gut="#c8783a", e="#101418"),
    shrimp("glass_shrimp", 1.25, cw=0.95, tw=0.9, gut=True))
add("cherry_shrimp", 12, P("#2a0606", "#c84030", "#e86050", "#ff8a70", CHERRY, CHERRY,
        tail=("#e8605080", "#b82424c0"), gut="#5a1010"),
    shrimp("cherry_shrimp", 1.35, spots='4'))
add("blue_shrimp", 12, P("#060a2a", "#3a64c0", "#5a8ae0", "#80b0ff", BLUE, BLUE,
        tail=("#5a8ae080", "#1e4ca8c0"), gut="#0a1a3a"),
    shrimp("blue_shrimp", 1.45, cw=1.05, stripe='H'))
add("tiger_shrimp", 10, P("#0e0a08", "#8a7a60", "#b0a080", "#d0c0a0", TIGER_A, TIGER_B,
        tail=("#d0a03ac0", "#3a6ab0e0"), gut="#3a2a1a"),
    shrimp("tiger_shrimp", 2.1, segs=6, cw=1.1, tw=1.05, fan=1.1, seg_ramp=alt(1, 2), rost=1.2))
add("cleaner_shrimp", 12, P("#1a0606", "#f4f0ec", "#ffffff", "#ffffff", CLEAN_R, CLEAN_W, CLEAN_W,
        tail=("#e03a28c0", "#f4f0ece0"), gut="#5a1010"),
    shrimp("cleaner_shrimp", 1.55, cw=1.0, ant=1.35, stripe='C', legs=1.3))
# krill
add("pink_krill", 14, P("#2a0808", "#e8746a90", "#f0a090a0", "#e87460", alpha(PINK, "e0"), alpha(PINK, "c0"),
        tail=("#e8746a70", "#c84a48a0"), glow=("#c0f0ff", "#60d0ff"), gut="#3a5a2a", e="#000000"),
    shrimp("pink_krill", 0.95, segs=6, cw=0.85, tw=0.85, fan=0.8, ant=0.9, rost=0.6, eyes=1.5, legs=0.8,
           glow=[1, 3], krill=True, gut=True))
add("lantern_krill", 14, P("#060a1a", "#5a8ac090", "#80b0e0a0", "#5a8ac0", alpha(LANTERN, "e0"), alpha(LANTERN, "c0"),
        tail=("#5a8ac070", "#3a6498a0"), glow=("#e0fcff", "#5ae0ff"), gut="#1a2a3a", e="#000000"),
    shrimp("lantern_krill", 1.05, segs=6, cw=0.9, tw=0.85, fan=0.85, ant=1.0, rost=0.7, eyes=1.6, legs=0.8,
           glow=[-1, 0, 2, 4], krill=True, gut=True))
# plankton
add("copepod", 10, P("#2a1406", "#d0801e", "#e8a04880", "#d0801e", alpha(COPE, "e0"), alpha(COPE_T, "e0"),
        tail=("#e8a048a0", "#fff0c080"), glow=("#ff2a1a", "#4ac0ff"), gut="#6a3a10"),
    copepod("copepod", 1.25))
add("water_flea", 8, P("#1a2a10", "#8aaa5c", "#aac87ac0", "#8aaa5c", alpha(FLEA, "a0"), alpha(FLEA, "d0"),
        tail=("#aac87ac0", "#e8ffd080"), glow=("#ffe060", "#e8a030"), gut="#4a3010"),
    water_flea("water_flea", 1.15))
add("sea_firefly", 10, P("#04101a", "#2e6a8a", "#5aa0c0c0", "#2e6a8a", FIREFLY,
        tail=("#a8e0ffc0", "#e0fcff"), glow=("#e0fcff", "#3ad8ff"), gut="#061420", e="#000000"),
    ostracod("sea_firefly", 1.35))

out = ["-- Crustacean enemy sprites: shrimp, krill and plankton (generated by",
       "-- tools/make_crustacean_sprites.py, safe to hand-edit). Face right; the game bakes rotations.",
       "-- Ramps: 1..4/h, A..D/H, 5..8/j (dark..light/gloss), o = soft outline, l = legs, a = antennae,",
       "-- s = eye stalks and rostrum, e/E = eyes, t/T = tail fan, g/G = glow spots, k = gut.",
       "return {"]
for sid, fps, pal, frames, opts in SPRITES:
    out.append("    {")
    out.append(f'        id = "{sid}",')
    out.append(f"        fps = {fps},")
    if sid in SMALL: out.append("        directions = 24,      -- tiny: fewer baked turns keeps the atlas small")
    used = set(''.join(''.join(fr) for fr in frames))
    pal = {k: v for k, v in pal.items() if k in used}
    out.append("        palette = { " + ", ".join(f'["{k}"] = "{v}"' for k, v in pal.items()) + " },")
    out.append("        frames = {")
    for fr in frames:
        out.append("            {")
        for r in fr: out.append(f'                "{r}",')
        out.append("            },")
    out.append("        },")
    out.append("    },")
out.append("}")
open("content/sprites/crustaceans.lua", "w").write("\n".join(out) + "\n")
print("wrote", len(SPRITES))
