# Generates top-down bug sprites from shape recipes and writes them as text-grid Lua.
#   python3 tools/make_bug_sprites.py   ->  content/sprites/bugs.lua
# Sprites face right (+x); the game bakes rotations at load.
#
# Body parts are lit ellipsoids (light from the top-left) quantised to 4-step colour ramps.
# Two ramps are available so parts can differ in colour (e.g. red thorax, black gaster):
#   ramp 1: "1".."4" + "h" (gloss)      ramp 2: "A".."D" + "H" (gloss)
# Legs walk with an alternating tripod gait over 4 frames.
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

def ant(s, w, h, cy, head=1.0, mandible=1.0, gaster=1.0, two_tone=True):
    """Real ant proportions: big gaster, petiole node, long mesosoma, rounded head."""
    gx = 3.3 * s
    grx, gry = 3.2 * s * gaster, 2.1 * s * gaster
    px = gx + grx + 0.7 * s               # petiole node
    mx = px + 0.8 * s + 1.7 * s           # mesosoma centre
    hx = mx + 1.7 * s + 1.5 * s * head    # head centre
    hr = 1.5 * s * head
    r2 = RAMP2 if two_tone else RAMP1
    def body(g):
        blob(g, gx, cy, grx, gry)
        for bx in (gx - 0.8 * s, gx + 0.6 * s):       # gaster bands
            line(g, [(bx, cy - gry * 0.8), (bx + 0.4, cy), (bx, cy + gry * 0.8)], '1')
        blob(g, px, cy, 0.6 * s, 0.6 * s, r2, spec=False)
        blob(g, mx, cy, 1.9 * s, 0.85 * s, r2)
        blob(g, hx, cy, hr * 1.05, hr, r2)
        # mandibles
        mlen = 1.5 * s * mandible
        line(g, [(hx + hr * 0.7, cy - hr * 0.55), (hx + hr + mlen, cy - 0.3 * s)], 'w')
        line(g, [(hx + hr * 0.7, cy + hr * 0.55), (hx + hr + mlen, cy + 0.3 * s)], 'w')
        put(g, hx + 0.2 * s, cy - hr * 0.75, 'e'); put(g, hx + 0.2 * s, cy + hr * 0.75, 'e')
    def legs():
        st = 0.9 * s
        return [
            lambda p: [(mx + 0.9 * s, cy - 0.5 * s), (mx + 2.4 * s, cy - 3.0 * s), (mx + 4.2 * s + p * st, cy - 4.2 * s)],
            lambda p: [(mx, cy - 0.6 * s), (mx + 0.3 * s, cy - 3.4 * s), (mx - 0.7 * s + p * st, cy - 5.0 * s)],
            lambda p: [(mx - 0.9 * s, cy - 0.5 * s), (mx - 2.9 * s, cy - 3.1 * s), (mx - 5.4 * s + p * st, cy - 4.5 * s)],
        ]
    # elbowed antennae: scape out, funiculus forward
    ant_pts = [(hx + 0.5 * s, cy - hr * 0.6), (hx + 0.6 * s, cy - hr - 1.3 * s), (hx + 2.8 * s, cy - hr - 1.0 * s)]
    def extra(g, f):
        twitch = 0.4 * s if f in (1, 2) else 0
        a = ant_pts[:2] + [(ant_pts[2][0], ant_pts[2][1] - twitch)]
        line(g, a, 'l', True); line(g, mirror(a, cy), 'l', True)
    return walk_frames(w, h, cy, legs, body, extra)

