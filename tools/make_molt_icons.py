# Icons for molted items (content/molts) -> content/sprites/molts.lua.
#   python3 tools/make_molt_icons.py                 (needs numpy)
#   python3 tools/make_molt_icons.py --preview out.png [ids...]
# A molted item is grown from the items that molted into it, so most icons redraw an ingredient
# icon from tools/make_item_icons.py (`draw`, optionally shifted / scaled), recolour it (`tint`)
# and add what is new, plus the fresh-moult sheen every molted item has (`sheen`).
# Kept apart from items.lua so new items and new molts don't touch the same generated file.
import math, sys
import numpy as np
import make_item_icons as base
from icon_render import Icon, quantize, rgb, render_fit
from make_item_icons import hairs, in_ell, leg, speck

FNS = {iid: fn for iid, _, _, _, _, fn in base.ICONS}
ICONS = []


def icon(iid, cols, rows, shape=None, seed=1):
    def deco(fn):
        ICONS.append((iid, cols, rows, shape, seed, fn))
        return fn
    return deco


def draw(I, iid, ox=0.0, oy=0.0, s=1.0):
    """Draw an ingredient's icon into this one, moved by (ox, oy) cells and scaled by s."""
    X, Y = I.X, I.Y
    I.X, I.Y = (X - ox) / s, (Y - oy) / s
    saved = I._noise
    I._noise = {}
    try:
        FNS[iid](I)
    finally:
        I.X, I.Y = X, Y
        I._noise = saved


def tint(I, col, amt=0.8, keep=1.0):
    """Recolour everything drawn so far toward col, keeping its light and dark."""
    c = rgb(col)
    lum = I.alb.mean(axis=2, keepdims=True)
    new = np.clip(lum / max(0.05, c.mean()) * c * keep, 0, 1)
    m = I.cov[..., None]
    I.alb = np.where(m, I.alb * (1 - amt) + new * amt, I.alb)


def sheen(I, x0, y0, x1, y1, col="#7ff0d8", amt=0.45):
    """The fresh-moult shimmer: a soft iridescent streak and a faint inner glow."""
    I.paint(I.T([(x0, y0), (x1, y1)], 0.09), "#d8fff4", amt=amt * 0.6, soft=1)
    I.glow(I.T([(x0, y0), (x1, y1)], 0.06), col, amt * 0.35)


@icon("magma_gland", 2, 1)
def magma_gland(I):             # the bombardier's twin reservoirs, now molten through
    draw(I, "bombardier_gland")
    tint(I, "#7a1a08", 0.7)
    for pts in ([(0.25, 0.4), (0.6, 0.55), (0.95, 0.45)], [(1.1, 0.5), (1.45, 0.62), (1.8, 0.48)], [(0.5, 0.7), (1.0, 0.6), (1.5, 0.72)]):
        I.paint(I.T(pts, 0.02), "#ffd060", amt=0.95)
        I.glow(I.T(pts, 0.03), "#ff7a20", 1.0)
    I.glow(I.E(1.0, 0.55, 0.7, 0.3), "#5a1400", 0.8)
    sheen(I, 0.3, 0.25, 1.6, 0.25, "#ffb060")


@icon("storm_antenna", 1, 2)
def storm_antenna(I):           # the static antenna, tipped with a crackling crystal
    draw(I, "static_antenna")
    tint(I, "#3a4a6a", 0.5)
    I.add(I.E(0.82, 0.2, 0.12, 0.17, rot=0.5), "#c8d8ff", mode="on", gloss=1.8, shin=50, op=0.85, emit="#5070c0")
    for pts in ([(0.82, 0.1), (0.6, 0.25), (0.75, 0.42), (0.5, 0.6)], [(0.9, 0.3), (0.95, 0.6), (0.8, 0.85)], [(0.3, 1.0), (0.18, 1.3), (0.32, 1.5)]):
        I.add(I.T(pts, 0.012), "#e0ecff", emit="#a0c0ff", gloss=0, mode="on")
    sheen(I, 0.4, 1.7, 0.6, 0.9, "#a0c8ff")


@icon("widow_fang", 2, 2, ["X.", "XX"])
def widow_fang(I):              # a hornet's sting gone black-widow: glossy black, red hourglass
    draw(I, "hornet_stinger")
    tint(I, "#16121a", 0.85)
    hour = lambda X, Y: ((np.abs(X - 0.78) < 0.03 + np.abs(Y - 1.42) * 0.9) & (np.abs(Y - 1.42) < 0.22), np.full(X.shape, 0.02))
    I.paint(I.F(hour), "#d02018", amt=0.95)
    I.glow(I.F(hour), "#5a0808", 0.6)
    I.add(I.E(0.51, 0.12, 0.05, 0.05), "#80ff60", mode="on", gloss=1.4, emit="#40a020", op=0.9)
    sheen(I, 0.3, 1.2, 1.2, 1.25, "#c0a0ff")


