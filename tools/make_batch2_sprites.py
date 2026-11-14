# Generates the batch 2 playable bugs (camel spider, hissing roach, tailless whip scorpion,
# vinegaroon, mantis shrimp, pistol shrimp, millipede) as text-grid Lua.
#   python3 tools/make_batch2_sprites.py   ->  content/sprites/batch2.lua
# Same look and helpers as tools/make_bug_sprites.py (copied so this runs on its own without
# regenerating bugs.lua). Each bug gets a whole sprite (icons), a legs entry that only carries
# the 3D leg rig, and an iso body for the stacked model.
import math

LIGHT = (-0.55, -0.65, 0.55)
_l = math.sqrt(sum(c * c for c in LIGHT))
LIGHT = tuple(c / _l for c in LIGHT)
RAMP1 = ('1', '2', '3', '4', 'h')
RAMP2 = ('A', 'B', 'C', 'D', 'H')
BODY = set('1234hABCDHwseSbmfFgvW')

def blank(w, h): return [['.'] * w for _ in range(h)]

def put(g, x, y, ch, only_empty=False):
    x, y = int(round(x)), int(round(y))
    if 0 <= y < len(g) and 0 <= x < len(g[0]):
        if only_empty and g[y][x] != '.': return
        g[y][x] = ch

def blob(g, cx, cy, rx, ry, ramp=RAMP1, spec=True, bias=0.0):
    for y in range(len(g)):
        for x in range(len(g[0])):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            d2 = dx * dx + dy * dy
            if d2 <= 1.0:
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

# Tripod gait: legs (front, mid, hind) on the top side use phases (+,-,+), bottom side (-,+,-).
GAIT = (0.0, 1.0, 0.0, -1.0)   # stride offset per frame

# part: None = whole bug, "legs" = legs/antennae only, "body" = body only (one frame).
# The split parts let the player be drawn in 3D: legs on the ground, body raised and stacked.
RIG = {}   # last leg layout seen by walk_frames (for the procedural 3D legs in game)

def walk_frames(w, h, cy, legs_fn, body_fn, extra_fn=None, frames=4, leg_ch='l', part=None):
    out = []
    RIG["last"] = dict(w=w, h=h, legs=[leg(0) for leg in legs_fn()])
    if part == "body": frames = 1
    if part == "legs": frames = 8       # smoother walk for the player's legs
    for f in range(frames):
        g = blank(w, h)
        phase = GAIT[f % 4] if frames == 4 else (1, -1)[f % 2] if frames == 2 else math.sin(f / frames * math.pi * 2) * 1.7
        if part == "legs":
            # The player's legs get a real step cycle: each foot is planted (and slides back
            # under the body as it walks) for 60% of the cycle, then lifts, swings forward and
            # plants again. Lifted feet are tucked in and lighter, planted ones dark claws.
            feet = []
            for i, leg in enumerate(legs_fn()):
                for side in (0, 1):
                    t = (f / frames + (0.5 if (i % 2) != side else 0.0)) % 1.0
                    if t < 0.6:
                        off, lift = 1.7 - 3.4 * (t / 0.6), 0.0
                    else:
                        k = (t - 0.6) / 0.4
                        off, lift = -1.7 + 3.4 * (k * k * (3 - 2 * k)), math.sin(k * math.pi)
                    pts = leg(off)
                    (x0, y0), (x1, y1) = pts[-2], pts[-1]
                    tuck = 0.3 * lift
                    pts = pts[:-1] + [(x1 + (x0 - x1) * tuck, y1 + (y0 - y1) * tuck)]
                    if side: pts = mirror(pts, cy)
                    line(g, pts, leg_ch)
                    feet.append((pts[-1], pts[-2], lift))
            for (fx, fy), (px, py), lift in feet:
                if lift > 0.15:
                    put(g, fx, fy, 'T')          # raised foot catches the light
                else:
                    dx, dy = fx - px, fy - py
                    l = math.hypot(dx, dy) or 1
                    put(g, fx, fy, 't')          # planted tarsus and claw
                    put(g, fx + dx / l, fy + dy / l, 't')
        elif part != "body":
            for i, leg in enumerate(legs_fn()):
                sign = 1 if i % 2 == 0 else -1
                line(g, leg(phase * sign), leg_ch)
                line(g, mirror(leg(-phase * sign), cy), leg_ch)
        if part != "legs": body_fn(g)
        outline(g)
        if extra_fn and part != "body": extra_fn(g, f)
        out.append([''.join(r) for r in g])
    return out