def ant_x(s, head=1.0, mandible=1.0, gaster=1.0, meso=1.0, leg=1.0, antenna=1.0, mstyle="normal",
          head_shape="round", leaf=False, wings=False, eye=1.0, frames=4):
    """Configurable ant that sizes its own canvas. Used for the species roster and queens.
    mstyle: normal | trap (long straight jaws) | sickle (curved army-ant jaws)
    head_shape: round | disc (turtle ant's flat shield head) | long | square (Pheidole major)
    wings: False | True (folded over the back, queens) | "spread" (flapping, flying alates)"""
    grx, gry = 3.2 * s * gaster, 2.1 * s * gaster
    gx = grx + 1.2
    px = gx + grx + 0.7 * s
    mrx = 1.9 * s * meso
    mx = px + 0.8 * s + mrx * 0.9
    hr = 1.5 * s * head
    hrx, hry = hr * 1.05, hr
    if head_shape == "disc": hrx, hry = hr * 0.8, hr * 1.3
    if head_shape == "long": hrx, hry = hr * 1.35, hr * 0.85
    if head_shape == "square": hrx, hry = hr * 1.1, hr * 1.2
    hx = mx + mrx * 0.9 + hrx
    mlen = 1.5 * s * mandible * (2.2 if mstyle == "trap" else 1.0)
    reach_x = max(hx + hrx + mlen, hx + (0.6 + 2.2 * antenna) * s, mx + (4.2 * leg + 1) * s)
    w = int(math.ceil(reach_x)) + 3
    half = int(math.ceil(max(5.2 * s * leg, gry + 1, hry + 1, (hr + 1.3 * s * antenna) if antenna else 0,
                             (8.8 * s if wings == "spread" else 3.6 * s) if wings else 0))) + 2
    h = half * 2 + 1
    cy = half
    def body(g):
        blob(g, gx, cy, grx, gry)
        for bx in (gx - grx * 0.25, gx + grx * 0.19):
            line(g, [(bx, cy - gry * 0.8), (bx + 0.4, cy), (bx, cy + gry * 0.8)], '1')
        blob(g, px, cy, 0.6 * s, 0.6 * s, RAMP2, spec=False)
        blob(g, mx, cy, mrx, 0.85 * s * (1.15 if meso > 1.1 else 1), RAMP2)
        blob(g, hx, cy, hrx, hry, RAMP2)
        if head_shape == "disc":
            line(g, [(hx - hrx * 0.2, cy - hry * 0.8), (hx + hrx * 0.5, cy), (hx - hrx * 0.2, cy + hry * 0.8)], 'B')
        if head_shape == "square":   # heart-shaped: a deep notch at the back, flat front
            line(g, [(hx - hrx * 0.95, cy), (hx - hrx * 0.35, cy)], '.')
            line(g, [(hx - hrx * 0.3, cy - 0.5), (hx - hrx * 0.3, cy + 0.5)], 'A')
        if mstyle == "trap":
            for sgn in (-1, 1):
                line(g, [(hx + hrx * 0.8, cy + sgn * 0.6 * s), (hx + hrx + mlen, cy + sgn * 0.7 * s), (hx + hrx + mlen + 0.4, cy + sgn * 0.2 * s)], 'w')
        elif mstyle == "sickle":
            for sgn in (-1, 1):
                line(g, [(hx + hrx * 0.7, cy + sgn * hry * 0.6), (hx + hrx + mlen * 0.7, cy + sgn * hry * 0.75), (hx + hrx + mlen * 1.1, cy + sgn * 0.15 * s)], 'w')
        else:
            for sgn in (-1, 1):
                line(g, [(hx + hrx * 0.7, cy + sgn * hry * 0.55), (hx + hrx + mlen, cy + sgn * 0.3 * s)], 'w')
        for sgn in (-1, 1):
            put(g, hx + 0.2 * s, cy + sgn * hry * 0.75, 'e')
            if eye > 1.2:
                put(g, hx + 0.2 * s + 1, cy + sgn * hry * 0.75, 'e'); put(g, hx + 0.2 * s, cy + sgn * (hry * 0.75 - 1), 'e')
        if leaf:     # a cut leaf fragment held up over the back
            lx, ly = mx + mrx * 0.3, cy - 0.6 * s
            blob(g, lx, ly, 2.8 * s, 2.3 * s, ('g', 'g', 'f', 'f', 'F'), spec=False)
            line(g, [(lx - 2.2 * s, ly + 1.2 * s), (lx + 2.0 * s, ly - 1.0 * s)], 'g')
            for t in (-1.0, 0.0, 1.0):
                line(g, [(lx + t * s, ly + t * -0.5 * s), (lx + t * s - 0.6 * s, ly + t * -0.5 * s - 1.2 * s)], 'g')
        if wings is True:    # translucent wings lying back over the gaster
            for sgn in (-1, 1):
                for yy in range(len(g)):
                    for xx in range(len(g[0])):
                        dx = (xx - (gx + grx * 0.15)) / (grx * 1.1)
                        dy = (yy - (cy + sgn * gry * 0.85)) / (1.05 * s)
                        if dx * dx + dy * dy <= 1 and g[yy][xx] in '1234h.':
                            g[yy][xx] = 'W' if dx * dx + dy * dy > 0.7 else 'v'
    def legs():
        st = 0.9 * s
        L = leg
        return [
            lambda p: [(mx + 0.9 * s, cy - 0.5 * s), (mx + 2.4 * s * L, cy - 3.0 * s * L), (mx + 4.2 * s * L + p * st, cy - 4.2 * s * L)],
            lambda p: [(mx, cy - 0.6 * s), (mx + 0.3 * s * L, cy - 3.4 * s * L), (mx - 0.7 * s * L + p * st, cy - 5.0 * s * L)],
            lambda p: [(mx - 0.9 * s, cy - 0.5 * s), (mx - 2.9 * s * L, cy - 3.1 * s * L), (mx - 5.4 * s * L + p * st, cy - 4.5 * s * L)],
        ]
    A = antenna
    ant_pts = [(hx + 0.5 * s, cy - hry * 0.6), (hx + 0.6 * s, cy - hry - 1.3 * s * A), (hx + (0.6 + 2.2 * A) * s, cy - hry - 1.0 * s * A)]
    def extra(g, f):
        twitch = 0.4 * s if f in (1, 2) else 0
        a = ant_pts[:2] + [(ant_pts[2][0], ant_pts[2][1] - twitch)]
        line(g, a, 'l', True); line(g, mirror(a, cy), 'l', True)
        if wings == "spread":   # two pairs of wings beating: out wide on even frames, swept back on odd
            sweep = 0.25 if f % 2 == 0 else 0.95        # radians back from straight out sideways
            for sgn in (-1, 1):
                for (rx0, L, W) in ((mx + 0.4 * s, 8.5 * s, 4.0 * s), (mx - 1.2 * s, 6.5 * s, 3.0 * s)):
                    dx, dy = -math.sin(sweep), sgn * math.cos(sweep)
                    ccx, ccy = rx0 + dx * L / 2, cy + sgn * 0.6 * s + dy * L / 2
                    for yy in range(len(g)):
                        for xx in range(len(g[0])):
                            px_, py_ = xx - ccx, yy - ccy
                            u = (px_ * dx + py_ * dy) / (L / 2)
                            v = (-px_ * dy + py_ * dx) / (W / 2)
                            d2 = u * u + v * v
                            if d2 <= 1 and g[yy][xx] in '.lW':
                                g[yy][xx] = 'W' if d2 > 0.55 else 'v'
    return walk_frames(w, h, cy, legs, body, extra, frames=frames)

def beetle(part=None):
    """Hercules-style rhinoceros beetle: olive elytra with dark spots, black glossy pronotum and horns."""
    w, h, cy = 33, 25, 12
    def body(g):
        blob(g, 11, cy, 8.6, 7.4)                                   # elytra (ramp 1, olive)
        for (x, y) in ((7, cy - 4), (10, cy - 5.2), (13, cy - 3.6), (6.5, cy + 3.5), (10, cy + 5), (13.5, cy + 3.8), (4.5, cy - 1.5), (4.5, cy + 1.8)):
            put(g, x, y, 'S'); put(g, x + 1, y, 'S')
        line(g, [(2.8, cy), (18.5, cy)], 's')                        # elytral seam
        blob(g, 20.8, cy, 3.4, 4.8, RAMP2, bias=0.05)              # pronotum (black gloss)
        blob(g, 24.3, cy, 1.8, 2.2, RAMP2, spec=False)              # head
        line(g, [(21, cy - 0.5), (25, cy - 0.8), (29, cy - 1.4), (31.5, cy - 3.2)], 'D')   # thoracic horn
        line(g, [(21, cy + 0.4), (25, cy + 0.2), (29, cy - 0.4), (31, cy - 2.4)], 'B')
        line(g, [(25.5, cy + 1.2), (28, cy + 2), (29.8, cy + 1.2)], 'C')          # head horn
        put(g, 25.2, cy - 2.0, 'e'); put(g, 25.2, cy + 2.0, 'e')
    def legs():
        return [
            lambda p: [(21, cy - 3.5), (23.5, cy - 7), (26 + p, cy - 9.2), (27.5 + p, cy - 9.6)],
            lambda p: [(15, cy - 6.5), (15.5, cy - 9.5), (14 + p, cy - 11.5), (13 + p, cy - 12)],
            lambda p: [(9, cy - 6.8), (6, cy - 9.3), (3.5 + p, cy - 11), (2 + p, cy - 11.3)],
        ]
    def extra(g, f):
        line(g, [(25.5, cy - 1.6), (27.5, cy - 3.6), (28.5, cy - 3.4)], 'l', True)
        line(g, mirror([(25.5, cy - 1.6), (27.5, cy - 3.6), (28.5, cy - 3.4)], cy), 'l', True)
    return walk_frames(w, h, cy, legs, body, extra, part=part)

