# Generates the bee, wasp and hornet sprites and writes them as text-grid Lua.
#   python3 tools/make_hymenoptera_sprites.py   ->  content/sprites/hymenoptera.lua
# Same look as tools/make_bug_sprites.py (lit ellipsoids quantised to colour ramps, soft
# outline, facing right, the game bakes the rotations), with what hymenoptera need on top:
#   - three colour ramps, so a gaster can be banded (yellow / black / white-tailed bumblebees)
#     1..4/h, A..D/H and 5..8/j
#   - fuzz (f dark / F light hair) for bees, dense for velvet ants
#   - two pairs of beating wings over a motion blur (2 frames), or none for velvet ants
#   - big compound eyes (e, E glint), a sting (w), dangling legs (l) and pollen baskets (P)
# The helpers are copied from make_bug_sprites.py so the two scripts don't depend on each other.
import math, random

LIGHT = (-0.55, -0.65, 0.55)
_l = math.sqrt(sum(c * c for c in LIGHT))
LIGHT = tuple(c / _l for c in LIGHT)
RAMP1 = ('1', '2', '3', '4', 'h')
RAMP2 = ('A', 'B', 'C', 'D', 'H')
RAMP3 = ('5', '6', '7', '8', 'j')
RAMPS = {1: RAMP1, 2: RAMP2, 3: RAMP3}
BODY = set('1234hABCDH5678jweEfFPmn')

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

def blob(g, cx, cy, rx, ry, ramp=RAMP1, spec=True, bias=0.0, ramp_at=None, taper=0.0):
    """Lit ellipsoid. ramp_at(t) picks the ramp by position from the back end (t=0) to the
    front (t=1), for bands. taper narrows the back half (wasp gasters come to a point)."""
    for y in range(len(g)):
        for x in range(len(g[0])):
            dx = (x - cx) / rx
            k = 1 - taper * max(0.0, -dx) ** 1.5
            dy = (y - cy) / (ry * max(0.2, k))
            d2 = dx * dx + dy * dy
            if d2 <= 1.0:
                r = ramp_at((dx + 1) / 2) if ramp_at else ramp
                g[y][x] = shade(dx, dy, d2, r, spec, bias)

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

def bands(spec):
    """spec: list of (until_t, ramp_no) from the back end of the gaster forward."""
    def at(t):
        for until, r in spec:
            if t <= until: return RAMPS[r]
        return RAMPS[spec[-1][1]]
    return at