# ---- More playable bugs ---------------------------------------------------------------------
# critter(): a generic builder. segs = body blobs (cx, rx, ry, ramp, spec) along the midline;
# legs = top-side legs as (root, knee, tip) points (mirrored for the other side; the gait swings
# the tip by p and the knee by 0.4 p); deco(g) paints details on the body; extra(g, f) runs after
# the outline on whole/leg frames (antennae, leg bands).
def critter(w, h, cy, segs, legs, deco=None, extra=None, part=None, stride=1.0):
    def body(g):
        for (cx, rx, ry, rmp, spec) in segs:
            blob(g, cx, cy + 0, rx, ry, rmp, spec=spec)
        if deco: deco(g)
    def legs_fn():
        out = []
        for (r, k, t) in legs:
            out.append(lambda p, r=r, k=k, t=t: [r, (k[0] + 0.4 * p * stride, k[1]), (t[0] + p * stride, t[1])])
        return out
    return walk_frames(w, h, cy, legs_fn, body, extra, part=part)

def seg(cx, rx, ry, rmp=RAMP1, spec=True): return (cx, rx, ry, rmp, spec)

def both(g, pts, ch, cy, only_empty=False):
    line(g, pts, ch, only_empty); line(g, mirror(pts, cy), ch, only_empty)

def antennae(pts, cy, ch='l'):
    def extra(g, f):
        twitch = 0.5 if f in (1, 2) else 0
        a = pts[:-1] + [(pts[-1][0], pts[-1][1] - twitch)]
        both(g, a, ch, cy, True)
    return extra

def ramp(c1, c2, c3, c4, hi): return {"1": c1, "2": c2, "3": c3, "4": c4, "h": hi}
def ramp2(c1, c2, c3, c4, hi): return {"A": c1, "B": c2, "C": c3, "D": c4, "H": hi}

SOFT = "b0"   # outline alpha (hex) for a softer, less cartoony edge


# ---- Batch 2 playable bugs ------------------------------------------------------------------

def hairs(ch_from='l', ch_to='m', mod=3):
    def f(g, fr=None):
        for y in range(len(g)):
            for x in range(len(g[0])):
                if g[y][x] == ch_from and (x + 2 * y) % mod == 0: g[y][x] = ch_to
    return f

def camel_spider(part=None):
    """Camel spider (solifuge): sandy and hairy, long abdomen, huge forward jaws (chelicerae),
    and leg-like pedipalps held out in front like a fifth pair of legs."""
    w, h, cy = 42, 38, 19
    def deco(g):
        for x in (6, 8.5, 11, 13.5):                                     # abdomen segments
            line(g, [(x, cy - 3.8), (x + 0.4, cy), (x, cy + 3.8)], '2')
        line(g, [(4, cy), (15, cy)], 'b')
        for sg in (-1, 1):
            blob(g, 27, cy + sg * 1.9, 3.8, 1.9, RAMP2)                   # the two great jaws
            line(g, [(28.5, cy + sg * 2.6), (30.6, cy + sg * 1.6), (31.4, cy + sg * 0.5)], 'w')
            line(g, [(28.6, cy + sg * 1.2), (30, cy + sg * 0.6)], 'w')
            line(g, [(24.5, cy + sg * 2.8), (27.5, cy + sg * 3.2)], 'B')  # jaw ridge
        put(g, 22.4, cy - 0.6, 'e'); put(g, 22.4, cy + 0.6, 'e')        # the two eyes on a tubercle
    legs = [((22, cy - 2.6), (27, cy - 7), (34, cy - 9)),                # pedipalps, held forward
            ((21, cy - 3.2), (23, cy - 9.5), (25, cy - 15)),
            ((19.5, cy - 3.4), (17.5, cy - 10.5), (16, cy - 16.5)),
            ((18, cy - 3.0), (13, cy - 9.5), (8, cy - 14)),
            ((17, cy - 2.4), (10, cy - 6.5), (3, cy - 9))]
    def extra(g, f):
        hairs('l', 'm', 3)(g)
        for (r, k, t) in legs[:1]:                                        # pale palp tips (suckers)
            for pt in (t, (t[0], 2 * cy - t[1])): put(g, pt[0], pt[1], 'b')
    return critter(w, h, cy, [seg(10, 7.6, 4.6), seg(20.5, 3.4, 3.6, RAMP2)], legs, deco, extra, part, stride=1.1)

