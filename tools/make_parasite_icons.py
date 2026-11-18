# Icons for parasite items (rarity "parasite", src/game/parasites.lua) -> content/sprites/parasites.lua.
#   PYTHONPATH=tools python3 tools/make_parasite_icons.py                 (needs numpy)
#   PYTHONPATH=tools python3 tools/make_parasite_icons.py --preview out.png [ids...]
# Same painted renderer as the item icons (tools/icon_render.py). Every parasite gets a faint
# sickly red under-glow (`infect`) so they read as one family next to the normal items.
# Kept apart from items.lua so new items and new parasites don't touch the same generated file.
import math, sys
import numpy as np
import make_item_icons as base
from icon_render import quantize, render_fit
from make_item_icons import R, hairs, in_ell, leg, speck

pi = math.pi
ICONS = []


def icon(iid, cols, rows, shape=None, seed=1):
    def deco(fn):
        def run(I):
            I._infect = []
            fn(I)
            for f, amt in I._infect: I.glow(f, "#5a0a18", amt)
        ICONS.append((iid, cols, rows, shape, seed, run))
        return fn
    return deco


def infect(I, f, amt=0.5):
    """The parasite family mark: a dull red glow over the creature (applied once it is drawn)."""
    I._infect.append((f, amt))


@icon("horsehair_worm", 1, 2)
def horsehair_worm(I):          # a long dark hair-thin worm in loose knots
    pts = []
    for t in np.linspace(0, 1, 90):
        a = t * pi * 7
        pts.append((0.5 + math.sin(a) * 0.3 * (0.6 + 0.4 * math.sin(t * 5)), 0.12 + t * 1.76 + math.cos(a) * 0.08))
    infect(I, I.T(pts, 0.05))
    I.add(I.T(pts, 0.03), "#3a2a1c", gloss=1.2, shin=34, mottle=0.1)
    I.paint(I.T(pts[5:-5], 0.01), "#8a6a40", amt=0.55)


@icon("deer_tick", 1, 1)
def deer_tick(I):               # an engorged tick: swollen grey-blue body, small red shield
    infect(I, I.E(0.5, 0.58, 0.36, 0.34))
    for s in (-1, 1):
        for k, y in enumerate((0.36, 0.44, 0.52, 0.6)):
            leg(I, [(0.5 + s * 0.16, y), (0.5 + s * 0.36, y - 0.06 + k * 0.03), (0.5 + s * 0.46, y + 0.06 + k * 0.04)], [0.022, 0.018, 0.012], "#4a2a1a")
    I.add(I.E(0.5, 0.6, 0.3, 0.3), "#8a8ea0", gloss=1.4, shin=40, mottle=0.12)
    I.carve(I.T([(0.3, 0.62), (0.7, 0.62)], 0.01), 0.01)
    I.add(I.E(0.5, 0.3, 0.13, 0.11), "#7a2a1a", mode="max", gloss=1.0, shin=30)
    I.add(I.E(0.5, 0.16, 0.05, 0.06), "#3a1a10", mode="max", gloss=0.8)


@icon("head_lice", 1, 1)
def head_lice(I):               # three pale lice on a couple of hairs
    for x in (0.2, 0.55, 0.85):
        I.add(I.T([(x, 0.05), (x - 0.1, 0.95)], 0.015), "#3a2a20", gloss=0.6)
    for (cx, cy, a, s) in ((0.32, 0.3, 0.3, 1.0), (0.68, 0.62, -0.4, 0.9), (0.3, 0.78, 0.8, 0.7)):
        infect(I, I.E(cx, cy, 0.16 * s, 0.2 * s, rot=a), 0.35)
        for k in (-1, 1):
            for j in (-0.05, 0.02, 0.09):
                leg(I, [(cx, cy + j * s), (cx + k * 0.12 * s, cy + (j + 0.03) * s)], [0.012, 0.008], "#6a5040")
        I.add(I.E(cx, cy + 0.04 * s, 0.1 * s, 0.14 * s, rot=a), "#d8c8a8", gloss=1.0, shin=30, op=0.9)
        I.add(I.E(cx - math.sin(a) * 0.12 * s, cy - 0.12 * s, 0.05 * s, 0.05 * s), "#b8a080", mode="max", gloss=0.8)
        I.paint(I.E(cx, cy + 0.06 * s, 0.05 * s, 0.08 * s, rot=a), "#7a3a2a", amt=0.6)