def hymen(sid, s, gl=1.0, gw=1.0, waist=0.0, tr=1.0, hs=1.0, es=1.0, al=1.0, wl=1.0, leg=1.0,
          gaster=None, thorax=2, head=2, taper=0.0, fuzz=0.0, fuzz_in=0.0, sting=0.6, pollen=False,
          wings=True, walk=False, ovipositor=0.0, deco=None, gloss=0.0):
    """One bee / wasp / hornet, facing right. Sizes are in units of s (about a pixel at s=1).
    gl/gw gaster length/width, waist petiole length (0 for bees), tr thorax, hs head, es eyes,
    al antennae, wl wings, leg legs; gaster = bands() or a ramp number; taper points the gaster;
    fuzz = chance of hair round the body edge, fuzz_in = hair texture on top of the body."""
    rng = random.Random(sid)
    grx, gry = 2.6 * s * gl, 1.55 * s * gw
    trx, try_ = 1.55 * s * tr, 1.35 * s * tr
    hrx, hry = 1.0 * s * hs, 1.3 * s * hs
    sting_len = sting * s + ovipositor * s
    m = 2 + sting_len
    gx = m + grx
    plen = waist * s
    tx = gx + grx * (0.92 if waist <= 0 else 1.0) + plen + trx * (0.8 if waist <= 0 else 0.95)
    hx = tx + trx * 0.88 + hrx * 0.75
    L = 5.6 * s * wl                      # forewing length
    reach_x = max(hx + hrx + (2.4 * s * al if al else 0), hx + hrx + 1)
    w = int(math.ceil(reach_x)) + 3
    half_w = (L * 0.98 + try_ * 0.7) if wings else 0
    half_l = try_ + (2.6 if walk else 1.8) * s * leg
    half = int(math.ceil(max(half_w, half_l, gry + 1, hry + (1.2 * s * al if al else 0)))) + 2
    h, cy = half * 2 + 1, half
    gramp = gaster if callable(gaster) else None
    gr = RAMPS[gaster] if isinstance(gaster, int) else RAMP1

    def body(g):
        blob(g, gx, cy, grx, gry, gr, ramp_at=gramp, taper=taper, bias=gloss)
        if waist > 0:
            px = gx + grx + plen / 2
            blob(g, px, cy, max(0.6, plen / 2 + 0.4), max(0.5, 0.42 * s), RAMPS[thorax], spec=False)
        blob(g, tx, cy, trx, try_, RAMPS[thorax], bias=gloss)
        blob(g, hx, cy, hrx, hry, RAMPS[head], bias=gloss)
        # compound eyes on the sides of the head, a glint on each
        for sg in (-1, 1):
            ex, ey = hx + hrx * 0.05, cy + sg * hry * 0.58
            erx, ery = max(0.6, 0.55 * hrx * es), max(0.6, 0.42 * hry * es)
            for yy in range(len(g)):
                for xx in range(len(g[0])):
                    if ((xx - ex) / erx) ** 2 + ((yy - ey) / ery) ** 2 <= 1: g[yy][xx] = 'e'
            put(g, ex - erx * 0.3, ey - ery * 0.3, 'E')
        for sg in (-1, 1):   # mandibles
            line(g, [(hx + hrx * 0.7, cy + sg * hry * 0.35), (hx + hrx + 0.5 * s, cy + sg * 0.25 * s)], 'w')
        if sting_len > 0:
            line(g, [(gx - grx + 0.4, cy), (gx - grx - sting * s, cy)], 'w')
        if ovipositor:
            for o in (-0.5, 0, 0.5):
                line(g, [(gx - grx, cy + o * 0.6), (gx - grx - sting_len, cy + o * 1.6)], 'w')
        if fuzz_in:
            for yy in range(len(g)):
                for xx in range(len(g[0])):
                    c = g[yy][xx]
                    if c in '1234h5678jABCDH' and rng.random() < fuzz_in:
                        g[yy][xx] = 'F' if c in '4hD H8j' and rng.random() < 0.6 else 'f'
        if deco: deco(g, dict(s=s, cy=cy, gx=gx, grx=grx, gry=gry, tx=tx, trx=trx, try_=try_, hx=hx, hrx=hrx, hry=hry, rng=rng))

    def fuzzy(g):
        if not fuzz: return
        h_, w_ = len(g), len(g[0])
        add = []
        for y in range(h_):
            for x in range(w_):
                if g[y][x] in '.o':
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w_ and 0 <= ny < h_ and g[ny][nx] in '1234h5678jABCDHfF' and rng.random() < fuzz:
                            add.append((x, y, 'F' if dy < 0 or dx < 0 else 'f')); break
        for x, y, c in add: g[y][x] = c

    def legs_fly(g):
        # tucked and dangling under the body in flight; the hind pair trails back along the gaster
        Lg = leg
        for sg in (-1, 1):
            pts = [
                [(tx + trx * 0.4, cy + sg * try_ * 0.5), (tx + trx * 0.7, cy + sg * (try_ + 0.5 * s * Lg)), (tx + trx * 0.95, cy + sg * (try_ + 0.6 * s * Lg))],
                [(tx - trx * 0.1, cy + sg * try_ * 0.6), (tx - trx * 0.3, cy + sg * (try_ + 0.7 * s * Lg)), (tx - trx * 0.8, cy + sg * (try_ + 0.9 * s * Lg))],
                [(tx - trx * 0.6, cy + sg * try_ * 0.5), (tx - trx * 1.2, cy + sg * (try_ + 0.4 * s * Lg)), (gx + grx * 0.3, cy + sg * (gry * 0.9 + 0.3 * s * Lg))],
            ]
            for p in pts: line(g, p, 'l', '.')
            if pollen:
                kx, ky = tx - trx * 1.1, cy + sg * (try_ + 0.9 * s * Lg)
                for yy in range(len(g)):
                    for xx in range(len(g[0])):
                        if ((xx - kx) / (0.6 * s)) ** 2 + ((yy - ky) / (0.45 * s)) ** 2 <= 1: g[yy][xx] = 'P'

    def legs_walk(g, phase):
        st = 0.9 * s
        Lg = leg
        lst = [
            lambda p: [(tx + trx * 0.5, cy - 0.5 * s), (tx + 2.0 * s * Lg, cy - 2.6 * s * Lg), (tx + 3.6 * s * Lg + p * st, cy - 3.6 * s * Lg)],
            lambda p: [(tx, cy - 0.6 * s), (tx + 0.3 * s * Lg, cy - 3.0 * s * Lg), (tx - 0.7 * s * Lg + p * st, cy - 4.3 * s * Lg)],
            lambda p: [(tx - trx * 0.5, cy - 0.5 * s), (tx - 2.6 * s * Lg, cy - 2.8 * s * Lg), (tx - 4.8 * s * Lg + p * st, cy - 3.9 * s * Lg)],
        ]
        for i, f in enumerate(lst):
            sign = 1 if i % 2 == 0 else -1
            line(g, f(phase * sign), 'l')
            line(g, mirror(f(-phase * sign), cy), 'l')

    def antennae(g, f):
        if not al: return
        twitch = 0.4 * s if f % 2 else 0
        a = [(hx + hrx * 0.55, cy - hry * 0.3), (hx + hrx + 0.5 * s * al, cy - hry - 0.9 * s * al),
             (hx + hrx + 2.4 * s * al, cy - hry - 0.2 * s * al - twitch)]
        both(g, a, 'l', cy, '.o')

    def wing(g, rootx, rooty, sg, ang, length, width, blur=False):
        # ang: radians out from straight back (0 = folded along the body, pi/2 = straight out)
        dx, dy = -math.cos(ang), sg * math.sin(ang)
        ccx, ccy = rootx + dx * length / 2, rooty + dy * length / 2
        for yy in range(len(g)):
            for xx in range(len(g[0])):
                px, py = xx - ccx, yy - ccy
                u = (px * dx + py * dy) / (length / 2)
                v = (-px * dy + py * dx) / (width / 2)
                d2 = u * u + v * v
                if d2 <= 1 and g[yy][xx] in ('.oul' if not blur else '.o'):
                    if blur: g[yy][xx] = 'u'
                    else: g[yy][xx] = 'W' if d2 > 0.62 else 'v'
        if not blur:
            # leading-edge vein and the dark stigma two thirds along it
            lx, ly = -dy * sg * width * 0.32, dx * sg * width * 0.32
            lead = [(rootx + lx * 0.3, rooty + ly * 0.3), (rootx + dx * length * 0.7 - lx * 0.1 * sg, rooty + dy * length * 0.7)]
            line(g, lead, 'V', 'vW')
            put(g, rootx + dx * length * 0.66, rooty + dy * length * 0.66, 'V', 'vW')

    def wings_fn(g, f):
        if not wings: return
        ang = (1.35, 0.55)[f % 2]
        for sg in (-1, 1):
            rx, ry = tx - trx * 0.1, cy + sg * try_ * 0.55
            # motion blur covering the stroke, then the crisp wings at this frame's angle
            for a in (0.5, 0.8, 1.1, 1.4):
                wing(g, rx, ry, sg, a, L * 0.95, 2.4 * s, blur=True)
            wing(g, rx - trx * 0.3, ry, sg, ang - 0.22, L * 0.7, 1.9 * s)
            wing(g, rx, ry, sg, ang, L, 2.5 * s)

    frames = []
    nframes = 4 if walk else 2
    for f in range(nframes):
        g = blank(w, h)
        if walk: legs_walk(g, (0.0, 1.0, 0.0, -1.0)[f])
        else: legs_fly(g)
        body(g)
        fuzzy(g)
        outline(g)
        antennae(g, f)
        wings_fn(g, f)
        frames.append([''.join(r) for r in g])
    return frames