def spider(part=None):
    """Wolf spider: banded legs, striped carapace, mottled abdomen with a cardiac mark."""
    w, h, cy = 33, 31, 15
    def body(g):
        blob(g, 9.5, cy, 6.2, 5.4)
        line(g, [(5, cy), (12.5, cy)], 'b')                          # cardiac mark
        for i, x in enumerate((6, 8.5, 11)):
            put(g, x, cy - 2.4, 'b'); put(g, x, cy + 2.4, 'b')
        for (x, y) in ((5, cy - 3), (7.5, cy + 3.6), (11, cy - 3.8), (12.5, cy + 2.5), (4, cy + 1.5)):
            put(g, x, y, '1')
        blob(g, 18.6, cy, 3.8, 3.3, RAMP2)
        line(g, [(15.5, cy), (21.5, cy)], 'b')
        line(g, [(16, cy - 1.7), (20.5, cy - 1.5)], 'A'); line(g, [(16, cy + 1.7), (20.5, cy + 1.5)], 'A')
        for (x, y) in ((22, cy - 1.0), (22, cy + 1.0), (21.3, cy - 2.0), (21.3, cy + 2.0)):
            put(g, x, y, 'e')
        put(g, 23, cy - 0.7, 'w'); put(g, 23, cy + 0.7, 'w')        # chelicerae
    def legs():
        return [
            lambda p: [(20.5, cy - 2), (25, cy - 5.5), (30.5 + p, cy - 5)],
            lambda p: [(19.5, cy - 2.6), (22.5, cy - 9.5), (24 - p, cy - 14)],
            lambda p: [(18, cy - 2.8), (16.5, cy - 10), (14 + p, cy - 14)],
            lambda p: [(16.8, cy - 2.2), (12.5, cy - 8.5), (7 - p, cy - 11)],
        ]
    def extra(g, f):
        for y in range(len(g)):
            for x in range(len(g[0])):
                if g[y][x] == 'l' and (x + y) % 3 == 0: g[y][x] = 'm'
    return walk_frames(w, h, cy, legs, body, extra, part=part)


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

def bombardier(part=None):
    """Bombardier beetle: blue-black elytra with yellow bands, orange head and pronotum."""
    w, h, cy = 28, 22, 11
    def deco(g):
        for x in (6, 11):
            line(g, [(x, cy - 5), (x + 0.6, cy), (x, cy + 5)], 'S')
        line(g, [(3.5, cy), (16, cy)], 's')
        put(g, 23.8, cy - 1.4, 'e'); put(g, 23.8, cy + 1.4, 'e')
        both(g, [(24, cy - 1), (25.8, cy - 0.4)], 'w', cy)
        put(g, 2, cy, 'w')                                       # the spray nozzle
    legs = [((18, cy - 2.5), (20, cy - 6), (22.5, cy - 8)), ((14, cy - 4.5), (14, cy - 8), (12.5, cy - 10)),
            ((9, cy - 4.8), (6.5, cy - 8), (4, cy - 9.5))]
    return critter(w, h, cy, [seg(10, 7.6, 6.0), seg(18.6, 2.8, 3.6, RAMP2), seg(22.3, 2.0, 2.2, RAMP2, False)], legs, deco,
                   antennae([(23.5, cy - 1.8), (25.5, cy - 4), (27, cy - 5)], cy), part)

def tiger_beetle(part=None):
    """Tiger beetle: metallic green with cream spots, long running legs, huge eyes and sickle jaws."""
    w, h, cy = 32, 28, 14
    def deco(g):
        for (x, y) in ((6, cy - 3.5), (9.5, cy - 4.5), (13, cy - 3), (6, cy + 3.5), (9.5, cy + 4.5), (13, cy + 3)):
            put(g, x, y, 'S'); put(g, x + 1, y, 'S')
        line(g, [(3, cy), (15.5, cy)], 's')
        for sg in (-1, 1):
            put(g, 22.6, cy + sg * 2.4, 'e'); put(g, 23.4, cy + sg * 2.4, 'e'); put(g, 23, cy + sg * 1.6, 'e')
            line(g, [(24.2, cy + sg * 1.2), (26.5, cy + sg * 2.4), (28.4, cy + sg * 1.4), (28.6, cy + sg * 0.4)], 'w')
    legs = [((19, cy - 1.8), (22.5, cy - 6.5), (27, cy - 10)), ((16.5, cy - 3), (16.5, cy - 8.5), (15, cy - 12.5)),
            ((13, cy - 3.6), (9, cy - 9), (4, cy - 12))]
    return critter(w, h, cy, [seg(9.5, 7.0, 4.8), seg(18.2, 2.2, 2.6, RAMP2), seg(22.8, 2.3, 3.0, RAMP2)], legs, deco,
                   antennae([(24, cy - 2.4), (26, cy - 6), (28.5, cy - 8)], cy), part)

def stag_beetle(part=None):
    """Stag beetle: dark chestnut elytra, broad head and enormous antler-like mandibles."""
    w, h, cy = 42, 28, 14
    def deco(g):
        line(g, [(3.2, cy), (18.5, cy)], 's')
        for sg in (-1, 1):
            put(g, 27.6, cy + sg * 3.2, 'e')
            pts = [(27.5, cy + sg * 2.2), (31, cy + sg * 4.2), (35, cy + sg * 4.6), (38.5, cy + sg * 3), (40, cy + sg * 0.8)]
            line(g, pts, 'D'); line(g, [(x, y - sg * 0.7) for x, y in pts[:4]], 'B')
            line(g, [(34, cy + sg * 4.4), (34.5, cy + sg * 2.4)], 'C')      # inner tooth
    legs = [((22, cy - 3.5), (25, cy - 7.5), (28, cy - 10.5)), ((16, cy - 6), (16, cy - 10), (14, cy - 12.8)),
            ((10, cy - 6), (7, cy - 9.5), (4, cy - 11.5))]
    return critter(w, h, cy, [seg(11, 8.2, 6.6), seg(21.4, 3.2, 5.0, RAMP2), seg(25.6, 2.6, 4.0, RAMP2, False)], legs, deco,
                   antennae([(27, cy - 3.4), (29, cy - 6.4), (31, cy - 6.2)], cy), part)

