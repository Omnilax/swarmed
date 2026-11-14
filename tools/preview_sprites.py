# python3 tools/preview_sprites.py out.png file.lua... : renders sprite frames at 8x for review
import subprocess, sys
from PIL import Image
out, files = sys.argv[1], sys.argv[2:]
bg = (150, 144, 132)
sprites = []
for f in files:
    txt = subprocess.run(["luajit", "tools/dump_sprites.lua", f], capture_output=True, text=True, check=True).stdout
    cur = None
    for line in txt.splitlines():
        if line.startswith("S "): cur = {"id": line[2:], "pal": {}, "frames": []}; sprites.append(cur)
        elif line.startswith("P "): _, k, v = line.split(" "); cur["pal"][k] = v
        elif line == "F": cur["frames"].append([])
        elif line.startswith("R "): cur["frames"][-1].append(line[2:])
S = 8
W = max(sum(max(len(r) for r in fr) + 2 for fr in s["frames"]) for s in sprites) * S
H = sum(max(len(fr) for fr in s["frames"]) + 2 for s in sprites) * S
img = Image.new("RGB", (W, H), bg)
y = 0
for s in sprites:
    x = 0
    for fr in s["frames"]:
        for ry, row in enumerate(fr):
            for rx, ch in enumerate(row):
                if ch == ".": continue
                col = s["pal"].get(ch)
                if col is None: print("bad char", s["id"], repr(ch)); continue
                c = [int(col[i:i+2], 16) for i in (1, 3, 5)]
                a = int(col[7:9], 16) / 255 if len(col) >= 9 else 1
                c = tuple(int(c[i] * a + bg[i] * (1 - a)) for i in range(3))
                for dy in range(S):
                    for dx in range(S):
                        img.putpixel((x + rx * S + dx, y + ry * S + dy), c)
        x += (max(len(r) for r in fr) + 2) * S
    y += (max(len(fr) for fr in s["frames"]) + 2) * S
img.save(out)