# ---- decorations -----------------------------------------------------------------------------
def spots(ramp_ch, pts_fn):
    def d(g, q):
        for (x, y) in pts_fn(q):
            put(g, x, y, ramp_ch, '1234h5678jABCDH')
    return d

def chain(*ds):
    def d(g, q):
        for f in ds: f(g, q)
    return d

def face(ch):
    """A pale face (bald-faced hornet, oriental hornet, sand wasp): front of the head."""
    def d(g, q):
        for yy in range(len(g)):
            for xx in range(len(g[0])):
                if g[yy][xx] in 'ABCDH5678j' and xx > q['hx'] + q['hrx'] * 0.2 and abs(yy - q['cy']) < q['hry'] * 0.55:
                    g[yy][xx] = ch
    return d

def stripe_thorax(ch, frac=0.3):
    """A pale collar across the front of the thorax (yellowjackets, bumblebees)."""
    def d(g, q):
        for yy in range(len(g)):
            for xx in range(len(g[0])):
                if g[yy][xx] in 'ABCDH5678j1234h' and q['tx'] + q['trx'] * (1 - 2 * frac) < xx < q['tx'] + q['trx'] and abs(yy - q['cy']) <= q['try_']:
                    if ((xx - q['tx']) / q['trx']) ** 2 + ((yy - q['cy']) / q['try_']) ** 2 <= 1: g[yy][xx] = ch
    return d

def side_spots(ch):
    """Paired yellow spots down the sides of the gaster (wool carder bee, cicada killer)."""
    def d(g, q):
        for t in (-0.55, -0.15, 0.25):
            for sg in (-1, 1):
                x = q['gx'] + t * q['grx']
                y = q['cy'] + sg * q['gry'] * 0.55
                put(g, x, y, ch, '1234hABCDH5678j'); put(g, x + 1, y, ch, '1234hABCDH5678j')
    return d