def scorpion(part=None):
    """Scorpion: segmented body, big pincers in front, tail curled up over to one side."""
    w, h, cy = 38, 32, 16
    def deco(g):
        tail = [(5.5, cy, 1.9), (3, cy - 1.5, 1.7), (2, cy - 4.5, 1.6), (3, cy - 7.5, 1.5), (5.5, cy - 9.5, 1.5)]
        for (x, y, r) in tail: blob(g, x, y, r, r)
        blob(g, 8.4, cy - 10.5, 1.4, 1.2, RAMP2)
        line(g, [(9.5, cy - 10.5), (11, cy - 9.6)], 'w')                    # stinger
        for x in (9.5, 13.5, 17.5):
            line(g, [(x, cy - 3.4), (x + 0.4, cy), (x, cy + 3.4)], '1')
        for sg in (-1, 1):
            line(g, [(24.5, cy + sg * 2), (27.5, cy + sg * 4.5), (30, cy + sg * 6)], 'B')
            blob(g, 32.5, cy + sg * 6.4, 2.8, 1.9, RAMP2)
            line(g, [(34.5, cy + sg * 7), (36.8, cy + sg * 6.4)], 'D')
            line(g, [(34.5, cy + sg * 5.6), (36.6, cy + sg * 5.4)], 'w')
        put(g, 25, cy - 0.8, 'e'); put(g, 25, cy + 0.8, 'e')
    legs = [((22, cy - 3), (22, cy - 7.5), (24.5, cy - 11)), ((20, cy - 3.5), (19, cy - 8.5), (19.5, cy - 13)),
            ((17.5, cy - 3.6), (15, cy - 8.5), (13.5, cy - 13)), ((15, cy - 3.5), (11, cy - 7.5), (8, cy - 11.5))]
    return critter(w, h, cy, [seg(9.5, 3.4, 3.5), seg(14, 3.8, 4.0), seg(18.5, 3.6, 4.2), seg(22.5, 3.4, 3.6, RAMP2)],
                   legs, deco, None, part)

def lobster(part=None):
    """Lobster: armoured carapace, segmented tail fan, long whip antennae (claws are drawn as limbs)."""
    w, h, cy = 46, 32, 16
    def deco(g):
        for sg in (-1, 1):
            # the claws themselves are animated limbs (content/characters/lobster.lua)
            line(g, [(28, cy + sg * 2.5), (29.5, cy + sg * 3.5)], 'B')
            put(g, 31.5, cy + sg * 1.6, 'e')
        line(g, [(29.5, cy), (33, cy)], 'C')                                 # rostrum
        blob(g, 2.8, cy, 2.0, 4.2, RAMP2, spec=False)                        # tail fan
        for x in (15, 11.8, 8.8, 6):
            line(g, [(x - 1.5, cy - 3), (x - 1.5, cy + 3)], 'A')
    legs = [((26, cy - 3.5), (27, cy - 7), (29, cy - 10)), ((24, cy - 4), (24, cy - 8), (24, cy - 11)),
            ((22, cy - 4.2), (21, cy - 8), (19.5, cy - 10.8)), ((20, cy - 4), (18, cy - 7.5), (15.5, cy - 10))]
    return critter(w, h, cy, [seg(16.2, 3.0, 3.6), seg(12.8, 2.7, 3.3), seg(9.6, 2.5, 3.0), seg(6.6, 2.2, 2.6),
                              seg(23.5, 6.2, 4.6, RAMP2)], legs, deco,
                   antennae([(31, cy - 1), (36, cy - 3), (41, cy - 10), (44, cy - 15)], cy), part)

def centipede(part=None):
    """Giant centipede: a long chain of plated segments, one pair of legs each, venom claws."""
    n = 12
    w, h, cy = 48, 24, 12
    xs = [6 + i * 3.1 for i in range(n)]
    def deco(g):
        for i, x in enumerate(xs):
            line(g, [(x - 1.5, cy - 2.2), (x - 1.5, cy + 2.2)], 'A' if i % 2 else '1')
        for sg in (-1, 1):
            line(g, [(43.2, cy + sg * 1.4), (45, cy + sg * 1.6), (45.8, cy + sg * 0.6)], 'w')
            put(g, 42.6, cy + sg * 1.2, 'e')
        line(g, [(2, cy - 1.5), (6, cy - 1)], 'l'); line(g, [(2, cy + 1.5), (6, cy + 1)], 'l')   # trailing legs
    legs = [((x, cy - 2), (x - 0.3, cy - 4.5), (x - 1.2, cy - 7)) for x in xs]
    segs = [seg(x, 1.9, 2.7, RAMP1 if i % 2 else RAMP2) for i, x in enumerate(xs)] + [seg(42.6, 2.3, 2.6, RAMP2)]
    return critter(w, h, cy, segs, legs, deco, antennae([(43.5, cy - 1.8), (45.5, cy - 4.5), (47, cy - 7)], cy), part, stride=0.5)

def jumping_spider(part=None):
    """Jumping spider: compact and fuzzy, white-banded, with two huge forward-facing eyes."""
    w, h, cy = 28, 28, 14
    def deco(g):
        line(g, [(5, cy - 2.5), (11, cy - 2.5)], 'b'); line(g, [(5, cy + 2.5), (11, cy + 2.5)], 'b')
        put(g, 8, cy, 'b'); put(g, 10, cy, 'b')
        for sg in (-1, 1):
            put(g, 19, cy + sg * 1.2, 'e'); put(g, 19.8, cy + sg * 1.2, 'e'); put(g, 19, cy + sg * 2, 'e'); put(g, 19.8, cy + sg * 2, 'e')
            put(g, 19.4, cy + sg * 1.4, 'b')
            put(g, 20.8, cy + sg * 0.6, 'w')
    legs = [((17.5, cy - 2.5), (21, cy - 6), (24, cy - 7.5)), ((16.5, cy - 3), (18, cy - 8), (18, cy - 11.5)),
            ((14.5, cy - 3), (13, cy - 8), (11, cy - 11)), ((13.5, cy - 2.5), (10, cy - 6.5), (6.5, cy - 9))]
    def extra(g, f):
        for y in range(len(g)):
            for x in range(len(g[0])):
                if g[y][x] == 'l' and (x * 2 + y) % 4 == 0: g[y][x] = 'm'
    return critter(w, h, cy, [seg(8.5, 4.6, 4.0), seg(16, 4.0, 3.8, RAMP2)], legs, deco, extra, part)