@icon("follicle_mite", 1, 1)
def follicle_mite(I):           # a worm-like Demodex mite: stubby legs up front, long ringed tail
    pts = [(0.5, 0.15 + t * 0.75) for t in np.linspace(0, 1, 12)]
    rs = [0.11 * (1 - t * 0.6) for t in np.linspace(0, 1, 12)]
    infect(I, I.T(pts, [r * 1.6 for r in rs]))
    for s in (-1, 1):
        for y in (0.22, 0.28, 0.34, 0.4):
            leg(I, [(0.5 + s * 0.08, y), (0.5 + s * 0.17, y + 0.03)], [0.02, 0.014], "#c8a890")
    I.add(I.T(pts, rs), "#e8d4c0", gloss=1.1, shin=30, mottle=0.08, op=0.92)
    for (x, y) in pts[4:-1]: I.carve(I.E(x, y, 0.08, 0.008), 0.008)
    I.add(I.E(0.5, 0.13, 0.05, 0.04), "#b89878", mode="max")


@icon("flu_virus", 1, 1)
def flu_virus(I):               # a spiky virion: a ball studded with knobbed spikes
    infect(I, I.E(0.5, 0.5, 0.44, 0.44))
    for k in range(16):
        a = k / 16 * 2 * pi
        x1, y1 = 0.5 + math.cos(a) * 0.3, 0.5 + math.sin(a) * 0.3
        x2, y2 = 0.5 + math.cos(a) * 0.42, 0.5 + math.sin(a) * 0.42
        I.add(I.T([(x1, y1), (x2, y2)], 0.018), "#5a9a5a", gloss=0.6)
        I.add(I.E(x2, y2, 0.035, 0.035), "#e0c040" if k % 2 else "#c86a8a", mode="max", gloss=1.2, shin=30)
    I.add(I.E(0.5, 0.5, 0.3, 0.3), "#7ab878", gloss=1.0, shin=24, mottle=0.25, mscale=0.08)
    speck(I, 14, in_ell(0.5, 0.5, 0.26, 0.26), "#3a6a40", seed=5, amt=0.7)


@icon("cordyceps_puppet", 1, 2)
def cordyceps_puppet(I):        # an ant's head with an orange fungal stalk bursting from it
    infect(I, I.E(0.5, 1.5, 0.36, 0.3))
    I.add(I.E(0.5, 1.52, 0.27, 0.22), "#2a1a14", gloss=1.0, shin=30)
    for s in (-1, 1):
        I.add(I.T([(0.5 + s * 0.12, 1.68), (0.5 + s * 0.2, 1.88)], [0.03, 0.015]), "#2a1a14", gloss=0.8)
        I.add(I.T([(0.5 + s * 0.1, 1.36), (0.5 + s * 0.3, 1.2), (0.5 + s * 0.38, 1.3)], 0.012), "#2a1a14")
    pts = [(0.5 + math.sin(t * 2.5) * 0.08, 1.35 - t * 1.15) for t in np.linspace(0, 1, 16)]
    I.add(I.T(pts, [0.06 - 0.03 * t for t in np.linspace(0, 1, 16)]), "#d07a2a", gloss=0.5, mottle=0.25)
    I.add(I.E(pts[-1][0], pts[-1][1], 0.1, 0.13), "#e89a3a", mode="max", gloss=0.6, mottle=0.3)
    speck(I, 12, in_ell(pts[-1][0], pts[-1][1], 0.09, 0.12), "#7a3a10", seed=3)
    I.glow(I.E(pts[-1][0], pts[-1][1], 0.12, 0.14), "#ffb050", 0.4)


@icon("toxoplasma", 1, 1)
def toxoplasma(I):              # crescent-shaped protozoa, glowing faintly inside a cyst
    infect(I, I.E(0.5, 0.5, 0.42, 0.42))
    I.add(I.E(0.5, 0.5, 0.42, 0.42), "#d8a8c0", gloss=1.2, shin=34, op=0.45)
    for (cx, cy, a) in ((0.38, 0.38, 0.6), (0.62, 0.45, -0.5), (0.45, 0.66, 1.8), (0.66, 0.68, 0.2)):
        pts = [(cx + math.cos(a + t) * 0.12, cy + math.sin(a + t) * 0.12) for t in np.linspace(-1.2, 1.2, 10)]
        I.add(I.T(pts, [0.02 + 0.03 * math.sin((k / 9) * pi) for k in range(10)]), "#a83a6a", mode="on", gloss=1.0, shin=30)
        I.paint(I.E(*pts[5], 0.02, 0.02), "#3a0a20", amt=0.8)