def hissing_roach(part=None):
    """Madagascar hissing cockroach: big, wingless, glossy chestnut-black plates with amber bands,
    a domed pronotum with two horn bumps and short antennae."""
    w, h, cy = 38, 26, 13
    def deco(g):
        for x in (6, 9.2, 12.4, 15.6, 18.8):                              # abdominal plates
            line(g, [(x, cy - 6.2), (x - 0.8, cy), (x, cy + 6.2)], 'S')
            line(g, [(x + 0.8, cy - 5.8), (x + 0.2, cy), (x + 0.8, cy + 5.8)], '1')
        line(g, [(22, cy - 5), (22, cy + 5)], '1')
        for sg in (-1, 1):
            blob(g, 25.4, cy + sg * 1.8, 1.4, 1.2, RAMP2, bias=0.15)       # horn bumps on the pronotum
            put(g, 30.2, cy + sg * 1.5, 'e')
            for x in range(5, 21, 3): put(g, x, cy + sg * 6.6, 's')      # breathing holes (they hiss through these)
    legs = [((26, cy - 3), (28.5, cy - 7), (31, cy - 10)), ((21, cy - 5.5), (21, cy - 9.5), (19, cy - 12.5)),
            ((16, cy - 6), (12, cy - 9.5), (7, cy - 12))]
    def extra(g, f):
        hairs('l', 'm', 4)(g)
        antennae([(30.5, cy - 1.2), (33, cy - 3.5), (36, cy - 4.5)], cy)(g, f)
    return critter(w, h, cy, [seg(13.5, 11.2, 6.6), seg(25, 4.0, 5.6, RAMP2), seg(29.6, 1.6, 2.6, RAMP2, False)],
                   legs, deco, extra, part, stride=1.2)

def whip_scorpion(part=None):
    """Tailless whip scorpion (amblypygid): flat and wide, a kidney-shaped carapace, ribbed round
    abdomen, spiny raptorial palps folded in front and walking legs splayed sideways. Its
    whip-thin feeler legs are drawn in game so they can sweep about."""
    w, h, cy = 44, 44, 22
    def deco(g):
        for x in (5.5, 8, 10.5, 13):
            line(g, [(x, cy - 4.4), (x + 0.6, cy), (x, cy + 4.4)], '1')
        line(g, [(17.5, cy - 4), (21, cy), (17.5, cy + 4)], 'A')          # carapace groove
        put(g, 24.6, cy - 0.5, 'e'); put(g, 24.6, cy + 0.5, 'e')
        for sg in (-1, 1):
            put(g, 22, cy + sg * 4.6, 'e')
            pts = [(23, cy + sg * 3), (27, cy + sg * 7), (31, cy + sg * 5.5), (29, cy + sg * 1.8)]   # folded palps
            line(g, pts, 'B'); line(g, [(x, y - sg * 0.6) for x, y in pts[:3]], 'D')
            for (x, y) in ((26, cy + sg * 6.9), (28, cy + sg * 7.6), (30, cy + sg * 6.6), (30.4, cy + sg * 4.4)):
                put(g, x, y, 'w')                                          # spines
    legs = [((20, cy - 4), (24, cy - 12), (30, cy - 19)), ((18, cy - 4.6), (16, cy - 13), (13, cy - 20)),
            ((16, cy - 4.2), (9.5, cy - 11), (4, cy - 15.5))]
    return critter(w, h, cy, [seg(9.5, 6.4, 5.4), seg(19.5, 5.4, 6.2, RAMP2)], legs, deco, hairs('l', 't', 5), part, stride=1.0)