def tarantula(part=None):
    """Red-knee tarantula: big, hairy, black legs with orange knee bands."""
    w, h, cy = 36, 36, 18
    def deco(g):
        for (x, y) in ((6, cy - 2), (8, cy + 3), (10.5, cy - 3.5), (12, cy + 1.5), (5, cy + 1)):
            put(g, x, y, 'm')
        line(g, [(18.5, cy - 2), (20.5, cy)], 'b'); line(g, [(18.5, cy + 2), (20.5, cy)], 'b')
        put(g, 24.2, cy - 0.6, 'e'); put(g, 24.2, cy + 0.6, 'e')
        put(g, 25.5, cy - 1, 'w'); put(g, 25.5, cy + 1, 'w')
    legs = [((22.5, cy - 2.5), (27.5, cy - 7), (33, cy - 8)), ((21, cy - 3.2), (24, cy - 11), (25, cy - 16.5)),
            ((18.5, cy - 3.4), (16.5, cy - 11.5), (14, cy - 16.5)), ((17, cy - 2.6), (11.5, cy - 9), (5, cy - 12.5))]
    knees = [(27.5, cy - 7), (24, cy - 11), (16.5, cy - 11.5), (11.5, cy - 9)]
    def extra(g, f):
        for y in range(len(g)):
            for x in range(len(g[0])):
                if g[y][x] == 'l' and any(abs(x - kx) + abs(min(abs(y - ky), abs(y - (2 * cy - ky)))) < 2.2 for kx, ky in knees):
                    g[y][x] = 'b'
                elif g[y][x] == 'l' and (x + y) % 3 == 0: g[y][x] = 'm'
    return critter(w, h, cy, [seg(10, 6.6, 6.0), seg(21, 4.6, 4.2, RAMP2)], legs, deco, extra, part)

def orb_weaver(part=None):
    """Garden orb weaver (Argiope): wasp-striped yellow and black abdomen, silver head, long banded legs."""
    w, h, cy = 36, 36, 18
    def deco(g):
        for x in (5.5, 8, 10.5, 13):
            line(g, [(x, cy - 4.5), (x + 0.6, cy), (x, cy + 4.5)], 'b')
        put(g, 21, cy - 0.6, 'e'); put(g, 21, cy + 0.6, 'e')
    legs = [((19.5, cy - 2), (25, cy - 8), (33, cy - 10)), ((18.5, cy - 2.4), (21, cy - 10), (22, cy - 17)),
            ((17, cy - 2.4), (15, cy - 9), (12, cy - 13.5)), ((16, cy - 2), (10, cy - 7), (3, cy - 9))]
    def extra(g, f):
        for y in range(len(g)):
            for x in range(len(g[0])):
                if g[y][x] == 'l' and (x + 2 * y) % 5 < 2: g[y][x] = 'm'
    return critter(w, h, cy, [seg(9.5, 6.4, 5.2), seg(18.2, 2.8, 2.6, RAMP2)], legs, deco, extra, part)

def mantis(part=None):
    """Praying mantis: long green body under folded wings, slim neck, triangle head, raptorial arms."""
    w, h, cy = 46, 28, 14
    def deco(g):
        for yy in range(len(g)):                                          # folded wings over the abdomen
            for xx in range(len(g[0])):
                dx, dy = (xx - 13) / 8.6, (yy - cy) / 2.6
                if dx * dx + dy * dy <= 1 and g[yy][xx] in '1234h':
                    g[yy][xx] = 'W' if dx * dx + dy * dy > 0.6 or yy == cy else 'v'
        for sg in (-1, 1):
            put(g, 35.6, cy + sg * 2.6, 'e'); put(g, 35, cy + sg * 2.2, 'e')
            line(g, [(29.5, cy + sg * 1), (33.5, cy + sg * 3.5), (37.5, cy + sg * 4.2)], 'D')      # raptorial arms
            line(g, [(37.5, cy + sg * 4.2), (35, cy + sg * 2.4), (33, cy + sg * 2)], 'C')
            put(g, 36, cy + sg * 3.3, 'w'); put(g, 34, cy + sg * 3.2, 'w')
    legs = [((26, cy - 1), (25, cy - 6), (27, cy - 11)), ((21, cy - 1.2), (17, cy - 6), (14, cy - 11))]
    return critter(w, h, cy, [seg(12.5, 9.5, 3.2), seg(26, 6.0, 1.5, RAMP2), seg(35, 1.8, 2.8, RAMP2)], legs, deco,
                   antennae([(36, cy - 1), (39, cy - 4), (43, cy - 6)], cy), part)

def ramp(c1, c2, c3, c4, hi): return {"1": c1, "2": c2, "3": c3, "4": c4, "h": hi}
def ramp2(c1, c2, c3, c4, hi): return {"A": c1, "B": c2, "C": c3, "D": c4, "H": hi}

SOFT = "b0"   # outline alpha (hex) for a softer, less cartoony edge

SPRITES = [
    ("worker_ant", 14, dict(o="#0a0605" + SOFT, l="#2a1a12", e="#0a0606", w="#5a3a24",
        **ramp("#120a08", "#24150f", "#3a2418", "#553624", "#b89a80"),
        **ramp2("#2a120c", "#4a2216", "#6e3420", "#8e4a2c", "#d8a080")),
        ant(0.72, 18, 15, 7)),
    ("fire_ant", 18, dict(o="#140605" + SOFT, l="#5a2414", e="#120604", w="#7a3a1a",
        **ramp("#1a0a08", "#2e130e", "#4a1e14", "#6a2c1a", "#d0907a"),
        **ramp2("#5a160c", "#8e2614", "#c03e1c", "#e05a28", "#ffc090")),
        ant(0.6, 16, 13, 6, gaster=0.9)),
    ("soldier_ant", 10, dict(o="#080404" + SOFT, l="#2a1610", e="#0a0505", w="#d8b880",
        **ramp("#100808", "#20120e", "#341c14", "#4c2a1c", "#b49680"),
        **ramp2("#2e140c", "#52241a", "#783822", "#9a5030", "#e6b08a")),
        ant(1.0, 26, 21, 10, head=1.55, mandible=1.6)),
    ("rhino_beetle", 10, dict(o="#060504" + SOFT, l="#141210", t="#4e4838", T="#9a947c", e="#1a1408", s="#2a2414", S="#1e1a10", w="#e8dcc0",
        **ramp("#3e3a1e", "#625a2c", "#867a3c", "#aa9c52", "#efe6c0"),
        **ramp2("#060606", "#121214", "#22232a", "#3a3c48", "#c8d0e8")),
        beetle()),
    ("rhino_beetle_legs", 18, "rhino_beetle", beetle("legs")),
    ("rhino_beetle_body", 10, "rhino_beetle", beetle("body")),
    ("wolf_spider", 12, dict(o="#070504" + SOFT, l="#2a1d14", t="#6a5238", T="#d0b898", m="#6e563c", b="#c4a070", e="#0a0a0a", w="#3a2a1c",
        **ramp("#2a1d14", "#43301f", "#5e452e", "#7c5f42", "#cdb898"),
        **ramp2("#33241a", "#4e3828", "#6c4f38", "#8c6c4e", "#dcc6a4")),
        spider()),
    ("wolf_spider_legs", 22, "wolf_spider", spider("legs")),
    ("wolf_spider_body", 12, "wolf_spider", spider("body")),
]
# ---- Ant species roster (enemies) and their queens -----------------------------------------
# Each species: palette (ramp 1 = gaster, ramp 2 = head + mesosoma, w = mandibles, l = legs,
# e = eyes, f/F/g = leaf, v/W = wings) and ant_x shape options. Queens reuse the palette.
def P(o, l, e, w, r1, r2, **more):
    d = dict(o=o + SOFT, l=l, e=e, w=w, **ramp(*r1), **ramp2(*r2))
    d.update(more); return d

