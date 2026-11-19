-- Paint: small pictures painted in Lua at runtime in the game's one art style, for things that
-- are not in the sprite atlas (props, the antlion, map gambles). Same rules as the bug sprites
-- (tools/make_bug_sprites.py) and the painted stage hazards: lit shapes with a few hard colour
-- steps (a 4-5 colour ramp per material), light from the upper left, a speck of noise so big
-- areas aren't flat, a soft dark outline, then hand-placed detail. Pictures are 1 picture pixel
-- per world pixel, so they sit on the same pixel grid as the bugs.
--
--   local p = Paint.pic(w, h, ox, oy)     a blank picture; (ox, oy) is its origin (feet)
--   p:blob(u, v, ra, rb, ang, ramp, texture, bias)   a lit ellipsoid (u, v from the origin)
--   p:stroke(u1, v1, u2, v2, r0, r1, col)            a tapered line of dabs (stems, legs, hairs)
--   p:set(u, v, col) / p:get(u, v)                   one pixel
--   p:outline(col)                                    soft dark edge round everything painted
--   Paint.get(key, fn)        -> { image, ox, oy, w, h }; fn() returns a Pic, painted once
--   Paint.draw(pic, x, y, r, k, alpha, flash)        draw it with its origin at (x, y)
--   Paint.ramp("#hex", ...)   a ramp (dark .. light) from hex colours; Paint.hex("#hex")
local Paint = { cache = {} }

local sqrt, floor, max, min, abs = math.sqrt, math.floor, math.max, math.min, math.abs
local cos, sin = math.cos, math.sin

local LIGHT = { -0.55, -0.65, 0.55 }
do
    local l = sqrt(LIGHT[1] ^ 2 + LIGHT[2] ^ 2 + LIGHT[3] ^ 2)
    for i = 1, 3 do LIGHT[i] = LIGHT[i] / l end
end
Paint.LIGHT = LIGHT

-- the soft outline every sprite in the game has (dark warm brown, a little see-through)
Paint.OUTLINE = { 0.07, 0.05, 0.04, 0.72 }

function Paint.hex(s, a)
    s = s:gsub("#", "")
    return { tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255, a or 1 }
end

function Paint.ramp(...)
    local r = {}
    for i, h in ipairs({ ... }) do r[i] = type(h) == "string" and Paint.hex(h) or h end
    return r
end

function Paint.mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] or 1 } end
function Paint.shade(c, k) return { min(1, c[1] * k), min(1, c[2] * k), min(1, c[3] * k), c[4] or 1 } end

-- A ramp from one colour: darkest .. lightest around it.
function Paint.rampOf(c, n)
    n = n or 4
    local r = {}
    for i = 1, n do
        local t = (i - 1) / (n - 1)
        local k = 0.45 + t * 0.85
        r[i] = { min(1, c[1] * k + t * t * 0.08), min(1, c[2] * k + t * t * 0.08), min(1, c[3] * k + t * t * 0.08), 1 }
    end
    return r
end

-- Cheap deterministic noise 0..1 for a pixel.
local function hash(x, y, seed)
    local n = sin(x * 12.9898 + y * 78.233 + (seed or 0) * 37.719) * 43758.5453
    return n - floor(n)
end
Paint.hash = hash

local Pic = {}
Pic.__index = Pic

function Paint.pic(w, h, ox, oy)
    return setmetatable({ w = w, h = h, ox = ox or floor(w / 2), oy = oy or h - 1, px = {} }, Pic)
end

function Pic:set(u, v, c)
    local x, y = floor(u + self.ox + 0.5), floor(v + self.oy + 0.5)
    if c and x >= 0 and y >= 0 and x < self.w and y < self.h then self.px[y * self.w + x] = c end
end

function Pic:get(u, v)
    local x, y = floor(u + self.ox + 0.5), floor(v + self.oy + 0.5)
    if x >= 0 and y >= 0 and x < self.w and y < self.h then return self.px[y * self.w + x] end
end

-- Iterate the pixels of a rotated box: fn(u, v, a, b), (a, b) in the shape's own frame.
function Pic:each(cu, cv, ra, rb, ang, fn)
    local c, s = cos(ang), sin(ang)
    local r = sqrt(ra * ra + rb * rb) + 1
    for v = floor(cv - r), floor(cv + r + 1) do
        for u = floor(cu - r), floor(cu + r + 1) do
            local du, dv = u - cu, v - cv
            local a, b = du * c + dv * s, -du * s + dv * c
            if a >= -ra and a <= ra and b >= -rb and b <= rb then fn(u, v, a, b) end
        end
    end
end

