# python3 tools/tone_palette.py : tones down the few sprites whose colours were far louder than
# the rest of the cast (art pass 2026-11-17), so every bug sits in the same dusky, shaded look.
# Edits the generated content/sprites/*.lua palettes and the matching generator script lines in
# place, so a later regeneration keeps the toned colours. Safe to run twice (it records nothing,
# so only run it again if you regenerate a sprite from an old palette).
import colorsys, re, sys

# (sprite file, generator, sprite id, saturation x, value x)
TARGETS = [
    ("content/sprites/bugs.lua", "tools/make_bug_sprites.py", "lobster", 0.74, 0.9),
    ("content/sprites/bugs.lua", "tools/make_bug_sprites.py", "centipede", 0.82, 0.92),
    ("content/sprites/batch1.lua", "tools/make_batch1_sprites.py", "crab", 0.74, 0.88),
    ("content/sprites/batch2.lua", "tools/make_batch2_sprites.py", "mantis_shrimp", 0.84, 0.9),
    ("content/sprites/batch2.lua", "tools/make_batch2_sprites.py", "pistol_shrimp", 0.84, 0.92),
]
KEEP = {"o", "e"}      # outline and eyes stay as they are

def tone(h, ks, kv):
    c = h[1:7]
    r, g, b = (int(c[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hh, s, v = colorsys.rgb_to_hsv(r, g, b)
    r, g, b = colorsys.hsv_to_rgb(hh, s * ks, v * kv)
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255)) + h[7:]

for spr, gen, sid, ks, kv in TARGETS:
    src = open(spr).read()
    mapping = {}
    def fix_pal(m):
        pal = m.group(0)
        def one(e):
            k, h = e.group(1), e.group(2)
            if k in KEEP: return e.group(0)
            new = tone(h, ks, kv)
            mapping[h[:7].lower()] = new[:7]
            return '["%s"] = "%s"' % (k, new)
        return re.sub(r'\["(.)"\] = "(#[0-9a-fA-F]{6,8})"', one, pal)
    # every sprite whose id is sid or sid_<part>
    out, n = [], 0
    pos = 0
    for m in re.finditer(r'id = "(%s(?:_[a-z0-9]+)?)"' % sid, src):
        if m.group(1) != sid and not m.group(1).startswith(sid + "_"): continue
        p = src.index("palette = {", m.end())
        q = src.index("}", p) + 1
        out.append(src[pos:p]); out.append(fix_pal(re.match(r'.*', src[p:q], re.S))); pos = q; n += 1
    out.append(src[pos:])
    open(spr, "w").write("".join(out))
    # the generator's palette line for this bug
    g = open(gen).read()
    lines = g.split("\n")
    for i, line in enumerate(lines):
        if line.strip().startswith('("%s",' % sid):
            j = i
            while True:
                for old, new in mapping.items():
                    lines[j] = re.sub(old, new, lines[j], flags=re.I)
                if lines[j].rstrip().endswith("),") or j > i + 4: break
                j += 1
    open(gen, "w").write("\n".join(lines))
    print("%s: %d sprites, %d colours toned" % (sid, n, len(mapping)))