WING = dict(v="#d8e4f0" + "48", W="#a8b8c8" + "88")
SPECIES = [
    # id, fps, palette, shape
    ("trapjaw_ant", 14, P("#0c0604", "#3a1c10", "#080404", "#e8c890",
        ("#2a1008", "#4a1c0e", "#6e2c16", "#8e3e20", "#e0a070"), ("#3a160a", "#5e2410", "#843818", "#a84c22", "#f0b080")),
        dict(s=0.8, head=1.15, mandible=1.3, mstyle="trap", leg=1.2, head_shape="long")),
    ("honeypot_ant", 10, P("#0e0804", "#3a2814", "#0a0604", "#6a4a24",
        ("#8a4e0c", "#c07818", "#e8a030", "#ffc860", "#fff2c0"), ("#2e1e10", "#4a3220", "#6a4a30", "#8a6442", "#d0b08a")),
        dict(s=0.62, gaster=2.0, leg=1.0)),
    ("leafcutter_ant", 14, P("#100604", "#4a2210", "#0a0404", "#5a2a14",
        ("#4a1e0a", "#6e2e10", "#94421a", "#b45a24", "#f0b080"), ("#5a2a0e", "#84401a", "#aa5a26", "#cc7434", "#f8c090"),
        f="#5aa83a", F="#a8e070", g="#2e6a22"),
        dict(s=0.75, leaf=True, head=1.15)),
    ("bullet_ant", 18, P("#080404", "#2a1410", "#060404", "#a06a40",
        ("#1a0806", "#2e100a", "#4a1a10", "#6a2818", "#d08060"), ("#200c08", "#3a160e", "#5a2216", "#7c321e", "#e09070")),
        dict(s=0.95, gaster=0.85, meso=1.25, leg=1.15, antenna=1.2)),
    ("army_ant", 12, P("#0a0404", "#3a1a10", "#3a1a10", "#e0c098",
        ("#24100a", "#3e1c12", "#5e2c1c", "#7e3c26", "#d89a7a"), ("#4a1c0e", "#702c16", "#963e20", "#b8522c", "#f4a880")),
        dict(s=1.15, head=1.25, mandible=1.5, mstyle="sickle", meso=1.1)),
    ("crazy_ant", 26, P("#0c0a08", "#3a342c", "#0a0808", "#5a5044",
        ("#1e1a16", "#302a24", "#463e34", "#5e5446", "#c8bca8"), ("#26201a", "#3a3228", "#524638", "#6c5e4a", "#d0c2a8")),
        dict(s=0.48, leg=1.7, antenna=1.8, gaster=0.9)),
    ("turtle_ant", 8, P("#060404", "#1e1814", "#2a2010", "#3a3028",
        ("#0e0a08", "#1a1410", "#2a221c", "#3e342a", "#a89880"), ("#120e0c", "#221c18", "#36302a", "#4e463c", "#c0b4a0")),
        dict(s=0.85, head=1.9, head_shape="disc", mandible=0.5, leg=0.9, meso=1.15)),
    ("green_ant", 14, P("#06100a", "#4a3010", "#0a0a04", "#8a5a20",
        ("#1e5a22", "#2e8030", "#48aa3e", "#72d052", "#e0ffb0"), ("#8a4a14", "#b0621c", "#d0802a", "#e8a040", "#fff0a8")),
        dict(s=0.72, gaster=1.05, leg=1.15, antenna=1.2)),
    ("exploding_ant", 14, P("#0e0806", "#3a2214", "#0a0606", "#6a3a1c",
        ("#8a6418", "#b48a24", "#d8ae3a", "#f0d060", "#fff8c0"), ("#3a1a0e", "#5a2a16", "#7c3a1e", "#9a4e2a", "#e0a080")),
        dict(s=0.7, gaster=1.4)),
    ("jumping_ant", 16, P("#0a0504", "#4a2414", "#0a0a0a", "#e0b070",
        ("#141010", "#221a18", "#342824", "#4a3a32", "#b8a090"), ("#7a2a0e", "#a43c14", "#c8541c", "#e4722a", "#ffc080")),
        dict(s=0.85, head=1.15, head_shape="long", mandible=1.2, mstyle="trap", eye=1.6, leg=1.25)),
    ("wood_ant", 16, P("#0a0504", "#3a1a10", "#0a0504", "#6a3a1c",
        ("#100c0c", "#1c1616", "#2c2424", "#40363a", "#a89a9a"), ("#6a2210", "#943418", "#b84a22", "#d4642e", "#ffb080")),
        dict(s=0.78, leg=1.15)),
]
# Round 7: ten more species from real ants.
SPECIES += [
    ("flying_ant", 26, P("#0a0606", "#3a2a20", "#1a1a1a", "#5a3a24",
        ("#160e0c", "#281a14", "#3c2a20", "#56402e", "#c8b098"), ("#1e1410", "#30221a", "#463424", "#604a34", "#d0b89a"),
        v="#e8f0fa" + "78", W="#a8b8cc" + "d0"),
        dict(s=0.72, wings="spread", gaster=1.15, eye=1.6, leg=0.9)),
    ("weaver_ant", 16, P("#140804", "#8a5020", "#1a0c04", "#6a3a14",
        ("#8a4a10", "#b8661a", "#d88a2a", "#f0aa48", "#fff0b0"), ("#9a5a18", "#c87a24", "#e49a36", "#f8bc58", "#fff4c0")),
        dict(s=0.8, gaster=0.85, leg=1.35, antenna=1.3, meso=1.15)),
    ("bulldog_ant", 16, P("#0a0404", "#5a2010", "#000000", "#f0d070",
        ("#0e0808", "#1a1010", "#2a1a18", "#3e2a26", "#b09088"), ("#6a1a0c", "#962812", "#c03a1a", "#e05428", "#ffb090")),
        dict(s=1.0, mstyle="trap", mandible=1.15, eye=1.7, leg=1.2, head=1.1, antenna=1.1)),
    ("driver_ant", 14, P("#0c0404", "#4a1a0c", "#2a0c06", "#e8b888",
        ("#3a120a", "#561c10", "#7a2a18", "#9c3c22", "#e09a78"), ("#5a1a0c", "#822812", "#a83a1c", "#c85028", "#f8a880")),
        dict(s=0.85, head=1.35, mandible=1.5, mstyle="sickle", gaster=0.75, meso=1.05)),
    ("dracula_ant", 18, P("#100804", "#8a5a24", "#0a0604", "#f0d8a0",
        ("#7a3e10", "#9e5418", "#c27024", "#dc8c36", "#ffd08a"), ("#8a4a14", "#b0621c", "#d07e2a", "#e89a40", "#ffe0a0")),
        dict(s=0.78, head=1.15, head_shape="long", mstyle="trap", mandible=1.45, leg=1.1)),
    ("matabele_ant", 12, P("#040404", "#1a1818", "#3a3a3a", "#2a2626",
        ("#060606", "#101010", "#1c1c1e", "#2c2c30", "#9a9aa8"), ("#080808", "#141414", "#222226", "#34343a", "#a8a8b8")),
        dict(s=1.05, mandible=1.1, leg=1.1, meso=1.1, gaster=1.05)),
    ("pharaoh_ant", 22, P("#1a0e04", "#a07030", "#2a1404", "#7a4a1a",
        ("#5a3410", "#8a5a1c", "#c08a30", "#dca848", "#fff0b0"), ("#b07a2a", "#d09a3a", "#e8b850", "#f8d070", "#fff8d0")),
        dict(s=0.42, gaster=1.0, leg=1.0)),
    ("bigheaded_ant", 10, P("#0c0604", "#5a2c14", "#0a0604", "#4a1e0e",
        ("#3a1a0e", "#5a2a16", "#7c3c20", "#9c502c", "#e0a080"), ("#6a2a10", "#8e3c18", "#b25222", "#cc6a30", "#f8b888")),
        dict(s=0.82, head=1.95, head_shape="square", mandible=0.75, leg=1.0, meso=1.05)),
    ("desert_ant", 26, P("#1a1a1e", "#8a8a92", "#0a0a0a", "#5a5a60",
        ("#4a4c54", "#70747e", "#9ca0aa", "#c8ccd4", "#ffffff"), ("#52545c", "#7a7e88", "#a8acb6", "#d4d8e0", "#ffffff")),
        dict(s=0.78, gaster=0.8, leg=1.65, antenna=1.4, meso=1.2)),
    ("pebble_ant", 16, P("#100604", "#6a3010", "#0a0404", "#5a2a10",
        ("#0e0a0a", "#1c1414", "#2c2220", "#40322e", "#b0a098"), ("#9a3a10", "#c04c18", "#e06424", "#f07e34", "#ffc090")),
        dict(s=0.62, leg=1.1, antenna=1.1)),
]
WORKER_PAL = dict(o="#0a0605" + SOFT, l="#2a1a12", e="#0a0606", w="#5a3a24",
        **ramp("#120a08", "#24150f", "#3a2418", "#553624", "#b89a80"), **ramp2("#2a120c", "#4a2216", "#6e3420", "#8e4a2c", "#d8a080"))