def gloss_dots(ch):
    """Pitted metallic shell (cuckoo wasp): a scatter of bright dots."""
    def d(g, q):
        rng = q['rng']
        for yy in range(len(g)):
            for xx in range(len(g[0])):
                if g[yy][xx] in '123ABC567' and rng.random() < 0.12: g[yy][xx] = 'm'
    return d

def tail_mark(ch):
    """Teardrop marks on each band (European hornet, yellowjacket arrows)."""
    def d(g, q):
        for t in (-0.6, -0.25, 0.1):
            x = q['gx'] + t * q['grx']
            for sg in (-1, 1):
                put(g, x, q['cy'] + sg * q['gry'] * 0.3, ch, '1234h5678jABCDH')
            put(g, x + 0.6, q['cy'], ch, '1234h5678jABCDH')
    return d

# ---- palettes --------------------------------------------------------------------------------
SOFT = "b0"
def ramp(chars, cols): return dict(zip(chars, cols))
def P(o, l, e, w, r1, r2, r3=None, wing=("#d8e4f0", "#a8b8c8", "#5a6470"), wa=("60", "a8", "d0"),
      blur="#c8d4e0", ba="1c", fuzz=("#2a2016", "#b0a080"), pollen="#e8a020", m="#ffffff", n="#000000", E="#d0e0ff"):
    d = dict(o=o + SOFT, l=l, e=e, E=E, w=w, v=wing[0] + wa[0], W=wing[1] + wa[1], V=wing[2] + wa[2], u=blur + ba,
             f=fuzz[0], F=fuzz[1], P=pollen, m=m, n=n)
    d.update(ramp(RAMP1, r1)); d.update(ramp(RAMP2, r2)); d.update(ramp(RAMP3, r3 or r2))
    return d

# common ramps (dark .. light, gloss)
BLACK = ("#0a0806", "#16120e", "#241e18", "#363028", "#a8a090")
JET = ("#050508", "#0e0e14", "#1a1a24", "#2c2c3a", "#c0c4e0")
AMBER = ("#5a3208", "#8a5414", "#b8781e", "#d89a34", "#ffe0a0")
YELLOW = ("#8a6a08", "#b89010", "#e0b81c", "#f8d83a", "#fff6b0")
LEMON = ("#7a7010", "#a8a018", "#d0c828", "#ece448", "#fffcc0")
BROWN = ("#2a1a0e", "#422a16", "#5e3e20", "#7a542c", "#d0b090")
TAWNY = ("#5a2a0c", "#843e14", "#ac5a1e", "#cc7a2c", "#ffc890")
RUST = ("#4a1608", "#70220c", "#983414", "#b84a1e", "#f0a070")
IVORY = ("#8a8478", "#b0aa9c", "#d4cebe", "#ece6d8", "#ffffff")
GREEN_M = ("#0a3a20", "#126030", "#1e8a44", "#34b05c", "#c8ffd8")
TEAL_M = ("#06303a", "#0c5060", "#16788a", "#2aa0b0", "#c8f8ff")
BLUE_M = ("#0a1430", "#14224a", "#203468", "#344c8c", "#b8c8ff")
RUBY = ("#4a0814", "#78101e", "#a81c2c", "#d0343e", "#ffb0b8")
GREY = ("#2a2826", "#423e3a", "#5e5852", "#7a746c", "#d0ccc4")
VELVET = ("#5a0806", "#8a120c", "#b81e14", "#e0381e", "#ff9a7a")

HONEY_BANDS = bands([(0.16, 2), (0.3, 1), (0.42, 2), (0.56, 1), (0.68, 2), (1.0, 1)])
SPRITES = []
def add(sid, fps, pal, frames, **opts): SPRITES.append((sid, fps, pal, frames, opts))

# ---- bees ------------------------------------------------------------------------------------
add("honey_bee", 30, P("#0a0604", "#2a1a0e", "#140c08", "#3a2414", AMBER, BLACK, BROWN, fuzz=("#3a2814", "#c8a060")),
    hymen("honey_bee", 1.25, gaster=HONEY_BANDS, thorax=3, head=2, fuzz=0.35, fuzz_in=0.25, pollen=True, taper=0.3))
add("africanized_bee", 30, P("#0a0604", "#2a160a", "#140808", "#3a2014",
        ("#4a2406", "#7a3e10", "#a45a18", "#c47a28", "#ffd090"), BLACK, BROWN, fuzz=("#2e1e10", "#b08850")),
    hymen("africanized_bee", 1.15, gaster=bands([(0.2, 2), (0.32, 1), (0.48, 2), (0.6, 1), (0.74, 2), (1.0, 1)]),
          thorax=3, head=2, fuzz=0.3, fuzz_in=0.2, taper=0.35))