@icon("nectar_pearl", 1, 1)
def nectar_pearl(I):            # a pearl of set nectar, golden and milky, with a dew-bright heart
    I.add(I.E(0.5, 0.54, 0.34, 0.34), "#e8c878", gloss=1.8, shin=60, mottle=0.06, op=0.95)
    I.paint(I.E(0.56, 0.64, 0.22, 0.2), "#ffe8a8", amt=0.6, soft=1)
    I.glow(I.E(0.5, 0.56, 0.16, 0.16), "#5a4010", 1)
    I.paint(I.E(0.4, 0.42, 0.14, 0.08, rot=-0.6), "#b8f0ff", amt=0.4, soft=1)
    I.add(I.E(0.38, 0.38, 0.06, 0.04, rot=-0.6), "#ffffff", mode="on", gloss=1, emit="#e0f0ff")
    sheen(I, 0.3, 0.7, 0.7, 0.3)


@icon("goliath_carapace", 2, 2)
def goliath_carapace(I):        # the wing case, hardened to a goliath beetle's banded armour
    draw(I, "chitin_plate")
    tint(I, "#1c3a30", 0.75)
    for k in range(4):
        y = 0.5 + k * 0.32
        I.paint(I.T([(0.4, y), (1.0, y + 0.2), (1.6, y + 0.45)], 0.05), "#d8d0b0", amt=0.5)
    I.set(I.E(1.0, 1.0, 0.9, 0.9), gloss=1.6, shin=44)
    sheen(I, 0.5, 0.35, 1.5, 1.35, "#60ffc0")


@icon("locust_wings", 1, 3)
def locust_wings(I):            # the hopper's leg under a long, veined locust wing
    draw(I, "grasshopper_legs")
    tint(I, "#6a5a22", 0.4)
    wing = [(0.5, 0.12), (0.78, 0.4), (0.82, 1.4), (0.7, 2.6), (0.55, 2.85), (0.4, 2.5), (0.32, 1.3), (0.36, 0.4)]
    I.add(I.P(wing, bevel=0.06, z=0.03), "#c8c098", base=0.25, gloss=1.2, shin=40, op=0.55)
    for t in np.linspace(0.2, 0.8, 4):
        I.paint(I.T([(0.5, 0.2), (0.32 + t * 0.5, 2.6)], 0.008), "#5a4a20", amt=0.6)
    speck(I, 20, (lambda x, y: True, (0.35, 0.4, 0.8, 2.6)), "#4a3a18", seed=5, size=(0.015, 0.03), amt=0.5)
    sheen(I, 0.45, 0.4, 0.6, 2.4)


@icon("hivemind_spore", 1, 3)
def hivemind_spore(I):          # the cordyceps club, laced with white mycelium and glowing pores
    draw(I, "cordyceps")
    for pts in ([(0.2, 2.9), (0.4, 2.3), (0.3, 1.7), (0.5, 1.1)], [(0.8, 2.9), (0.62, 2.2), (0.72, 1.5)]):
        I.add(I.T(pts, 0.022), "#ece4d0", mode="on", gloss=0.2, mottle=0.1)
    for i in range(9):
        y = 0.25 + i * 0.13
        I.add(I.E(0.5 + math.sin(i * 2.1) * 0.12, y, 0.03, 0.03), "#d0a0ff", mode="on", emit="#7040c0", gloss=0.6)
    sheen(I, 0.4, 0.2, 0.55, 1.2, "#d0a0ff")


@icon("obsidian_mandible", 1, 2)
def obsidian_mandible(I):       # the glass jaw, black as volcanic glass, a violet edge
    draw(I, "glass_mandible")
    tint(I, "#141020", 0.9, keep=0.35)
    I.set(I.E(0.5, 1.0, 0.6, 1.0), gloss=2.0, shin=70)
    I.paint(I.T([(0.3, 1.8), (0.32, 1.2), (0.5, 0.65), (0.8, 0.2)], 0.025), "#a080ff", amt=0.7)
    I.glow(I.T([(0.3, 1.8), (0.32, 1.2), (0.5, 0.65), (0.8, 0.2)], 0.02), "#4020a0", 0.8)
    speck(I, 12, (lambda x, y: True, (0.3, 0.3, 0.7, 1.8)), "#e0e8ff", seed=4, size=(0.008, 0.012))