def vinegaroon(part=None):
    """Vinegaroon (whip scorpion): heavy dark body, massive crushing palps up front, thin feeler
    legs and a long whip tail it sprays vinegar from."""
    w, h, cy = 46, 32, 16
    def deco(g):
        line(g, [(1, cy - 0.5), (3, cy - 0.2), (6, cy)], 'w')            # the whip (flagellum)
        put(g, 0, cy - 1, 'w')
        for x in (8, 10.5, 13, 15.5):
            line(g, [(x, cy - 3.6), (x + 0.5, cy), (x, cy + 3.6)], '1')
        for sg in (-1, 1):
            line(g, [(26, cy + sg * 2.4), (29, cy + sg * 4.4), (32, cy + sg * 4.6)], 'B')
            blob(g, 34.5, cy + sg * 4.2, 3.2, 2.2, RAMP2)                 # thick palps
            line(g, [(36.5, cy + sg * 3.2), (38.6, cy + sg * 1.6)], 'D')
            line(g, [(36, cy + sg * 2.8), (37.5, cy + sg * 1.2)], 'w')
            put(g, 27.2, cy + sg * 0.7, 'e')
    legs = [((24, cy - 2.5), (28, cy - 6.5), (34, cy - 11)),
            ((22, cy - 3.4), (22, cy - 8.5), (20.5, cy - 13)), ((20, cy - 3.4), (17, cy - 8.5), (14, cy - 12.5)),
            ((18, cy - 3), (13, cy - 7), (8, cy - 10))]
    def extra(g, f):
        # first legs are feelers: thin and pale at the tips
        for y in range(len(g)):
            for x in range(len(g[0])):
                if g[y][x] == 'l' and x > 30 and (x + y) % 2 == 0: g[y][x] = 'm'
    return critter(w, h, cy, [seg(11.5, 6.4, 4.2), seg(23, 4.4, 3.6, RAMP2)], legs, deco, extra, part)

def mantis_shrimp(part=None):
    """Peacock mantis shrimp: emerald carapace, banded segmented tail with a blue and orange fan,
    stalked eyes, and the folded red smashing clubs under the head."""
    w, h, cy = 44, 26, 13
    def deco(g):
        for x in (16, 13, 10, 7):                                          # tail segment edges
            line(g, [(x - 1.6, cy - 3.2), (x - 1.6, cy + 3.2)], 'A')
            put(g, x - 0.4, cy - 2.6, 'S'); put(g, x - 0.4, cy + 2.6, 'S')
        blob(g, 3, cy, 2.2, 4.4, RAMP2, spec=False)                       # tail fan
        for sg in (-1, 1):
            line(g, [(1.2, cy + sg * 3), (4, cy + sg * 1)], 'b')
            line(g, [(28, cy + sg * 2.2), (31.5, cy + sg * 3.2), (34, cy + sg * 2.4)], 'C')   # folded clubs
            blob(g, 34.4, cy + sg * 2.4, 1.6, 1.2, RAMP2)
            line(g, [(35.5, cy + sg * 0.8), (37.8, cy + sg * 1.4)], 'b')   # eye stalks
            put(g, 38.4, cy + sg * 1.6, 'e'); put(g, 38.8, cy + sg * 2, 'e')
        line(g, [(31, cy), (36, cy)], 'C')                                 # rostrum
    legs = [((26, cy - 2.5), (27, cy - 5.5), (28.5, cy - 8)), ((23.5, cy - 3), (23.5, cy - 6), (22.5, cy - 9)),
            ((21, cy - 3), (19.5, cy - 6), (17.5, cy - 8.5))]
    return critter(w, h, cy, [seg(15.5, 2.8, 3.6), seg(12.4, 2.7, 3.5), seg(9.4, 2.6, 3.3), seg(6.6, 2.3, 3.0),
                              seg(23.6, 5.8, 4.0), seg(30, 2.4, 2.6, RAMP2)], legs, deco,
                   antennae([(37, cy - 0.6), (40, cy - 3), (43, cy - 6)], cy), part)

