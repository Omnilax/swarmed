# A tiny software renderer for item icons (used by tools/make_item_icons.py).
#
# Icons are built from lit 3D primitives instead of flat pixel shapes: every shape writes a
# height field and a material (colour, gloss, mottling, surface grain), then the whole icon is
# lit by a warm key light from the top-left and a cool dusk ambient, with cavity shading, a
# tinted dark rim (no flat black outline) and a soft drop shadow. It renders at 2x and averages
# down, then each icon is reduced to a palette of up to ~48 colours for content/sprites/items.lua.
#
# Coordinates are in CELLS (1.0 = one inventory cell), so icons don't care about RES.
import math
import numpy as np

RES = 28          # pixels per inventory cell in the final sprite
SS = 2            # supersampling
LIGHT = np.array([-0.55, -0.68, 0.72]); LIGHT = LIGHT / np.linalg.norm(LIGHT)
HALF = LIGHT + np.array([0, 0, 1.0]); HALF = HALF / np.linalg.norm(HALF)
KEY = np.array([1.1, 0.96, 0.78])          # warm low sun
AMB = np.array([0.30, 0.31, 0.42])         # cool dusk sky
BOUNCE = np.array([0.16, 0.11, 0.07])      # warm light off the dirt, from below
CHARS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!#$%&()*+,-/:;<=>?@[]^_`{|}~"