FIRE_PAL = dict(o="#140605" + SOFT, l="#5a2414", e="#120604", w="#7a3a1a",
        **ramp("#1a0a08", "#2e130e", "#4a1e14", "#6a2c1a", "#d0907a"), **ramp2("#5a160c", "#8e2614", "#c03e1c", "#e05a28", "#ffc090"))
for sid, fps, pal, shape in SPECIES:
    SPRITES.append((sid, fps, pal, ant_x(**shape)))
# Pheidole minors: the small caste of the big-headed ant (no queen of their own).
BIGHEAD_PAL = next(pal for sid, _, pal, _ in SPECIES if sid == "bigheaded_ant")
SPRITES.append(("bigheaded_minor", 20, BIGHEAD_PAL, ant_x(s=0.48, head=1.05, leg=1.1)))
QUEENS = [("worker_ant", WORKER_PAL, {}), ("fire_ant", FIRE_PAL, {})] + [(sid, pal, shape) for sid, _, pal, shape in SPECIES]
for sid, pal, shape in QUEENS:
    q = dict(s=1.9, gaster=1.45, meso=1.25, leg=1.0, frames=2, wings=True)
    for k in ("head_shape", "mstyle", "eye"):
        if k in shape: q[k] = shape[k]
    if shape.get("leaf"): pass
    pal = dict(pal); pal.update(WING)
    SPRITES.append(("queen_" + sid.replace("_ant", ""), 6, pal, ant_x(**q), {"directions": 16}))