def pistol_shrimp(part=None):
    """Pistol shrimp: small banded red-and-cream shrimp with one enormous snapping claw (right
    side) and a tiny one on the other."""
    w, h, cy = 42, 30, 15
    def deco(g):
        for x in (15, 12.2, 9.4, 6.8):
            line(g, [(x - 1.4, cy - 2.8), (x - 1.4, cy + 2.8)], 'b')       # cream bands
        blob(g, 3, cy, 1.8, 3.6, RAMP1, spec=False)
        # the big snapping claw (plus side) and the small one
        line(g, [(25, cy + 2.6), (28, cy + 5), (30, cy + 6)], 'B')
        blob(g, 34, cy + 6.4, 4.4, 3.0, RAMP2)
        line(g, [(37, cy + 4.6), (40, cy + 5.4)], 'D')                     # the hinged dactyl (hammer)
        line(g, [(37.4, cy + 7.6), (40.4, cy + 6.6)], 'w')
        put(g, 35, cy + 6.6, 'H')
        line(g, [(25, cy - 2.2), (27.5, cy - 4), (30, cy - 4.4), (31.5, cy - 3.8)], 'B')
        put(g, 32, cy - 3.6, 'D')
        for sg in (-1, 1): put(g, 29, cy + sg * 1.0, 'e')                  # eyes under the hood
        line(g, [(28, cy), (31, cy)], 'C')
    legs = [((24, cy - 2.6), (25, cy - 5.5), (26.5, cy - 8)), ((22, cy - 2.8), (21.5, cy - 6), (20, cy - 8.5)),
            ((20, cy - 2.6), (18, cy - 5.4), (15.5, cy - 7.5))]
    return critter(w, h, cy, [seg(14.8, 2.6, 3.2), seg(12, 2.5, 3.0), seg(9.2, 2.3, 2.8), seg(6.6, 2.1, 2.5),
                              seg(23, 5.6, 3.6, RAMP2)], legs, deco,
                   antennae([(30.5, cy - 0.6), (35, cy - 3.5), (40, cy - 7)], cy), part)

def millipede(part=None):
    """Giant African millipede: glossy black rings edged with red, a rounded head with short
    antennae, and a fringe of many short red legs (two pairs per ring)."""
    n = 12
    w, h, cy = 48, 20, 10
    xs = [5 + i * 3.2 for i in range(n)]
    def deco(g):
        for i, x in enumerate(xs):
            line(g, [(x - 1.6, cy - 2.8), (x - 1.6, cy + 2.8)], 'S')
        for sg in (-1, 1): put(g, 44.5, cy + sg * 1.4, 'e')
    legs = [((x + dx, cy - 2.5), (x + dx - 0.2, cy - 4), (x + dx - 0.8, cy - 5.5)) for x in xs for dx in (-0.8, 0.8)]
    segs = [seg(x, 2.0, 3.2, RAMP1 if i % 2 else RAMP2) for i, x in enumerate(xs)] + [seg(43.6, 2.4, 2.9, RAMP2)]
    return critter(w, h, cy, segs, legs, deco, antennae([(45.5, cy - 1.4), (47, cy - 3)], cy), part, stride=0.35)

def millipede_part(kind):
    """Pieces of the chain-drawn millipede: a ring (two tones) or the head."""
    if kind in ("seg", "seg2"):
        w, h, cy = 7, 10, 4.5
        def body(g):
            blob(g, 3, cy, 2.1, 3.3, RAMP1 if kind == "seg" else RAMP2)
            line(g, [(1.2, cy - 2.8), (1.2, cy + 2.8)], 'S')
    else:
        w, h, cy = 9, 10, 4.5
        def body(g):
            blob(g, 4, cy, 2.6, 3.0, RAMP2)
            for sg in (-1, 1): put(g, 5.4, cy + sg * 1.4, 'e')
            line(g, [(6.2, cy - 0.5), (7.4, cy - 0.8)], 'w'); line(g, [(6.2, cy + 0.5), (7.4, cy + 0.8)], 'w')
    g = blank(w, h); body(g); outline(g)
    return [[''.join(r) for r in g]]