add("bumblebee", 18, P("#060404", "#1a1410", "#0c0808", "#2a2018", YELLOW, BLACK, IVORY, fuzz=("#1a1610", "#e8d080")),
    hymen("bumblebee", 2.0, gl=1.0, gw=1.25, tr=1.1, gaster=bands([(0.22, 3), (0.55, 2), (0.78, 1), (1.0, 2)]),
          thorax=2, head=2, fuzz=0.7, fuzz_in=0.45, pollen=True, wl=0.8, sting=0.3,
          deco=stripe_thorax('4', 0.35)))
add("carpenter_bee", 18, P("#040406", "#141418", "#0a0a0e", "#2a2a30", JET, YELLOW, BLACK,
        wing=("#4a3a6a", "#2a2040", "#1a1424"), wa=("70", "b0", "d0"), blur="#6a5a8a", fuzz=("#3a3010", "#f0d060")),
    hymen("carpenter_bee", 2.0, gl=1.0, gw=1.15, tr=1.1, hs=1.05, gaster=1, thorax=2, head=3, fuzz=0.2, gloss=0.12, sting=0.3))
add("leafcutter_bee", 22, P("#060404", "#2a2018", "#0c0808", "#d0c0a0", GREY, BROWN, IVORY, fuzz=("#2a2218", "#d8ccb0")),
    hymen("leafcutter_bee", 1.4, gl=1.05, hs=1.2, gaster=bands([(0.1, 1), (0.18, 3), (0.34, 1), (0.42, 3), (0.58, 1), (0.66, 3), (1.0, 1)]),
          thorax=2, head=2, fuzz=0.3, fuzz_in=0.15, taper=0.2))
add("mason_bee", 22, P("#04040a", "#1a1a24", "#08080c", "#2a2a3a", BLUE_M, BLUE_M, BLACK, fuzz=("#1a1a24", "#9090a8")),
    hymen("mason_bee", 1.35, gw=1.15, gaster=1, thorax=2, head=2, fuzz=0.45, fuzz_in=0.25, gloss=0.08))
add("sweat_bee", 30, P("#020604", "#1a2a1a", "#081008", "#1a2a14", YELLOW, GREEN_M, BLACK, fuzz=("#14281a", "#a0e0b0")),
    hymen("sweat_bee", 0.9, gaster=bands([(0.15, 3), (0.3, 1), (0.42, 3), (0.57, 1), (0.7, 3), (1.0, 1)]),
          thorax=2, head=2, fuzz=0.15, gloss=0.15, taper=0.3))
add("cuckoo_bee", 26, P("#0a0402", "#7a3a14", "#100604", "#3a1a0a", RUST, RUST, YELLOW),
    hymen("cuckoo_bee", 1.25, gl=1.1, gw=0.9, waist=0.3, gaster=bands([(0.15, 1), (0.25, 3), (0.42, 1), (0.52, 3), (1.0, 1)]),
          thorax=2, head=2, taper=0.5, al=1.2))
add("stingless_bee", 34, P("#060402", "#2a1a10", "#100806", "#3a2416", BROWN, BLACK, BROWN,
        wing=("#e8eef4", "#c0ccd8", "#7a8490"), wa=("40", "80", "b0")),
    hymen("stingless_bee", 0.85, gl=0.8, wl=1.35, gaster=1, thorax=2, head=2, fuzz=0.15, sting=0, pollen=True))
add("fire_bee", 30, P("#0c0402", "#6a2a0e", "#140604", "#e05a1a", TAWNY, RUST, BLACK, fuzz=("#5a2a0e", "#ffb060"), E="#ffe0a0"),
    hymen("fire_bee", 1.05, gaster=1, thorax=2, head=2, fuzz=0.25, fuzz_in=0.1, sting=0))
add("mining_bee", 24, P("#060404", "#2a1a10", "#0c0806", "#2a1a10", BLACK, TAWNY, BROWN, fuzz=("#6a3410", "#f0a050")),
    hymen("mining_bee", 1.35, gaster=bands([(0.45, 1), (1.0, 3)]), thorax=2, head=3, fuzz=0.55, fuzz_in=0.4, taper=0.25))
add("orchid_bee", 26, P("#020604", "#1a4a2a", "#04140a", "#2a4a3a", GREEN_M, GREEN_M, TEAL_M, E="#ffffff"),
    hymen("orchid_bee", 1.4, gw=1.1, gaster=bands([(0.5, 1), (1.0, 3)]), thorax=2, head=3, gloss=0.2, sting=0.3))
add("wool_carder_bee", 26, P("#060404", "#a08a20", "#0a0806", "#2a2414", BLACK, BLACK, YELLOW, fuzz=("#2a2414", "#c8c0a0")),
    hymen("wool_carder_bee", 1.45, gw=1.05, gaster=1, thorax=2, head=2, fuzz=0.3, fuzz_in=0.15, sting=0.4,
          deco=chain(side_spots('8'), face('7'))))