# Playable characters: whole sprite (icons), iso legs and iso body for the 3D model.
CHARS = [
    ("bombardier_beetle", bombardier, 10, 18, dict(o="#05050a" + SOFT, l="#a04a14", t="#5a2208", T="#f0a060", e="#0a0606", w="#f0e0b0", s="#0a0a14", S="#e8b830",
        **ramp("#06060e", "#0e1020", "#1a1e38", "#2a3058", "#a8b8f0"), **ramp2("#7a2808", "#a83c10", "#d8601c", "#f08030", "#ffd0a0"))),
    ("tiger_beetle", tiger_beetle, 14, 26, dict(o="#020804" + SOFT, l="#3a6a30", t="#183a14", T="#a8e080", e="#1a1a10", w="#f0ecd0", s="#0e3a1a", S="#f0e8c0",
        **ramp("#0c3a20", "#145a30", "#1e8044", "#32a85c", "#c0ffd8"), **ramp2("#103a30", "#18604a", "#228a66", "#3cb48a", "#d0fff0"))),
    ("stag_beetle", stag_beetle, 9, 16, dict(o="#060302" + SOFT, l="#1a0e08", t="#4a3020", T="#a07858", e="#0a0606", w="#e8d0a0", s="#120804",
        **ramp("#1e0c06", "#34160a", "#4e2412", "#6a341c", "#d8a080"), **ramp2("#2a1008", "#4a1e0e", "#6e3018", "#904424", "#f0b088"))),
    ("scorpion", scorpion, 10, 18, dict(o="#080602" + SOFT, l="#5a4420", t="#2e2210", T="#d0b070", e="#0a0a0a", w="#2a1a0a",
        **ramp("#4a3a14", "#6a521e", "#8c6e2a", "#ae8c3a", "#f0e0a0"), **ramp2("#54401a", "#765a24", "#987632", "#bc9644", "#ffecb0"))),
    ("lobster", lobster, 8, 14, dict(o="#0a0302" + SOFT, l="#7c3c2e", t="#431f17", T="#d89883", e="#060404", w="#d8c3ad",
        **ramp("#51221a", "#793529", "#9e4a39", "#bb624a", "#e6b19c"), **ramp2("#56251c", "#80392c", "#a7513d", "#c46b4e", "#e6bca6"))),
    ("centipede", centipede, 18, 30, dict(o="#080202" + SOFT, l="#ce9e49", t="#704c20", T="#ebdfa3", e="#0a0604", w="#180c07",
        **ramp("#351410", "#532018", "#723022", "#91412f", "#dda088"), **ramp2("#180d0a", "#2a1812", "#40271e", "#58372a", "#bf9783"))),
    ("jumping_spider", jumping_spider, 14, 24, dict(o="#030303" + SOFT, l="#1a1616", m="#5a5250", b="#f0ece0", t="#0a0808", T="#c0b8b0", e="#060606", w="#30d0a0",
        **ramp("#0e0c0c", "#1c1818", "#2c2626", "#403838", "#c0b0a8"), **ramp2("#141010", "#241e1c", "#363030", "#4c4442", "#d0c4bc"))),
    ("tarantula", tarantula, 8, 16, dict(o="#040302" + SOFT, l="#1a1410", m="#3e3028", b="#e0702a", t="#0e0a08", T="#f09a50", e="#0a0606", w="#2a1e18",
        **ramp("#1a120e", "#2a1e18", "#3c2c24", "#523e32", "#b09a8a"), **ramp2("#221812", "#34261e", "#4a3628", "#644a38", "#c8b098"))),
    ("orb_weaver", orb_weaver, 12, 20, dict(o="#050402" + SOFT, l="#3a3020", m="#d8c890", b="#141008", t="#1a140a", T="#f0e0a0", e="#0a0606", w="#2a2010",
        **ramp("#8a6a0a", "#b48e14", "#dab424", "#f2d23e", "#fff8c0"), **ramp2("#5e6066", "#80848c", "#a4a8b0", "#c8ccd4", "#ffffff"))),
    ("mantis", mantis, 9, 16, dict(o="#030602" + SOFT, l="#4a7a28", t="#2a4a14", T="#c0f080", e="#1a2a08", w="#e8f0c0", v="#b8f080" + "a0", W="#6aa840" + "e0",
        **ramp("#2a5a14", "#3c7a1e", "#52a02a", "#6cc03a", "#d8ffb0"), **ramp2("#346a1a", "#4a8a24", "#62ac30", "#80c840", "#e0ffc0"))),
]
def centipede_part(kind):
    """Pieces of the chain-drawn centipede: one plated segment, or the head with its claws."""
    if kind == "seg":
        w, h, cy = 7, 9, 4
        def body(g):
            blob(g, 3, cy, 1.9, 2.8, RAMP1); line(g, [(1.4, cy - 2.3), (1.4, cy + 2.3)], 'A')
    elif kind == "seg2":
        w, h, cy = 7, 9, 4
        def body(g):
            blob(g, 3, cy, 1.9, 2.8, RAMP2); line(g, [(1.4, cy - 2.3), (1.4, cy + 2.3)], '1')
    else:
        w, h, cy = 9, 9, 4
        def body(g):
            blob(g, 3.5, cy, 2.3, 2.6, RAMP2)
            for sg in (-1, 1):
                line(g, [(5, cy + sg * 1.4), (6.8, cy + sg * 1.6), (7.6, cy + sg * 0.6)], 'w')
                put(g, 4, cy + sg * 1.2, 'e')
    g = blank(w, h); body(g); outline(g)
    return [[''.join(r) for r in g]]

for cid, fn, fps, lfps, pal in CHARS:
    SPRITES.append((cid, fps, pal, fn()))
    SPRITES.append((cid + "_legs", lfps, cid, fn("legs")))
    SPRITES.append((cid + "_body", fps, cid, fn("body")))
for part in ("seg", "seg2", "head"):
    SPRITES.append(("centipede_" + part, 1, "centipede", centipede_part(part)))

# 3D leg rigs for the characters: the legs' joint points (one side; mirrored in game), relative
# to the sprite centre, so the game can draw real jointed legs that step and plant their feet.
RIGS = {}
for cid, fn in [("rhino_beetle", beetle), ("wolf_spider", spider)] + [(c[0], c[1]) for c in CHARS]:
    fn("legs")
    r = RIG["last"]
    cx, cyy = (r["w"] - 1) / 2, (r["h"] - 1) / 2
    RIGS[cid + "_legs"] = [[(round(x - cx, 2), round(y - cyy, 2)) for (x, y) in leg] for leg in r["legs"]]

# Parts reuse their parent's palette and are baked as isometric views (iso = true).
PAL = {e[0]: e[2] for e in SPRITES if isinstance(e[2], dict)}

out = ["-- Top-down bug sprites (generated by tools/make_bug_sprites.py, safe to hand-edit).",
       "-- Face right; the game bakes rotations so bugs turn toward where they move.",
       "-- Ramps: 1..4/h and A..D/H (dark..light/gloss), o = soft outline, l = legs, e = eyes.",
       "return {"]
for entry in SPRITES:
    sid, fps, pal, frames = entry[:4]
    opts = entry[4] if len(entry) > 4 else {}
    out.append("    {")
    out.append(f'        id = "{sid}",')
    out.append(f"        fps = {fps},")
    if "directions" in opts: out.append(f"        directions = {opts['directions']},")
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
open("content/sprites/bugs.lua", "w").write("\n".join(out) + "\n")
print("wrote", len(SPRITES))
