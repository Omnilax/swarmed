# Generates the Mole Cricket and the Velvet Worm (playable) as text-grid Lua.
#   python3 tools/make_molecricket_sprites.py   ->  content/sprites/molecricket.lua
# Reuses the drawing helpers of tools/make_batch2_sprites.py (everything above its
# "Batch 2 playable bugs" line), so the look matches the rest of the cast. The big digging
# forelegs are not in the body: they are animation limbs (content/characters/mole_cricket.lua),
# so they can swipe and dig. Only the flat icon sprite paints them in.
import math, os

HERE = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(HERE, "make_batch2_sprites.py")).read().split("# ---- Batch 2 playable bugs")[0]
exec(_src)

def hairs(ch_from='l', ch_to='m', mod=3):
    def f(g, fr=None):
        for y in range(len(g)):
            for x in range(len(g[0])):
                if g[y][x] == ch_from and (x + 2 * y) % mod == 0: g[y][x] = ch_to
    return f

def mole_cricket(part=None):
    """Mole cricket: velvety brown, a big domed armoured pronotum like a helmet, a soft tapering
    abdomen with short folded wings, two tail cerci, short antennae and stout legs."""
    w, h, cy = 40, 28, 14
    def deco(g):
        # short folded forewings over the front of the abdomen, with veins
        for sg in (-1, 1):
            line(g, [(18.5, cy + sg * 1.0), (11, cy + sg * 3.6), (8.5, cy + sg * 2.8)], 'S')
            line(g, [(17, cy + sg * 2.4), (12.5, cy + sg * 4.2)], 'S')
        line(g, [(18.5, cy), (8, cy)], '1')
        for x in (5, 7):                                                 # soft rear segments
            line(g, [(x, cy - 3.6), (x - 0.5, cy), (x, cy + 3.6)], '2')
        # the helmet: a dark rim and a heart-shaped groove on top
        line(g, [(19.6, cy - 4.6), (19.2, cy), (19.6, cy + 4.6)], 'A')
        line(g, [(22, cy - 1.6), (24.5, cy), (22, cy + 1.6)], 'B')
        for sg in (-1, 1): put(g, 30.4, cy + sg * 1.6, 'e')             # eyes
    legs = [((21, cy - 4.2), (21.5, cy - 8.5), (19, cy - 11)),          # middle legs
            ((15.5, cy - 4.6), (11, cy - 8.5), (6, cy - 10.5))]          # stout hind legs
    def extra(g, f):
        hairs('l', 'm', 3)(g)
        antennae([(31.5, cy - 1.0), (34, cy - 2.6), (36.5, cy - 3.2)], cy)(g, f)
        both(g, [(3, cy - 1.2), (0.6, cy - 3.2)], 'l', cy, True)       # tail cerci
        if part is None:
            # flat icon only: the two shovel forelegs, broad and toothed
            for sg in (-1, 1):
                line(g, [(27, cy + sg * 3.6), (29.5, cy + sg * 6.2)], 'l')
                blob(g, 31, cy + sg * 7, 2.6, 2.0, RAMP2, bias=0.1)
                for k in range(3): put(g, 33.4, cy + sg * (5.6 + k * 1.2), 'w')
    return critter(w, h, cy, [seg(10, 8.4, 5.0), seg(23.5, 5.6, 5.4, RAMP2), seg(29.6, 2.6, 3.0, RAMP2)],
                   legs, deco, extra, part, stride=0.9)

def velvet_worm(part=None):
    """Velvet worm: a soft, velvety tube of a body in deep plum-brown, peppered with orange
    papillae, many stubby clawed lobopod legs, and two thick ringed antennae."""
    n = 12
    w, h, cy = 50, 20, 10
    xs = [5 + i * 3.1 for i in range(n)]
    def deco(g):
        for i, x in enumerate(xs):
            line(g, [(x - 1.5, cy - 2.6), (x - 1.5, cy + 2.6)], 'S')
            put(g, x, cy - 1.4 + (i % 2) * 2.4, 'd')
        for sg in (-1, 1): put(g, 44.6, cy + sg * 1.3, 'e')
    legs = [((x, cy - 2.6), (x - 0.2, cy - 3.8), (x - 0.6, cy - 4.8)) for x in xs]
    segs = [seg(x, 2.0, 3.0, RAMP1 if i % 2 else RAMP2, spec=False) for i, x in enumerate(xs)] + [seg(43.8, 2.4, 2.8, RAMP2, spec=False)]
    return critter(w, h, cy, segs, legs, deco, antennae([(46, cy - 1.2), (47.8, cy - 2.4), (49, cy - 2.6)], cy), part, stride=0.3)