add("giant_honey_bee", 28, P("#0a0604", "#2a1a0e", "#140c08", "#3a2414",
        ("#6a3608", "#9a5a10", "#c8801a", "#e4a030", "#ffe4a0"), BLACK, BLACK, fuzz=("#2a1a0e", "#c09860")),
    hymen("giant_honey_bee", 1.55, gl=1.1, gaster=bands([(0.2, 2), (0.36, 1), (0.5, 2), (0.66, 1), (1.0, 2)]),
          thorax=3, head=2, fuzz=0.3, fuzz_in=0.2, taper=0.35))
add("japanese_honey_bee", 30, P("#060404", "#221a14", "#0c0806", "#2a2018",
        ("#3a3020", "#5a4a30", "#7a6840", "#9a8858", "#e8dcc0"), BLACK, BLACK, fuzz=("#2a2218", "#b0a080")),
    hymen("japanese_honey_bee", 1.15, gaster=HONEY_BANDS, thorax=3, head=2, fuzz=0.35, fuzz_in=0.25, taper=0.3))

# ---- wasps -----------------------------------------------------------------------------------
YJ_BANDS = bands([(0.12, 1), (0.22, 2), (0.36, 1), (0.46, 2), (0.6, 1), (0.7, 2), (1.0, 1)])
add("yellowjacket", 30, P("#060402", "#c8a020", "#0a0806", "#2a2010", YELLOW, BLACK, YELLOW),
    hymen("yellowjacket", 1.35, gw=1.0, waist=0.25, gaster=YJ_BANDS, thorax=2, head=3, taper=0.6, gloss=0.08,
          deco=chain(tail_mark('B'), stripe_thorax('7', 0.18))))
add("paper_wasp", 26, P("#0a0402", "#c08a20", "#100604", "#2a140a", RUST, RUST, YELLOW),
    hymen("paper_wasp", 1.35, gl=1.2, gw=0.85, waist=0.6, gaster=bands([(0.3, 1), (0.36, 3), (0.62, 1), (0.68, 3), (1.0, 1)]),
          thorax=2, head=2, taper=0.6, leg=1.4, al=1.2))
add("cicada_killer", 22, P("#060302", "#a06020", "#0e0806", "#2a1408", BLACK, RUST, YELLOW,
        wing=("#c89a50", "#8a6020", "#4a3010"), wa=("50", "a0", "d0"), blur="#d0a060"),
    hymen("cicada_killer", 2.0, gl=1.1, waist=0.4, gaster=bands([(0.2, 1), (0.28, 3), (0.48, 1), (0.56, 3), (1.0, 1)]),
          thorax=2, head=2, taper=0.55, deco=side_spots('7')))
add("jewel_wasp", 30, P("#020406", "#c02a1a", "#06100c", "#2a3a3a", TEAL_M, GREEN_M, TEAL_M),
    hymen("jewel_wasp", 1.3, gl=1.0, gw=0.9, waist=0.5, gaster=1, thorax=2, head=2, taper=0.55, gloss=0.2, leg=1.2, al=1.3))
add("ichneumon_wasp", 26, P("#060402", "#d07a20", "#0c0604", "#2a1a0e", TAWNY, BLACK, IVORY),
    hymen("ichneumon_wasp", 1.2, gl=1.5, gw=0.7, waist=0.7, gaster=bands([(0.7, 1), (1.0, 2)]), thorax=2, head=2,
          taper=0.4, leg=1.5, al=1.7, ovipositor=6, sting=0))
add("cuckoo_wasp", 26, P("#020406", "#1a5a5a", "#04080a", "#1a2a2a", RUBY, TEAL_M, BLUE_M, m="#ffffff"),
    hymen("cuckoo_wasp", 1.3, gl=0.85, gw=1.1, gaster=1, thorax=2, head=3, taper=0.3, gloss=0.2, sting=0.2,
          deco=gloss_dots('m')))
add("sand_wasp", 26, P("#040402", "#c0c060", "#405a30", "#1a1a0a", LEMON, BLACK, LEMON, E="#e0ffd0"),
    hymen("sand_wasp", 1.45, gw=1.0, waist=0.2, es=1.3, gaster=bands([(0.14, 2), (0.24, 1), (0.38, 2), (0.48, 1), (0.62, 2), (0.72, 1), (1.0, 2)]),
          thorax=2, head=2, taper=0.45))
add("warrior_wasp", 26, P("#020206", "#14141e", "#06060a", "#1a1a2a", BLUE_M, JET, JET,
        wing=("#3a3a4a", "#22222e", "#141418"), wa=("60", "a0", "d0"), blur="#5a5a6a"),
    hymen("warrior_wasp", 1.4, gl=1.05, waist=0.35, gaster=1, thorax=2, head=2, taper=0.5, gloss=0.12))
