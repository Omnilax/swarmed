# Builds every icon size from the two paintings `love . --makeicon` saves (src/debug/iconmaker.lua):
#   love . --makeicon
#   cp "<save folder>/icon/icon_128.png" "<save folder>/icon/icon_32.png" assets/icon/
#   python3 tools/make_icons.py
# Big sizes are the 128 painting blown up with crisp pixels; small ones come from the 32 close-up.
# Writes assets/icon/icon_<size>.png, swarmed.ico (Windows shortcuts / .exe) and swarmed.icns (macOS).
import os
from PIL import Image

HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "icon")
big = Image.open(os.path.join(HERE, "icon_128.png")).convert("RGBA")
small = Image.open(os.path.join(HERE, "icon_32.png")).convert("RGBA")


def size(n):
    if n >= 128:
        return big.resize((n, n), Image.NEAREST)
    if n > 32:
        return big.resize((n, n), Image.LANCZOS)
    if n == 32:
        return small.copy()
    return small.resize((n, n), Image.LANCZOS)


imgs = {n: size(n) for n in (16, 24, 32, 48, 64, 128, 256, 512, 1024)}
for n in (16, 48, 64, 256, 512):
    imgs[n].save(os.path.join(HERE, "icon_%d.png" % n), optimize=True)
imgs[256].save(os.path.join(HERE, "swarmed.ico"), sizes=[(n, n) for n in (16, 24, 32, 48, 64, 128, 256)],
               append_images=[imgs[n] for n in (16, 24, 32, 48, 64, 128)])
imgs[1024].save(os.path.join(HERE, "swarmed.icns"))
print("icons written to", os.path.normpath(HERE))