@icon("firefly_halo", 1, 1)
def firefly_halo(I):            # a little lantern with a ring of glowing fireflies round it
    I.add(I.E(0.5, 0.5, 0.15, 0.17), "#3a2a1e", gloss=0.6, shin=24)
    I.add(I.E(0.5, 0.6, 0.13, 0.12), "#e8e070", gloss=0.5, emit="#c0b030")
    I.glow(I.E(0.5, 0.6, 0.12, 0.11), "#ffe860", 1)
    for k in range(6):
        a = k / 6 * math.pi * 2 + 0.3
        x, y = 0.5 + math.cos(a) * 0.34, 0.5 + math.sin(a) * 0.3
        I.add(I.E(x, y, 0.06, 0.045, rot=a), "#2a2018", gloss=0.5)
        I.add(I.E(x + math.cos(a) * 0.04, y + math.sin(a) * 0.035, 0.035, 0.03), "#fff090", mode="on", emit="#ffe040")
    sheen(I, 0.3, 0.4, 0.7, 0.4, "#fff0a0", 0.3)


@icon("eternal_exuvia", 2, 2)
def eternal_exuvia(I):          # the cicada's shed skin, pale and pearly, a tardigrade curled inside
    draw(I, "cicada_shell")
    tint(I, "#c0d8c8", 0.6)
    I.set(I.E(1.0, 1.0, 0.9, 0.9), op=0.78)
    I.add(I.E(1.0, 1.25, 0.2, 0.14), "#e0c8a8", mode="on", gloss=0.4, mottle=0.2, op=0.9)
    for k in range(4):
        I.carve(I.T([(0.86 + k * 0.09, 1.14), (0.86 + k * 0.09, 1.36)], 0.01), 0.02)
    I.glow(I.E(1.0, 1.0, 0.4, 0.6), "#204838", 0.7)
    sheen(I, 0.75, 0.45, 1.25, 1.6, "#7ff0d8", 0.6)


@icon("devouring_bloom", 3, 2, ["X.X", "XXX"])
def devouring_bloom(I):         # the flytrap's jaws, now trailing yellow slime-mould veins
    draw(I, "venus_flytrap")
    for pts in ([(0.5, 1.3), (0.9, 1.55), (1.5, 1.4), (2.1, 1.55), (2.5, 1.3)], [(1.5, 1.4), (1.3, 1.8), (1.0, 1.9)], [(1.5, 1.4), (1.8, 1.85), (2.3, 1.9)]):
        I.add(I.T(pts, 0.03), "#e8c020", mode="on", gloss=0.6, emit="#604000")
    for cx in (0.5, 2.5):
        I.glow(I.E(cx, 0.8, 0.2, 0.4), "#5a1010", 0.6)
    sheen(I, 0.3, 0.3, 0.7, 1.0, "#c0ff80", 0.35)


@icon("bramble_hide", 1, 2)
def bramble_hide(I):            # a strip of bark bristling with rose thorns and cactus spines
    I.add(I.P([(0.25, 0.1), (0.75, 0.12), (0.8, 1.88), (0.22, 1.9)], bevel=0.12, z=0.12), "#4a3424", gloss=0.2, mottle=0.25, grain=0.03)
    for y in np.linspace(0.3, 1.7, 5):
        I.carve(I.T([(0.3, y), (0.72, y + 0.05)], 0.012), 0.03)
    for k, (x, y, s) in enumerate([(0.3, 0.3, -1), (0.72, 0.6, 1), (0.28, 1.0, -1), (0.7, 1.35, 1), (0.32, 1.7, -1)]):
        I.add(I.T([(x, y), (x + s * 0.2, y - 0.08)], [0.06, 0.006]), "#a83a2a", mode="on", gloss=0.9, shin=30)
    for k in range(10):
        x, y = 0.4 + (k % 3) * 0.1, 0.25 + k * 0.15
        I.add(I.T([(x, y), (x + 0.12, y - 0.1)], [0.012, 0.003]), "#e8e0b0", mode="on", gloss=0.4)
    I.paint(I.E(0.5, 1.0, 0.2, 0.7), "#3a6a2a", amt=0.35, soft=1)
    sheen(I, 0.35, 0.2, 0.6, 1.8, "#a0ff90", 0.35)


@icon("queens_comb", 2, 2)
def queens_comb(I):             # the queen cell overflowing, golden comb glowing with jelly
    draw(I, "royal_jelly")
    tint(I, "#e8b030", 0.4)
    I.glow(I.E(1.0, 1.0, 0.55, 0.5), "#806010", 0.9)
    for (x, y) in ((0.3, 0.3), (1.7, 0.3), (0.3, 1.7), (1.7, 1.7)):
        I.add(I.E(x, y, 0.12, 0.1), "#ffe070", mode="on", gloss=1.5, shin=40, emit="#604000")
    sheen(I, 0.5, 0.5, 1.5, 0.5, "#fff0a0", 0.5)


def build(only=None):
    out = ["-- Molted item icons (generated by tools/make_molt_icons.py; edit the generator, not this file).",
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
        open("content/sprites/molts.lua", "w").write("\n".join(lines) + "\n")
        print("wrote", len(prev))