add("hover_wasp", 30, P("#060402", "#6a5030", "#0a0806", "#2a1a10", BROWN, BROWN, IVORY),
    hymen("hover_wasp", 1.2, gl=0.9, gw=0.75, waist=1.6, gaster=bands([(0.2, 1), (0.3, 3), (1.0, 1)]), thorax=2, head=2,
          taper=0.3, wl=1.1, leg=1.2))
add("bald_faced_hornet", 26, P("#020204", "#1a1a20", "#08080c", "#2a2a30", JET, JET, IVORY),
    hymen("bald_faced_hornet", 1.6, gw=1.0, waist=0.25, gaster=bands([(0.18, 3), (0.26, 1), (0.36, 3), (1.0, 1)]),
          thorax=2, head=2, taper=0.55, deco=chain(face('7'), stripe_thorax('6', 0.12))))
add("mud_dauber", 26, P("#020202", "#d0b020", "#060606", "#1a1a1a", JET, JET, YELLOW,
        wing=("#6a6a8a", "#3a3a5a", "#1a1a2a"), wa=("50", "a0", "d0"), blur="#7a7a9a"),
    hymen("mud_dauber", 1.35, gl=0.9, gw=0.85, waist=3.0, gaster=1, thorax=2, head=2, taper=0.3, leg=1.5, gloss=0.1))
add("tarantula_hawk", 20, P("#020206", "#0e0e1a", "#06060c", "#1a1a2a", BLUE_M, JET, JET,
        wing=("#e0782a", "#b04a14", "#6a2a0a"), wa=("c0", "e8", "f0"), blur="#f08a3a", ba="30"),
    hymen("tarantula_hawk", 2.4, gl=1.15, gw=0.9, waist=0.5, gaster=1, thorax=2, head=2, taper=0.5, leg=1.6, al=1.3,
          gloss=0.15, wl=1.05))
add("velvet_ant", 16, P("#040202", "#1a0e0c", "#0a0606", "#1a1010", VELVET, BLACK, VELVET, fuzz=("#3a0806", "#ff6a4a")),
    hymen("velvet_ant", 1.35, gl=0.9, gw=1.2, tr=0.95, gaster=bands([(0.3, 2), (1.0, 1)]), thorax=3, head=2, fuzz=0.5, fuzz_in=0.35,
          wings=False, walk=True, leg=1.1, sting=0.2))

# ---- hornets ---------------------------------------------------------------------------------
add("giant_hornet", 22, P("#060302", "#5a3a14", "#140a04", "#1a0c04",
        ("#6a3a08", "#9a5a10", "#c8801a", "#e8a828", "#fff0b0"), ("#1a0e08", "#2e1a0e", "#462a16", "#603c20", "#d0a880"),
        TAWNY, wing=("#c89a50", "#8a6020", "#4a3010"), wa=("50", "a0", "d0"), blur="#d0a060", E="#ffffff"),
    hymen("giant_hornet", 2.5, gl=1.0, gw=1.05, hs=1.25, waist=0.25, gaster=bands([(0.14, 2), (0.3, 1), (0.42, 2), (0.58, 1), (0.7, 2), (1.0, 1)]),
          thorax=2, head=3, taper=0.5, gloss=0.08))
add("european_hornet", 24, P("#060302", "#7a3a14", "#100604", "#2a0e04", YELLOW, RUST, RUST,
        wing=("#c8a070", "#8a6a3a", "#4a3418"), wa=("50", "a0", "d0"), blur="#d0b080"),
    hymen("european_hornet", 2.1, waist=0.25, hs=1.1, gaster=bands([(0.55, 1), (0.66, 2), (1.0, 3)]), thorax=2, head=3,
          taper=0.5, deco=tail_mark('B')))
add("asian_hornet", 26, P("#040302", "#d0a030", "#0a0604", "#1a0c06", BLACK, BLACK, TAWNY),
    hymen("asian_hornet", 1.95, waist=0.25, gaster=bands([(0.18, 1), (0.32, 3), (0.4, 1), (1.0, 1)]), thorax=2, head=3,
          taper=0.5, deco=face('8')))
add("oriental_hornet", 24, P("#060302", "#7a3a14", "#100604", "#2a0e04", RUST, RUST, YELLOW),
    hymen("oriental_hornet", 2.05, waist=0.25, gaster=bands([(0.3, 1), (0.52, 3), (1.0, 1)]), thorax=2, head=2,
          taper=0.5, deco=face('7')))