def rgb(hexs):
    hexs = hexs.lstrip('#')
    return np.array([int(hexs[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


class Field:
    """Where a primitive is (mask) and how it bulges (prof, in cells)."""
    def __init__(self, mask, prof):
        self.mask, self.prof = mask, prof


class Icon:
    def __init__(self, cols, rows, shape=None, seed=1):
        self.cols, self.rows, self.seed = cols, rows, seed
        self.shape = shape or ["X" * cols] * rows
        k = RES * SS
        self.k = k
        H, W = rows * k, cols * k
        yy, xx = np.mgrid[0:H, 0:W]
        self.X, self.Y = (xx + 0.5) / k, (yy + 0.5) / k
        self.h = np.zeros((H, W))
        self.cov = np.zeros((H, W), bool)
        self.alb = np.zeros((H, W, 3))
        self.gloss = np.zeros((H, W))
        self.shin = np.full((H, W), 12.0)
        self.op = np.ones((H, W))
        self.emit = np.zeros((H, W, 3))
        self._noise = {}
        self._n = 0

    # ---- noise --------------------------------------------------------------------------
    def noise(self, scale, seed=0):
        """Smooth value noise in 0..1 with features about `scale` cells across."""
        key = (scale, seed)
        if key in self._noise: return self._noise[key]
        rng = np.random.default_rng(self.seed * 7919 + seed * 104729 + int(scale * 1000))
        gw, gh = int(self.cols / scale) + 3, int(self.rows / scale) + 3
        grid = rng.random((gh, gw))
        fx, fy = self.X / scale, self.Y / scale
        x0, y0 = np.floor(fx).astype(int), np.floor(fy).astype(int)
        tx, ty = smooth(fx - x0), smooth(fy - y0)
        a, b = grid[y0, x0], grid[y0, x0 + 1]
        c, d = grid[y0 + 1, x0], grid[y0 + 1, x0 + 1]
        n = (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty
        self._noise[key] = n
        return n

    def fbm(self, scale, seed=0, octaves=3):
        n, amp, tot = 0, 1.0, 0
        for o in range(octaves):
            n = n + self.noise(scale / (2 ** o), seed + o * 31) * amp
            tot += amp; amp *= 0.5
        return n / tot

    # ---- fields -------------------------------------------------------------------------
    def E(self, cx, cy, rx, ry, rot=0.0, z=1.0, flat=0.0):
        """Ellipsoid (rot in radians). z scales the bulge; flat>0 flattens the top."""
        c, s = math.cos(rot), math.sin(rot)
        px, py = self.X - cx, self.Y - cy
        dx, dy = (px * c + py * s) / rx, (-px * s + py * c) / ry
        d2 = dx * dx + dy * dy
        m = d2 <= 1
        prof = np.sqrt(np.clip(1 - d2, 0, 1))
        if flat: prof = np.minimum(prof, 1 - flat) / (1 - flat)
        return Field(m, prof * min(rx, ry) * z)

    def T(self, pts, r, z=1.0):
        """Tube along a polyline. r: radius, or a list with one radius per point."""
        rs = r if isinstance(r, (list, tuple)) else [r] * len(pts)
        best = np.full(self.X.shape, -1.0)
        for (x0, y0), (x1, y1), r0, r1 in zip(pts, pts[1:], rs, rs[1:]):
            vx, vy = x1 - x0, y1 - y0
            l2 = vx * vx + vy * vy + 1e-9
            t = np.clip(((self.X - x0) * vx + (self.Y - y0) * vy) / l2, 0, 1)
            dx, dy = self.X - (x0 + vx * t), self.Y - (y0 + vy * t)
            d = np.sqrt(dx * dx + dy * dy)
            rr = r0 + (r1 - r0) * t
            hgt = np.where(d < rr, np.sqrt(np.clip(rr * rr - d * d, 0, None)), -1)
            best = np.maximum(best, hgt)
        return Field(best >= 0, np.clip(best, 0, None) * z)

    def P(self, pts, bevel=0.08, z=0.08):
        """Flat slab inside a polygon with bevelled edges (leaves, wings, plates)."""
        X, Y = self.X, self.Y
        inside = np.zeros(X.shape, bool)
        dist = np.full(X.shape, 1e9)
        n = len(pts)
        for i in range(n):
            (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % n]
            cond = ((y0 > Y) != (y1 > Y)) & (X < (x1 - x0) * (Y - y0) / ((y1 - y0) or 1e-9) + x0)
            inside ^= cond
            vx, vy = x1 - x0, y1 - y0
            l2 = vx * vx + vy * vy + 1e-9
            t = np.clip(((X - x0) * vx + (Y - y0) * vy) / l2, 0, 1)
            dist = np.minimum(dist, np.hypot(X - (x0 + vx * t), Y - (y0 + vy * t)))
        prof = z * np.sqrt(smooth(dist / bevel))
        return Field(inside, prof)

    def F(self, fn):
        """Any field from fn(X, Y) -> (mask, prof)."""
        m, p = fn(self.X, self.Y)
        return Field(m, p)

    # ---- drawing ------------------------------------------------------------------------
    def add(self, f, col, base=0.0, mode="over", gloss=0.15, shin=12, mottle=0.12, mscale=0.15,
            grain=0.004, gscale=0.035, op=1.0, emit=None, clipto=None):
        """Put a primitive down. mode 'over' paints on top, 'max' merges with what's there
        (only where it is higher), 'on' sits on top of what's under it (adds height)."""
        self._n += 1
        m = f.mask.copy()
        if clipto is not None: m &= clipto
        under = np.where(self.cov, self.h, 0)
        if mode == "on": hgt = under + f.prof + base
        else: hgt = base + f.prof
        if grain: hgt = hgt + (self.noise(gscale, self._n) - 0.5) * grain * 2
        if mode == "max": m &= (~self.cov) | (hgt > self.h)
        c = np.array(rgb(col) if isinstance(col, str) else col, float)
        var = 1 + (self.fbm(mscale, self._n + 500) - 0.5) * 2 * mottle
        self.h[m] = hgt[m]
        self.alb[m] = (c[None, :] * var[m][:, None])
        self.gloss[m], self.shin[m], self.op[m] = gloss, shin, op
        self.emit[m] = 0
        if emit is not None: self.emit[m] = rgb(emit) if isinstance(emit, str) else emit
        self.cov |= m
        return m

    def paint(self, f, col, amt=1.0, soft=0.0, only=None):
        """Recolour where a field lies (no height change). soft fades it out toward its edge."""
        m = f.mask & self.cov
        if only is not None: m &= only
        c = np.array(rgb(col) if isinstance(col, str) else col, float)
        w = np.full(self.X.shape, amt)
        if soft:
            pm = f.prof.max() or 1
            w = amt * smooth(f.prof / (pm * soft))
        w = np.where(m, w, 0)[..., None]
        self.alb = self.alb * (1 - w) + c[None, None, :] * w

    def carve(self, f, depth, only=None):
        """Press a groove or dent into the surface (depth in cells)."""
        m = f.mask & self.cov
        if only is not None: m &= only
        pm = f.prof.max() or 1
        self.h = np.where(m, self.h - depth * (f.prof / pm), self.h)

    def raise_(self, f, amount):
        m = f.mask & self.cov
        pm = f.prof.max() or 1
        self.h = np.where(m, self.h + amount * (f.prof / pm), self.h)

    def glow(self, f, col, amt=1.0):
        m = f.mask & self.cov
        pm = f.prof.max() or 1
        w = (amt * f.prof / pm)[..., None] * m[..., None]
        self.emit = self.emit + w * rgb(col)[None, None, :]

    def set(self, f, **mat):
        m = f.mask & self.cov
        for k, v in mat.items(): getattr(self, k)[m] = v

    # ---- lighting -----------------------------------------------------------------------
    def render(self):
        k = self.k
        h = np.where(self.cov, self.h, 0.0)
        gy, gx = np.gradient(h)
        sx, sy = np.clip(gx * k, -4, 4), np.clip(gy * k, -4, 4)
        nz = 1 / np.sqrt(sx * sx + sy * sy + 1)
        nx, ny = -sx * nz, -sy * nz
        ndl = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
        diff = np.clip((ndl + 0.15) / 1.15, 0, 1)
        # self shadowing: march toward the light; anything higher on the way blocks it
        shadow = np.ones_like(h)
        step = np.array([-LIGHT[0], -LIGHT[1]]) / math.hypot(LIGHT[0], LIGHT[1])
        rise = LIGHT[2] / math.hypot(LIGHT[0], LIGHT[1]) / k
        for i in range(2, int(0.35 * k), 2):
            ox, oy = int(round(-step[0] * i)), int(round(-step[1] * i))
            sh = np.roll(np.roll(h, oy, 0), ox, 1)
            blocked = sh > h + rise * i * 1.0 + 0.004
            shadow = np.where(blocked & self.cov, np.minimum(shadow, 0.35 + 0.65 * (i / (0.35 * k))), shadow)
        # cavities (creases between parts, grooves) get darker
        blur = h.copy()
        for _ in range(3):
            blur = (blur + np.roll(blur, 2, 0) + np.roll(blur, -2, 0) + np.roll(blur, 2, 1) + np.roll(blur, -2, 1)) / 5
        ao = 1 - np.clip((blur - h) * 9, 0, 0.55)
        spec = self.gloss * np.clip(nx * HALF[0] + ny * HALF[1] + nz * HALF[2], 0, 1) ** self.shin
        rim = np.clip(1 - nz, 0, 1) ** 2 * np.clip(-ndl + 0.2, 0, 1) * 0.35
        up = np.clip(-ny, 0, 1) * 0  # (kept for tuning)
        bounce = np.clip(ny, 0, 1) * 0.8
        light = AMB[None, None, :] * ao[..., None] + KEY[None, None, :] * (diff * shadow)[..., None] \
            + BOUNCE[None, None, :] * bounce[..., None] + np.array([0.25, 0.3, 0.45])[None, None, :] * rim[..., None]
        col = self.alb * light + (spec * shadow)[..., None] * KEY[None, None, :] * 1.3 + self.emit
        # grade: soft shoulder, a touch less saturated, deeper blacks
        col = col / (1 + 0.22 * col) * 1.12
        lum = (col * np.array([0.3, 0.55, 0.15])).sum(-1, keepdims=True)
        col = lum + (col - lum) * 0.88
        col = np.clip(col, 0, 1) ** 1.08
        # downsample
        H, W = h.shape
        r, c = H // SS, W // SS
        cov = self.cov.reshape(r, SS, c, SS).mean((1, 3))
        cw = self.cov[..., None].astype(float)
        csum = (col * cw).reshape(r, SS, c, SS, 3).sum((1, 3))
        out = csum / np.maximum(cov[..., None] * SS * SS, 1e-6)
        op = (self.op * self.cov).reshape(r, SS, c, SS).sum((1, 3)) / np.maximum(cov * SS * SS, 1e-6)
        alpha = cov >= 0.5
        hs = h.reshape(r, SS, c, SS).mean((1, 3))
        return self._finish(out, alpha, op)

    def _finish(self, col, alpha, op):
        rows, cols = alpha.shape
        # cells the item really covers, 1px in from any edge with no neighbour cell
        allowed = np.zeros_like(alpha)
        for cy, row in enumerate(self.shape):
            for cx, ch in enumerate(row):
                if ch == 'X': allowed[cy * RES:(cy + 1) * RES, cx * RES:(cx + 1) * RES] = True
        inner = allowed.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.zeros_like(allowed)
            ys, yd = (slice(max(dy, 0), rows + min(dy, 0)), slice(max(-dy, 0), rows + min(-dy, 0)))
            xs, xd = (slice(max(dx, 0), cols + min(dx, 0)), slice(max(-dx, 0), cols + min(-dx, 0)))
            sh[yd, xd] = allowed[ys, xs]
            inner &= sh
        alpha &= inner
        # tinted rim: empty pixels next to the item take a dark version of its colour
        rim = np.zeros_like(alpha)
        rimcol = np.zeros(col.shape)
        for dy, dx, k in ((0, 1, 0.42), (1, 0, 0.42), (0, -1, 0.26), (-1, 0, 0.26)):
            nb = np.roll(np.roll(alpha, dy, 0), dx, 1)
            nc = np.roll(np.roll(col, dy, 0), dx, 1)
            new = nb & ~alpha & ~rim & allowed
            rimcol[new] = nc[new] * k + np.array([0.02, 0.015, 0.03])
            rim |= new
        # drop shadow down-right of the item
        body = alpha | rim
        shadow = np.zeros_like(alpha)
        for dy, dx in ((1, 1), (2, 1), (2, 2), (3, 2)):
            shadow |= np.roll(np.roll(body, dy, 0), dx, 1)
        shadow &= ~body & allowed
        return dict(col=col, alpha=alpha, op=op, rim=rim, rimcol=rimcol, shadow=shadow)


def quantize(img, maxc=46):
    """Reduce an icon to a small palette -> (rows of chars, {char: '#rrggbb[aa]'})."""
    col, alpha, op, rim, rimcol, shadow = img['col'], img['alpha'], img['op'], img['rim'], img['rimcol'], img['shadow']
    rows, cols = alpha.shape
    px = np.concatenate([col[alpha], rimcol[rim]])
    if len(px) == 0: return ["." * cols] * rows, {}
    k = min(maxc, len(np.unique((px * 255).astype(int), axis=0)))
    lum = px @ np.array([0.3, 0.55, 0.15])
    order = np.argsort(lum)
    cent = px[order[np.linspace(0, len(px) - 1, k).astype(int)]].copy()
    for _ in range(12):
        d = ((px[:, None, :] - cent[None, :, :]) ** 2).sum(-1)
        lab = d.argmin(1)
        for i in range(k):
            sel = px[lab == i]
            if len(sel): cent[i] = sel.mean(0)
    def nearest(c):
        return ((c[:, None, :] - cent[None, :, :]) ** 2).sum(-1).argmin(1)
    grid = np.full((rows, cols), -1)
    lab_body = nearest(col[alpha])
    aq = np.clip(np.round(op[alpha] * 4) / 4, 0.25, 1)
    keys = {}
    pal = {}
    def key_for(ci, a):
        kk = (int(ci), float(a))
        if kk not in keys:
            ch = CHARS[len(keys)]
            keys[kk] = ch
            r, g, b = (np.clip(cent[ci], 0, 1) * 255).round().astype(int)
            pal[ch] = f"#{r:02x}{g:02x}{b:02x}" + ("" if a >= 1 else f"{int(a * 255):02x}")
        return keys[kk]
    out = [["."] * cols for _ in range(rows)]
    ys, xs = np.nonzero(alpha)
    for (y, x, ci, a) in zip(ys, xs, lab_body, aq): out[y][x] = key_for(ci, a)
    ys, xs = np.nonzero(rim)
    for (y, x, ci) in zip(ys, xs, nearest(rimcol[rim])): out[y][x] = key_for(ci, 1.0)
    ys, xs = np.nonzero(shadow)
    if len(ys):
        ch = CHARS[len(keys)]; keys['shadow'] = ch; pal[ch] = "#0a060c55"
        for y, x in zip(ys, xs): out[y][x] = ch
    assert len(keys) <= len(CHARS), "too many colours"
    return ["".join(r) for r in out], pal