-- A lit ellipsoid. ramp: colours dark .. light. texture(u, v, i, a, b) may return a colour to
-- use instead (streaks, markings) given the light level i (0..1). bias brightens (+) or darkens.
function Pic:blob(cu, cv, ra, rb, ang, ramp, texture, bias)
    local n = #ramp
    ang = ang or 0
    local c, s = cos(ang), sin(ang)
    self:each(cu, cv, ra, rb, ang, function(u, v, a, b)
        local da, db = a / ra, b / rb
        local d2 = da * da + db * db
        if d2 > 1 then return end
        local nz = sqrt(1 - d2)
        local nu, nv = da * c - db * s, da * s + db * c
        local i = nu * LIGHT[1] + nv * LIGHT[2] + nz * LIGHT[3] + (bias or 0)
        i = max(0, min(0.999, i * 0.5 + 0.5 + (hash(u, v, 3) - 0.5) * 0.12))
        local col = texture and texture(u, v, i, a, b) or ramp[floor(i * n) + 1]
        if col then self:set(u, v, col) end
    end)
end

-- A line of round dabs: radius r0 -> r1 along the way. col may be a ramp (lit across the line).
function Pic:stroke(u1, v1, u2, v2, r0, r1, col)
    local d = sqrt((u2 - u1) ^ 2 + (v2 - v1) ^ 2)
    local n = max(1, floor(d * 1.5))
    local ramp = type(col[1]) == "table" and col or nil
    for i = 0, n do
        local t = i / n
        local r = r0 + (r1 - r0) * t
        local u, v = u1 + (u2 - u1) * t, v1 + (v2 - v1) * t
        if r <= 0.6 then self:set(u, v, ramp and ramp[#ramp - 1] or col)
        else
            for dv = -r, r do
                for du = -r, r do
                    if du * du + dv * dv <= r * r then
                        local cc = col
                        if ramp then
                            local lit = -(du * LIGHT[1] + dv * LIGHT[2]) / r * 0.5 + 0.5
                            cc = ramp[max(1, min(#ramp, floor((1 - lit) * #ramp) + 1))]
                        end
                        self:set(u + du, v + dv, cc)
                    end
                end
            end
        end
    end
end

-- Darkens what is already painted inside an ellipse (cast shadow of an upper part on a lower).
function Pic:darken(cu, cv, ra, rb, k)
    self:each(cu, cv, ra, rb, 0, function(u, v, a, b)
        if (a / ra) ^ 2 + (b / rb) ^ 2 > 1 then return end
        local c = self:get(u, v)
        if c then self:set(u, v, Paint.shade(c, k)) end
    end)
end

-- A soft outline: empty pixels next to painted ones get a dark edge.
function Pic:outline(col)
    col = col or Paint.OUTLINE
    local w, h, px = self.w, self.h, self.px
    local add = {}
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            if not px[y * w + x] then
                local hit = (x > 0 and px[y * w + x - 1]) or (x < w - 1 and px[y * w + x + 1])
                    or (y > 0 and px[(y - 1) * w + x]) or (y < h - 1 and px[(y + 1) * w + x])
                if hit then add[#add + 1] = y * w + x end
            end
        end
    end
    for _, i in ipairs(add) do px[i] = col end
end

function Pic:image()
    local data = love.image.newImageData(self.w, self.h)
    local w = self.w
    for i, c in pairs(self.px) do data:setPixel(i % w, floor(i / w), c[1], c[2], c[3], c[4] or 1) end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    return { image = img, ox = self.ox, oy = self.oy, w = self.w, h = self.h, data = data }
end

-- A painted picture by key, painted the first time it is asked for.
function Paint.get(key, fn)
    local p = Paint.cache[key]
    if not p then
        p = fn():image()
        Paint.cache[key] = p
    end
    return p
end

-- Draw a painted picture with its origin at (x, y). kx, ky: scale. alpha: a number, or a
-- colour { r, g, b, a } to tint it with.
local flashShader
function Paint.draw(p, x, y, r, kx, ky, alpha, flash)
    local lg = love.graphics
    kx = kx or 1
    ky = ky or kx
    if flash then
        if not flashShader then
            flashShader = lg.newShader([[
                vec4 effect(vec4 col, Image tex, vec2 uv, vec2 sc) {
                    vec4 c = Texel(tex, uv);
                    return vec4(1.0, 1.0, 1.0, c.a) * col;
                }]])
        end
        lg.setShader(flashShader)
    end
    if type(alpha) == "table" then lg.setColor(alpha[1], alpha[2], alpha[3], alpha[4] or 1)
    else lg.setColor(1, 1, 1, alpha or 1) end
    lg.draw(p.image, x, y, r or 0, kx, ky, p.ox + 0.5, p.oy + 0.5)
    if flash then lg.setShader() end
end

return Paint