add("banded_hornet", 26, P("#020202", "#2a1a0e", "#080606", "#1a1008", JET, JET, YELLOW),
    hymen("banded_hornet", 1.95, waist=0.25, gaster=bands([(0.72, 1), (0.86, 3), (1.0, 1)]), thorax=2, head=2, taper=0.5,
          gloss=0.08))

# ---- things that aren't bugs -----------------------------------------------------------------
def paper_nest():
    """An umbrella paper wasp nest seen from above: a grey disc of hexagonal cells, some capped."""
    w = h = 19
    c = 9
    g = blank(w, h)
    rng = random.Random("nest")
    for y in range(h):
        for x in range(w):
            dx, dy = (x - c) / 8.6, (y - c) / 8.6
            d2 = dx * dx + dy * dy
            if d2 <= 1:
                g[y][x] = shade(dx, dy, d2, RAMP1, spec=False)
    # cell walls in a hex pattern; the cell mouths are dark, a few capped pale
    for y in range(h):
        for x in range(w):
            if g[y][x] in RAMP1:
                cx = (x + (1 if (y // 2) % 2 else 0)) % 3
                if y % 2 == 0 and cx == 0 or (y % 2 == 1 and cx == 1):
                    g[y][x] = 'm' if rng.random() < 0.18 else 'n'
    put(g, c, c, 'A'); put(g, c + 1, c, 'B')     # the stalk
    outline(g)
    return [[''.join(r) for r in g]]

def mud_pipe():
    """A mud dauber's pipe from above: a lumpy ring of mud with a dark opening."""
    w = h = 11
    c = 5
    g = blank(w, h)
    for y in range(h):
        for x in range(w):
            dx, dy = (x - c) / 4.6, (y - c) / 4.6
            d2 = dx * dx + dy * dy
            if d2 <= 1: g[y][x] = shade(dx, dy, d2, RAMP1, spec=False)
            if d2 <= 0.22: g[y][x] = 'n'
    for (x, y) in ((2, 4), (7, 3), (4, 8), (8, 6)): put(g, x, y, 'm', RAMP1)    # mud balls
    outline(g)
    return [[''.join(r) for r in g]]

def grub():
    """An ichneumon grub: pale, soft, segmented; wriggles over two frames."""
    frames = []
    for f in range(2):
        w, h, cy = 15, 9, 4
        g = blank(w, h)
        for i in range(6):
            x = 2.5 + i * 1.9
            y = cy + math.sin(i * 0.9 + f * math.pi) * 0.6
            blob(g, x, y, 1.5, 2.0 - abs(i - 2.5) * 0.15, RAMP1, spec=True)
        for i in range(1, 6):
            line(g, [(2.5 + i * 1.9 - 0.9, cy - 1.4), (2.5 + i * 1.9 - 0.9, cy + 1.4)], '2', '1234h')
        blob(g, 13, cy, 1.1, 1.2, RAMP2)
        put(g, 14, cy, 'w')
        outline(g)
        frames.append([''.join(r) for r in g])
    return frames

add("paper_nest", 1, P("#1a1814", "#3a3630", "#000000", "#3a3630", ("#5a564e", "#7a756a", "#9a958a", "#b8b2a6", "#e8e2d4"),
        ("#3a3228", "#4a4034", "#5a5040", "#6a604e", "#a09080"), m="#e8e0cc", n="#2a2622"), paper_nest(), rotate=False)
add("mud_pipe", 1, P("#140c06", "#3a2a1a", "#000000", "#000000", ("#3a2a1a", "#5a4430", "#7a6046", "#967a5c", "#c8b090"),
        BROWN, m="#a08060", n="#0e0804"), mud_pipe(), rotate=False)
add("ichneumon_larva", 4, P("#2a2418", "#6a6050", "#000000", "#3a2a14", ("#a89c80", "#c8bea0", "#e0d8bc", "#f0ead4", "#ffffff"),
        ("#6a4a20", "#8a6430", "#aa8044", "#c89c58", "#f0d8a0")), grub())

out = ["-- Bee, wasp and hornet sprites (generated by tools/make_hymenoptera_sprites.py, safe to hand-edit).",
       "-- Face right; the game bakes rotations. Ramps: 1..4/h, A..D/H, 5..8/j (dark..light/gloss),",
       "-- o = soft outline, l = legs, e/E = eyes, w = jaws and sting, v/W/V = wings, u = wing blur, f/F = fuzz.",
       "return {"]
for sid, fps, pal, frames, opts in SPRITES:
    out.append("    {")
    out.append(f'        id = "{sid}",')
    out.append(f"        fps = {fps},")
    if opts.get("rotate") is False: out.append("        rotate = false,")
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
open("content/sprites/hymenoptera.lua", "w").write("\n".join(out) + "\n")
print("wrote", len(SPRITES))