CHARS = [
    ("camel_spider", camel_spider, 14, 26, dict(o="#0a0703" + SOFT, l="#a07a48", m="#c4a070", b="#f4ecd8", t="#5a4020", T="#f0d8a8", e="#0a0806", w="#2a1a0c",
        **ramp("#6a4a24", "#8e6a38", "#b28c50", "#d0ac6c", "#fff0c8"), **ramp2("#5a3a1c", "#7e5428", "#a6743a", "#c8964e", "#ffe0b0"))),
    ("hissing_roach", hissing_roach, 12, 22, dict(o="#050302" + SOFT, l="#3a1e10", m="#6a3a1e", t="#1e0e06", T="#a0643a", e="#060404", s="#0c0604", S="#c07a32",
        **ramp("#140a06", "#26140a", "#3e2212", "#5a321a", "#d09a70"), **ramp2("#0e0806", "#1e120c", "#342014", "#4c2e1c", "#c8a080"))),
    ("whip_scorpion", whip_scorpion, 10, 18, dict(o="#060404" + SOFT, l="#5a3e2a", t="#2a1a10", T="#c8a080", e="#0a0606", w="#f0d8b0",
        **ramp("#2e2018", "#463024", "#604434", "#7c5a46", "#d8bca0"), **ramp2("#3a2618", "#563822", "#744e30", "#946640", "#f0c8a0"))),
    ("vinegaroon", vinegaroon, 10, 18, dict(o="#030202" + SOFT, l="#3a2420", m="#8a6a60", t="#1a0e0c", T="#a07870", e="#0a0606", w="#c0a090",
        **ramp("#0e0808", "#1c1010", "#2e1a18", "#442622", "#b08880"), **ramp2("#1e0a08", "#36140e", "#521e16", "#70301e", "#e0a088"))),
    ("mantis_shrimp", mantis_shrimp, 12, 20, dict(o="#020604" + SOFT, l="#e04a2a", t="#8a2010", T="#ffb090", e="#20e0f0", b="#f0e060", S="#3a80ff",
        **ramp("#0e4a24", "#16703a", "#20984e", "#34c068", "#d0ffd8"), **ramp2("#8a1a20", "#b82a2a", "#e04a36", "#ff7448", "#ffd0b0"))),
    ("pistol_shrimp", pistol_shrimp, 14, 24, dict(o="#0a0302" + SOFT, l="#d06a4a", t="#7a2a1a", T="#ffc0a0", e="#0a0404", b="#f8ead8", w="#fff4e0",
        **ramp("#8a2a1a", "#b03e24", "#d05a34", "#ec7a4c", "#ffd8c0"), **ramp2("#902818", "#b83c22", "#dc5a32", "#f88048", "#ffe0c8"))),
    ("millipede", millipede, 12, 30, dict(o="#030202" + SOFT, l="#c0402a", t="#601a10", T="#ff9a7a", e="#0a0606", w="#2a1a14", S="#a0301e",
        **ramp("#0e0a0a", "#1c1414", "#2e2222", "#463434", "#c0aaa8"), **ramp2("#140c0c", "#261818", "#3a2828", "#544040", "#d0b8b8"))),
]

SPRITES = []
for cid, fn, fps, lfps, pal in CHARS:
    SPRITES.append((cid, fps, pal, fn()))
    # in game the legs are drawn from the rig, so one unrotated frame is enough (saves atlas space)
    SPRITES.append((cid + "_legs", lfps, cid, fn("legs")[:1], {"rotate": False}))
    SPRITES.append((cid + "_body", fps, cid, fn("body")))
for part in ("seg", "seg2", "head"):
    SPRITES.append(("millipede_" + part, 1, "millipede", millipede_part(part)))

RIGS = {}
for cid, fn in [(c[0], c[1]) for c in CHARS]:
    fn("legs")
    r = RIG["last"]
    cx, cyy = (r["w"] - 1) / 2, (r["h"] - 1) / 2
    RIGS[cid + "_legs"] = [[(round(x - cx, 2), round(y - cyy, 2)) for (x, y) in leg] for leg in r["legs"]]

PAL = {e[0]: e[2] for e in SPRITES if isinstance(e[2], dict)}

out = ["-- Batch 2 playable bugs (generated by tools/make_batch2_sprites.py, safe to hand-edit).",
       "-- Same conventions as content/sprites/bugs.lua: face right, rotations baked in game.",
       "return {"]
for entry in SPRITES:
    sid, fps, pal, frames = entry[:4]
    opts = entry[4] if len(entry) > 4 else {}
    out.append("    {")
    out.append(f'        id = "{sid}",')
    out.append(f"        fps = {fps},")
    if opts.get("rotate") is False: out.append("        rotate = false,")
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
open("content/sprites/batch2.lua", "w").write("\n".join(out) + "\n")
print("wrote", len(SPRITES))
