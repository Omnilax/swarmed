-- Painted pictures of the huge non-bug creatures (the sparrow and the giant anteater stage
-- hazards, content/bosses). They are far too big for the sprite atlas, so each is painted once
-- into its own image the first time it is needed, in the same style as the bug sprites
-- (tools/make_bug_sprites.py): lit shapes with a few hard colour steps, light from the upper
-- left, a soft dark outline, then hand-placed detail (feathers, streaks, coarse fur).
--
-- Pictures are top-down and face right (+u), like every sprite. They are drawn projected onto
-- the iso floor (Beasts.drawFlat), turned to a world angle and lifted to a height, so they lie
-- in the world like the stacked player model does instead of standing up like a billboard.
--
--   Beasts.get(id)                   -> { image, ox, oy, w, h } (painted on first use)
--   Beasts.prepare(list)             paint a list of ids now (the director does this when a
--                                    hazard wave starts, so the first frame doesn't hitch)
--   Beasts.drawFlat(id, x, y, z, angle, k, alpha, shadow, kAlong)
--                                    draw lying flat at world (x, y) height z, turned to world
--                                    `angle`, k world units per picture pixel. shadow = true
--                                    draws a black silhouette (alpha) instead. kAlong stretches
--                                    it along its length only (a reaching foreleg).
--   Beasts.drawUp(id, x, y, z, angle, k, alpha, kAlong)   the same, standing up (see below)
--   Beasts.point(x, y, angle, k, u, v)  -> world x, y of picture pixel (u, v) (from origin)
local Iso = require("src.core.iso")

local Beasts = { cache = {} }

local sqrt, floor, max, min, abs = math.sqrt, math.floor, math.max, math.min, math.abs
local cos, sin, atan2 = math.cos, math.sin, math.atan2 or math.atan

local LIGHT = { -0.55, -0.65, 0.55 }
do
    local l = sqrt(LIGHT[1] ^ 2 + LIGHT[2] ^ 2 + LIGHT[3] ^ 2)
    for i = 1, 3 do LIGHT[i] = LIGHT[i] / l end
end

local function hex(s)
    s = s:gsub("#", "")
    return { tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255 }
end

local function mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end
local function shade(c, k) return { min(1, c[1] * k), min(1, c[2] * k), min(1, c[3] * k) } end

-- Cheap deterministic noise 0..1 for a pixel.
local function hash(x, y, seed)
    local n = sin(x * 12.9898 + y * 78.233 + (seed or 0) * 37.719) * 43758.5453
    return n - floor(n)
end

----------------------------------------------------------------------------------------------
-- A paint buffer. Coordinates are picture pixels relative to the origin (ox, oy); +u forward
-- (right), +v to the bird's right side (down).

local Pic = {}
Pic.__index = Pic

local function newPic(w, h, ox, oy)
    return setmetatable({ w = w, h = h, ox = ox, oy = oy, px = {} }, Pic)
end

function Pic:set(u, v, c)
    local x, y = floor(u + self.ox + 0.5), floor(v + self.oy + 0.5)
    if x >= 0 and y >= 0 and x < self.w and y < self.h then self.px[y * self.w + x] = c end
end

function Pic:get(u, v)
    local x, y = floor(u + self.ox + 0.5), floor(v + self.oy + 0.5)
    if x >= 0 and y >= 0 and x < self.w and y < self.h then return self.px[y * self.w + x] end
end

-- Iterate the pixels of a rotated box: fn(u, v, a, b) with (a, b) the pixel in the shape's own
-- frame (a along `ang`, b across), for |a| <= ra and |b| <= rb around (cu, cv).
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

-- A lit ellipsoid. ramp = list of colours dark..light; texture(u, v, i, a, b) may return a
-- colour to use instead (fur streaks, markings) given the light level i (0..1).
function Pic:blob(cu, cv, ra, rb, ang, ramp, texture, bias)
    local n = #ramp
    self:each(cu, cv, ra, rb, ang or 0, function(u, v, a, b)
        local da, db = a / ra, b / rb
        local d2 = da * da + db * db
        if d2 > 1 then return end
        local nz = sqrt(1 - d2)
        -- surface normal in picture space (rotate the shape-frame normal back)
        local c, s = cos(ang or 0), sin(ang or 0)
        local nu, nv = da * c - db * s, da * s + db * c
        local i = nu * LIGHT[1] + nv * LIGHT[2] + nz * LIGHT[3] + (bias or 0)
        i = max(0, min(0.999, i * 0.5 + 0.5 + (hash(u, v, 3) - 0.5) * 0.12))
        local col = texture and texture(u, v, i, a, b) or ramp[floor(i * n) + 1]
        if col then self:set(u, v, col) end
    end)
end

-- A tapered feather: from (u, v) along `ang`, `len` long and `wid` wide at its widest.
-- cols = { base, fringe, shaft, tip (optional, the last `tipLen` px) }
function Pic:feather(u, v, ang, len, wid, cols, tipLen)
    local hw = wid / 2
    local cu, cv = u + cos(ang) * len / 2, v + sin(ang) * len / 2
    self:each(cu, cv, len / 2 + 1, hw + 1, ang, function(pu, pv, a, b)
        local t = (a + len / 2) / len         -- 0 at the base .. 1 at the tip
        if t < 0 or t > 1 then return end
        local w = hw * min(1, sin(min(1, t * 1.15) * math.pi * 0.5 + 0.35)) * (t > 0.82 and sqrt(max(0, (1 - t) / 0.18)) or 1)
        if abs(b) > w then return end
        local col = cols[1]
        if tipLen and cols[4] and (1 - t) * len < tipLen then col = cols[4]
        elseif abs(b) >= w - 1.3 then col = cols[2]
        elseif abs(b) < 0.6 and t < 0.9 and cols[3] then col = cols[3] end
        -- light falls across: the upper-left half of each vane a touch brighter
        local side = b * cos(ang) * LIGHT[2] - b * sin(ang) * LIGHT[1]
        if side > 0.5 and col == cols[1] then col = shade(col, 1.12) end
        self:set(pu, pv, col)
    end)
end

-- A line of round dabs (hair strands, claws, streaks): radius r0 -> r1 along the way.
function Pic:stroke(u1, v1, u2, v2, r0, r1, col)
    local d = sqrt((u2 - u1) ^ 2 + (v2 - v1) ^ 2)
    local n = max(1, floor(d * 1.5))
    for i = 0, n do
        local t = i / n
        local r = r0 + (r1 - r0) * t
        local u, v = u1 + (u2 - u1) * t, v1 + (v2 - v1) * t
        if r <= 0.6 then self:set(u, v, col)
        else
            for dv = -r, r do
                for du = -r, r do
                    if du * du + dv * dv <= r * r then self:set(u + du, v + dv, col) end
                end
            end
        end
    end
end

-- A soft outline: empty pixels next to painted ones get a dark edge.
function Pic:outline(col)
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
    for i, c in pairs(self.px) do
        data:setPixel(i % w, floor(i / w), c[1], c[2], c[3], c[4] or 1)
    end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    return { image = img, ox = self.ox, oy = self.oy, w = self.w, h = self.h }
end

----------------------------------------------------------------------------------------------
-- House sparrow (male), seen from above.

local SP = {
    prim = hex("#3b2b1f"), primEdge = hex("#7e5f3f"), shaft = hex("#22170f"),
    sec = hex("#4a3425"), secEdge = hex("#a87d4f"),
    gcov = hex("#2f2118"), gcovEdge = hex("#be8f58"),
    mcov = hex("#3a2a1e"), bar = hex("#eee6d4"),
    lesser = { hex("#4a2a18"), hex("#62381f"), hex("#7a4626"), hex("#8e5630") },
    back = { hex("#4e321e"), hex("#6e472a"), hex("#8c5c36"), hex("#a8784a") },
    streak = hex("#22160e"), buff = hex("#c9a06a"),
    rump = { hex("#5e554b"), hex("#766c60"), hex("#8f8476"), hex("#a39888") },
    crown = { hex("#4e4c4a"), hex("#64615e"), hex("#7a7672"), hex("#8e8a84") },
    nape = { hex("#4e2a16"), hex("#68381e"), hex("#814828"), hex("#985a32") },
    cheek = hex("#c9c5bc"), eye = hex("#0c0908"), glint = hex("#e8e8e8"), white = hex("#efeae0"),
    beak = { hex("#1c1917"), hex("#2c2826"), hex("#423c38"), hex("#5c5550") },
    tail = hex("#45342a"), tailEdge = hex("#8a6a48"),
    outline = { 0.07, 0.05, 0.04, 1 },
}

-- The back, rump and mantle streaks (shared by flying and perched pictures).
local function sparrowBody(p, perched)
    p:blob(-4, 0, 30, perched and 16 or 15, 0, SP.back, function(u, v, i, a, b)
        local n = #SP.back
        if u < -18 then return SP.rump[floor(i * #SP.rump) + 1] end
        -- black mantle streaks with buff stripes between, running back along the body
        local lane = abs(v) + (hash(floor(u / 4), v > 0 and 1 or 2, 9) - 0.5) * 2.4 + sin(u * 0.35) * 0.6
        if u > -16 and u < 18 then
            if abs(lane - 5) < 1.1 or abs(lane - 10.5) < 1.0 then return SP.streak end
            if abs(lane - 7.8) < 0.8 and i > 0.35 then return SP.buff end
        end
        return SP.back[floor(i * n) + 1]
    end)
end

local function sparrowHead(p, hu)
    -- nape and the chestnut band behind the eye, grey crown on top
    p:blob(hu - 3, 0, 14, 12, 0, SP.nape)
    p:blob(hu + 1, 0, 10, 6.5, 0, SP.crown, function(u, v, i)
        if u < hu - 6 and abs(v) > 3 then return SP.nape[floor(i * 4) + 1] end
    end)
    for s = -1, 1, 2 do
        p:set(hu + 6, s * 10, SP.eye) p:set(hu + 7, s * 10, SP.eye)
        p:set(hu + 6, s * 11, SP.eye) p:set(hu + 7, s * 11, SP.eye)
        p:set(hu + 7, s * 10 - s, SP.glint)
        p:set(hu + 3, s * 10, SP.white)
    end
    -- a stout seed-eater's cone of a beak
    p:each(hu + 17, 0, 6, 5, 0, function(u, v, a, b)
        local t = (a + 6) / 12
        if abs(b) <= 4.6 * (1 - t) + 0.3 then
            local i = (-b * 0.08 + (1 - t) * 0.6)
            p:set(u, v, SP.beak[max(1, min(4, floor(i * 4) + 2))])
        end
    end)
end

local function sparrowTail(p, spread)
    for i = -3, 3 do
        local a = math.pi + i * 0.07 * spread
        p:feather(-24, i * 1.6, a, 48, 10, { SP.tail, SP.tailEdge, SP.shaft })
    end
end

-- One wing out to side s (+1 right, -1 left). spanK: 1 fully spread, less mid-flap;
-- sweep: how far back the hand is swept.
local function sparrowWing(p, s, spanK, sweep)
    local L = 118 * spanK
    local su, sv = 6, s * 13
    local wu, wv = 14 - sweep * 14, s * (13 + L * 0.46)          -- wrist
    local tu, tv = -4 - sweep * 40, s * (13 + L)                 -- wing tip
    local tipAng = atan2(tv - wv, tu - wu)
    local backAng = atan2(s * 0.22, -1)
    -- primaries: fan from pointing at the tip (outermost) to pointing back
    for i = 8, 0, -1 do
        local k = i / 8
        local bu = wu + (tu - wu) * 0.18 * (1 - k)
        local bv = wv + (tv - wv) * 0.18 * (1 - k)
        local ang = tipAng + (backAng - tipAng) * k ^ 0.9
        local len = (L * 0.58) * (1 - 0.22 * k) + 4
        p:feather(bu, bv, ang, len, 10, { SP.prim, SP.primEdge, SP.shaft })
    end
    -- secondaries along the arm, trailing back
    for i = 9, 0, -1 do
        local k = i / 9
        local bu, bv = su + (wu - su) * (0.15 + 0.85 * k), sv + (wv - sv) * (0.15 + 0.85 * k)
        p:feather(bu - 2, bv, backAng + s * 0.05 * k, 30 + 4 * k, 11, { SP.sec, SP.secEdge, SP.shaft })
    end
    -- greater coverts: black centres, warm fringes
    for i = 11, 0, -1 do
        local k = i / 11
        local bu, bv = su + (wu - su) * (0.05 + 0.95 * k), sv + (wv - sv) * (0.05 + 0.95 * k)
        p:feather(bu + 1, bv, backAng, 16, 9, { SP.gcov, SP.gcovEdge, nil })
    end
    -- primary coverts over the hand
    for i = 5, 0, -1 do
        local k = i / 5
        local bu, bv = wu + (tu - wu) * 0.12 * k, wv + (tv - wv) * 0.12 * k
        p:feather(bu, bv, tipAng + (backAng - tipAng) * 0.5, 14, 8, { SP.gcov, SP.primEdge, nil })
    end
    -- median coverts: the white wing bar
    for i = 12, 0, -1 do
        local k = i / 12
        local bu, bv = su + (wu - su) * (0.05 + 0.95 * k), sv + (wv - sv) * (0.05 + 0.95 * k)
        p:feather(bu + 3, bv, backAng, 9, 7, { SP.mcov, SP.mcov, nil, SP.bar }, 3)
    end
    -- lesser coverts: the chestnut shoulder along the leading edge
    local lu, lv = (su + wu) / 2 + 4, (sv + wv) / 2
    local la = atan2(wv - sv, wu - su)
    p:blob(lu + 1, lv, sqrt((wu - su) ^ 2 + (wv - sv) ^ 2) / 2 + 2, 4, la, SP.lesser)
end

local function paintSparrowFlight(spanK, sweep)
    local p = newPic(160, 280, 90, 140)
    sparrowTail(p, 2.0)
    sparrowWing(p, -1, spanK, sweep)
    sparrowWing(p, 1, spanK, sweep)
    sparrowBody(p, false)
    sparrowHead(p, 30)
    p:outline(SP.outline)
    return p:image()
end

local function paintSparrowPerched()
    local p = newPic(150, 70, 90, 35)
    sparrowTail(p, 0.6)
    -- folded wings lie along the sides: long primaries back toward the tail, black-centred
    -- tertials with buff fringes, the white bar across them
    for s = -1, 1, 2 do
        for i = 4, 0, -1 do p:feather(-6 - i * 2, s * (9 + i * 0.4), math.pi - s * 0.1, 40, 9, { SP.prim, SP.primEdge, SP.shaft }) end
    end
    sparrowBody(p, true)
    for s = -1, 1, 2 do
        for i = 3, 0, -1 do p:feather(6 - i * 6, s * 11, math.pi - s * 0.14, 22, 12, { SP.gcov, SP.gcovEdge, nil }) end
        for i = 5, 0, -1 do p:feather(12 - i * 3, s * 13, math.pi - s * 0.3, 8, 6, { SP.mcov, SP.mcov, nil, SP.bar }, 3) end
        p:blob(12, s * 12, 9, 4, 0, SP.lesser)
    end
    p:outline(SP.outline)
    return p:image()
end

local function paintSparrowHead()
    local p = newPic(56, 40, 22, 20)
    sparrowHead(p, 2)
    p:outline(SP.outline)
    return p:image()
end

----------------------------------------------------------------------------------------------
-- Giant anteater, seen from above.

local AT = {
    head = { hex("#4a443c"), hex("#625a50"), hex("#7c7366"), hex("#958b7c"), hex("#aca192") },
    body = { hex("#3a342e"), hex("#4f4740"), hex("#665d53"), hex("#7e7466"), hex("#948876") },
    hind = { hex("#2a2622"), hex("#38332e"), hex("#4a443d"), hex("#5e564c") },
    hairL = hex("#b3a894"), hairD = hex("#2a2420"),
    stripe = hex("#151210"), cream = hex("#ddd6c4"), cream2 = hex("#c4bba6"),
    leg = { hex("#7c7468"), hex("#968e80"), hex("#b0a896"), hex("#c8c0ac"), hex("#d8d0bc") },
    wrist = hex("#16120f"), palm = { hex("#2a2622"), hex("#3a3530"), hex("#4c4640") },
    claw = hex("#2a2420"), clawHi = hex("#6a6056"),
    nose = hex("#141110"), eye = hex("#060505"),
    tail = { hex("#24201c"), hex("#332d28"), hex("#463f37"), hex("#5a5146") },
    outline = { 0.06, 0.05, 0.04, 1 },
}

-- Coarse hair laid over a painted area: short strokes running back (toward -u), light ones
-- on the lit side, dark ones in the grain. Only over pixels already painted with `onlyOver`.
local function fur(p, rng, u0, u1, v0, v1, count, len, light, dark, flow)
    for _ = 1, count do
        local u, v = u0 + rng:random() * (u1 - u0), v0 + rng:random() * (v1 - v0)
        if p:get(u, v) then
            local a = math.pi + (flow or 0.35) * (v / max(1, abs(v1))) + (rng:random() - 0.5) * 0.4
            local l = len * (0.6 + rng:random() * 0.7)
            local col = rng:random() < 0.55 and light or dark
            local n = floor(l)
            for i = 0, n do
                local pu, pv = u + cos(a) * i, v + sin(a) * i
                if not p:get(pu, pv) then break end
                p:set(pu, pv, col)
            end
        end
    end
end

-- A body painted from a width profile: keys = { {u, halfWidth}, ... } (u rising), smoothly
-- joined, lit like a lying cylinder. colorAt(u, v, i, r) returns the colour (or nil to skip).
local function profile(keys, u)
    if u < keys[1][1] or u > keys[#keys][1] then return nil end
    for i = 1, #keys - 1 do
        local a, b = keys[i], keys[i + 1]
        if u <= b[1] then
            local t = (u - a[1]) / (b[1] - a[1])
            t = t * t * (3 - 2 * t)
            return a[2] + (b[2] - a[2]) * t
        end
    end
end

local function paintProfile(p, keys, colorAt)
    for u = floor(keys[1][1]), floor(keys[#keys][1]) do
        local r = profile(keys, u)
        if r and r > 0.5 then
            for v = -floor(r), floor(r) do
                local nb = v / r
                local nz = sqrt(max(0, 1 - nb * nb))
                local i = nb * LIGHT[2] + nz * LIGHT[3]
                i = max(0, min(0.999, i * 0.55 + 0.42 + (hash(u, v, 5) - 0.5) * 0.14))
                local col = colorAt(u, v, i, r)
                if col then p:set(u, v, col) end
            end
        end
    end
end

local function stripeDist(u, v)
    local s = v >= 0 and 1 or -1
    -- the stripe runs from the throat side (34, s*40) back to the spine (-84, s*2)
    local ax, ay, bx, by = 34, s * 40, -84, s * 2
    local vx, vy = bx - ax, by - ay
    local l = sqrt(vx * vx + vy * vy)
    return ((u - ax) * vy - (v - ay) * vx) / l * s       -- + is toward the head side
end

local ANT_BODY = {
    { -236, 4 }, { -214, 22 }, { -185, 31 }, { -150, 36 }, { -118, 47 }, { -80, 52 }, { -40, 51 },
    { -5, 48 }, { 22, 38 }, { 44, 24 }, { 62, 16 }, { 74, 12 }, { 120, 8.5 }, { 168, 4.5 }, { 182, 3 },
}

local function paintAnteater()
    local rng = love.math.newRandomGenerator(7)
    local p = newPic(440, 120, 244, 60)
    paintProfile(p, ANT_BODY, function(u, v, i, r)
        local ramp
        if u < -150 then ramp = AT.tail
        elseif u < -70 then ramp = AT.hind
        elseif u < 26 then ramp = AT.body
        else ramp = AT.head end
        -- blend the ramps over a few pixels with noise so there are no hard seams
        local j = hash(u, v, 8)
        if u < -150 and u > -162 and j > (u + 162) / 12 then ramp = AT.hind end
        if u >= -70 and u < -56 and j > (u + 70) / 14 then ramp = AT.hind end
        if u >= 26 and u < 40 and j > (u - 26) / 14 then ramp = AT.body end
        if u > -90 and u < 40 then
            local d = stripeDist(u, v)
            if d > -6 and d < 6 then return AT.stripe end
            if d >= 6 and d < 12 then return i > 0.45 and AT.cream or AT.cream2 end
        end
        if u > 168 then return i > 0.62 and hex("#3a3430") or AT.nose end
        return ramp[floor(i * #ramp) + 1]
    end)
    -- coarse hair over everything but the snout, longest on the tail
    fur(p, rng, -236, -150, -36, 36, 900, 13, hex("#5e5548"), AT.hairD, 0.7)
    fur(p, rng, -150, -40, -52, 52, 1300, 9, hex("#6e6558"), AT.hairD, 0.5)
    fur(p, rng, -40, 70, -48, 48, 700, 7, AT.hairL, AT.hairD, 0.35)
    -- re-lay the stripe edges with hair crossing them so they look furred, not cut
    for _ = 1, 260 do
        local u, v = -84 + rng:random() * 120, (rng:random() - 0.5) * 96
        local d = stripeDist(u, v)
        if abs(d - 6) < 2 or abs(d + 6) < 2 then
            local col = d > 0 and AT.cream2 or AT.stripe
            if rng:random() < 0.5 then col = d > 0 and AT.stripe or AT.body[2] end
            for k = 0, 3 do if p:get(u - k, v) then p:set(u - k, v, col) end end
        end
    end
    -- small round ears and the tiny eyes
    for s = -1, 1, 2 do
        p:blob(54, s * 17, 4.5, 3.5, 0, AT.body)
        p:set(68, s * 10, AT.eye) p:set(69, s * 10, AT.eye)
        p:set(178, s * 1.5, AT.eye)
    end
    p:outline(AT.outline)
    return p:image()
end

-- One huge foreleg reaching forward (+u): pale furred arm, black wrist band, dark palm and the
-- great hooked middle claw it tears termite mounds open with.
local function paintAnteaterPaw()
    local rng = love.math.newRandomGenerator(11)
    local p = newPic(150, 60, 14, 30)
    paintProfile(p, { { -10, 6 }, { 0, 15 }, { 20, 16 }, { 55, 12 }, { 80, 11 }, { 86, 10 } }, function(u, v, i)
        if u > 68 then return AT.wrist end
        return AT.leg[floor(i * #AT.leg) + 1]
    end)
    fur(p, rng, 0, 66, -15, 15, 160, 6, AT.cream, AT.leg[1], 0.15)
    p:blob(92, 0, 12, 13, 0, AT.palm)
    -- claws: two small, one great curved one
    for _, c in ipairs({ { -8, 18, 2.6 }, { 8, 18, 2.6 }, { 0, 40, 4.8 } }) do
        local cv, len, r = c[1], c[2], c[3]
        local prevU, prevV = 100, cv
        for i = 1, 12 do
            local t = i / 12
            local u = 100 + t * len
            local v = cv + (t * t) * (cv == 0 and 6 or cv * 0.4)
            p:stroke(prevU, prevV, u, v, r * (1 - t * 0.85), r * (1 - t * 0.9), AT.claw)
            prevU, prevV = u, v
        end
        p:stroke(102, cv - r * 0.4, 100 + len * 0.6, cv - r * 0.3 + (cv == 0 and 2 or 0), 0.6, 0.6, AT.clawHi)
    end
    p:outline(AT.outline)
    return p:image()
end

----------------------------------------------------------------------------------------------

local painters = {
    sparrow_glide = function() return paintSparrowFlight(1, 0) end,
    sparrow_up = function() return paintSparrowFlight(0.62, -0.35) end,
    sparrow_down = function() return paintSparrowFlight(0.8, 0.55) end,
    sparrow_tuck = function() return paintSparrowFlight(0.48, 1.0) end,
    sparrow_perched = paintSparrowPerched,
    sparrow_head = paintSparrowHead,
    anteater = paintAnteater,
    anteater_paw = paintAnteaterPaw,
}
Beasts.SPARROW = { "sparrow_glide", "sparrow_up", "sparrow_down", "sparrow_tuck", "sparrow_perched", "sparrow_head" }
Beasts.ANTEATER = { "anteater", "anteater_paw" }

function Beasts.get(id)
    local b = Beasts.cache[id]
    if not b then
        local f = painters[id]
        if not f then error("unknown beast picture '" .. tostring(id) .. "'") end
        b = f()
        Beasts.cache[id] = b
    end
    return b
end

function Beasts.prepare(list)
    for _, id in ipairs(list or {}) do Beasts.get(id) end
end

-- World position of picture pixel (u, v) for a picture at (x, y) turned to `angle`.
function Beasts.point(x, y, angle, k, u, v)
    local c, s = cos(angle), sin(angle)
    return x + (u * c - v * s) * k, y + (u * s + v * c) * k
end

local tf
function Beasts.drawFlat(id, x, y, z, angle, k, alpha, shadow, kAlong)
    local b = Beasts.get(id)
    local lg = love.graphics
    tf = tf or love.math.newTransform()
    local c, s = cos(angle), sin(angle)
    local ka = kAlong or k
    -- picture (u, v) -> world (x + ka*u*c - k*v*s, y + ka*u*s + k*v*c) -> screen (wx - wy, (wx + wy)/2 - z)
    local a11, a12 = ka * (c - s), k * (-s - c)
    local a21, a22 = ka * (c + s) * 0.5, k * (c - s) * 0.5
    local tx, ty = Iso.toScreen(x, y, z or 0)
    tf:setMatrix(a11, a12, 0, tx, a21, a22, 0, ty, 0, 0, 1, 0, 0, 0, 0, 1)
    lg.push()
    lg.applyTransform(tf)
    if shadow then lg.setColor(0.04, 0.03, 0.03, alpha or 0.4) else lg.setColor(1, 1, 1, alpha or 1) end
    lg.draw(b.image, -b.ox, -b.oy)
    lg.pop()
    lg.setColor(1, 1, 1, 1)
end

-- Standing up instead of lying flat: turned in screen space like the bug sprites are, scaled
-- so distances along its length still land on the right world points (a snout tip reaches the
-- spot its tongue starts from), and only lightly squashed across. Solid animals (a perched
-- bird, the anteater) read better this way; flat things (spread wings, shadows) use drawFlat.
function Beasts.drawUp(id, x, y, z, angle, k, alpha, kAlong)
    local b = Beasts.get(id)
    local c, s = cos(angle), sin(angle)
    local dx, dy = c - s, (c + s) * 0.5
    local L = sqrt(dx * dx + dy * dy)
    local sx, sy = Iso.toScreen(x, y, z or 0)
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(b.image, sx, sy, atan2(dy, dx), (kAlong or k) * L, k * 0.95, b.ox, b.oy)
    love.graphics.setColor(1, 1, 1, 1)
end

return Beasts