@icon("botfly_larva", 1, 1)
def botfly_larva(I):            # a fat banded maggot ringed with dark hooks
    pts = [(0.25 + t * 0.5, 0.65 - math.sin(t * pi) * 0.2) for t in np.linspace(0, 1, 12)]
    rs = [0.12 + 0.12 * math.sin(t * pi) ** 0.7 for t in np.linspace(0, 1, 12)]
    infect(I, I.T(pts, [r * 1.3 for r in rs]))
    I.add(I.T(pts, rs), "#e8dcb8", gloss=1.2, shin=30, mottle=0.12)
    for k, (x, y) in enumerate(pts[1:-1]):
        I.carve(I.E(x, y, 0.012, rs[k + 1] * 0.95), 0.012)
        for j in np.linspace(-0.6, 0.6, 4):
            I.paint(I.E(x + 0.01, y + j * rs[k + 1] * 0.9, 0.012, 0.012), "#3a2010", amt=0.85)
    I.add(I.E(pts[0][0] - 0.02, pts[0][1], 0.05, 0.05), "#5a3a20", mode="max", gloss=1.0)


@icon("lancet_fluke", 1, 1)
def lancet_fluke(I):            # a translucent lancet-shaped fluke with its branching gut
    pts = [(0.5 + math.sin(t * pi) * 0.0, 0.08 + t * 0.84) for t in np.linspace(0, 1, 14)]
    rs = [0.02 + 0.16 * math.sin(t * pi) ** 0.8 * (1 - t * 0.4) for t in np.linspace(0, 1, 14)]
    infect(I, I.T(pts, [r * 1.5 for r in rs]))
    I.add(I.T(pts, rs), "#e8b0a0", gloss=1.3, shin=36, op=0.82)
    I.paint(I.T([(0.5, 0.2), (0.5, 0.85)], 0.012), "#9a3a3a", amt=0.8)
    for y in np.linspace(0.3, 0.75, 6):
        for s in (-1, 1): I.paint(I.T([(0.5, y), (0.5 + s * 0.1, y + 0.05)], 0.008), "#b05050", amt=0.7)
    I.add(I.E(0.5, 0.16, 0.04, 0.04), "#c06060", mode="max", gloss=0.9)


@icon("guinea_worm", 2, 1)
def guinea_worm(I):             # a pale worm curling out of a red, smouldering blister
    infect(I, I.E(0.45, 0.6, 0.38, 0.28), 0.6)
    I.add(I.E(0.45, 0.62, 0.3, 0.2), "#b84a2a", gloss=1.0, shin=24, mottle=0.2)
    I.glow(I.E(0.45, 0.62, 0.22, 0.14), "#ff8030", 0.8)
    pts = [(0.45 + t * 1.35, 0.55 - math.sin(t * pi * 1.5) * 0.25) for t in np.linspace(0, 1, 30)]
    I.add(I.T(pts, 0.04), "#f0e8d0", mode="on", gloss=1.2, shin=30)
    I.paint(I.T(pts[3:], 0.01), "#c8b890", amt=0.5)


def build(only=None):
    out = ["-- Parasite item icons (generated by tools/make_parasite_icons.py; edit the generator, not this file).",
           "-- One inventory cell = 28x28 pixels. Item defs use icon = \"icon_<item id>\" by default.",
           "return {"]
    previews = []
    for iid, cols, rows, shape, seed, fn in ICONS:
        if only and iid not in only: continue
        grid, pal = quantize(render_fit(cols, rows, shape, seed, fn))
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


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "--preview":
        _, prev = build(set(args[2:]) or None)
        base.preview(args[1], prev)
        print("preview", len(prev))
    else:
        lines, prev = build()
        open("content/sprites/parasites.lua", "w").write("\n".join(lines) + "\n")
        print("wrote", len(prev))