def velvet_part(kind):
    """Pieces of the chain-drawn velvet worm: a soft ring (two tones) or the head."""
    if kind in ("seg", "seg2"):
        w, h, cy = 7, 10, 4.5
        def body(g):
            blob(g, 3, cy, 2.2, 3.3, RAMP1 if kind == "seg" else RAMP2, spec=False)
            line(g, [(1.0, cy - 2.6), (1.0, cy + 2.6)], 'S')
            put(g, 3, cy - 1.5 if kind == "seg" else cy + 1.5, 'd')
            put(g, 4, cy + 0.5 if kind == "seg" else cy - 0.5, 'd')
    else:
        w, h, cy = 13, 10, 4.5
        def body(g):
            blob(g, 4, cy, 2.7, 3.0, RAMP2, spec=False)
            for sg in (-1, 1):
                put(g, 5.4, cy + sg * 1.3, 'e')
                put(g, 6.8, cy + sg * 0.6, 'w')                          # slime papillae
                line(g, [(6, cy + sg * 1.6), (8.5, cy + sg * 2.6), (11.5, cy + sg * 3.0)], 'l')   # antennae
                for k in (8, 10): put(g, k, cy + sg * (2.0 + (k - 6) * 0.25), 'm')
    g = blank(w, h); body(g); outline(g)
    return [[''.join(r) for r in g]]

CHARS = [
    ("mole_cricket", mole_cricket, 10, 18, dict(o="#0a0603" + SOFT, l="#7a4e2a", m="#a0724a", t="#3e2412", T="#d8b082", e="#080504", w="#e8d2a8", S="#b8905e",
        **ramp("#3e2614", "#5c3a1e", "#7c522c", "#9c6c3c", "#e6c49c"), **ramp2("#2e1a0c", "#4a2c16", "#684022", "#86582e", "#dcb88e"))),
    ("velvet_worm", velvet_worm, 8, 24, dict(o="#100608" + SOFT, l="#6a3a48", m="#a0606e", t="#3a1a24", T="#c08890", e="#060304", w="#f0e0c0", S="#2a1018", d="#e0883a",
        **ramp("#2a121c", "#3e1c2a", "#56283a", "#70384c", "#c890a0"), **ramp2("#321620", "#4a2232", "#643044", "#7e4258", "#d098a8"))),
]

SPRITES = []
for cid, fn, fps, lfps, pal in CHARS:
    SPRITES.append((cid, fps, pal, fn()))
    SPRITES.append((cid + "_legs", lfps, cid, fn("legs")[:1], {"rotate": False}))
    SPRITES.append((cid + "_body", fps, cid, fn("body")))
for part in ("seg", "seg2", "head"):
    SPRITES.append(("velvet_worm_" + part, 1, "velvet_worm", velvet_part(part)))

RIGS = {}
for cid, fn in [(c[0], c[1]) for c in CHARS]:
    fn("legs")
    r = RIG["last"]
    cx, cyy = (r["w"] - 1) / 2, (r["h"] - 1) / 2
    RIGS[cid + "_legs"] = [[(round(x - cx, 2), round(y - cyy, 2)) for (x, y) in leg] for leg in r["legs"]]

PAL = {e[0]: e[2] for e in SPRITES if isinstance(e[2], dict)}

out = ["-- Mole Cricket (generated by tools/make_molecricket_sprites.py, safe to hand-edit).",
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
open(os.path.join(HERE, "..", "content", "sprites", "molecricket.lua"), "w").write("\n".join(out) + "\n")
print("wrote", len(SPRITES))
