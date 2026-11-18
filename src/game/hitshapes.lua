-- Hitbox shapes and attack feel for custom bug code (me.hit, docs/CUSTOM_BUGS.md "Hitboxes and
-- feel"). A hit is a shape laid along the aim, an optional wind-up (with a telegraph), an
-- optional active time (the shape stays live, can follow the bug and sweep round), and the feel
-- of each contact: damage numbers, sparks, hitstop, shake, knockback direction, a sweet spot,
-- a per-ant callback.
--
-- Shapes (lengths in world pixels, "forward" = along the aim, "side" = across it):
--   circle  { radius }                         centred on the hit point (ahead / x, y)
--   arc     { radius, arc (radians) | degrees, inner }   a wedge from the bug (cone)
--   ring    { radius, inner }                  a donut round the hit point
--   box     { length, width, back }            a rectangle from the hit point forward
--   line    { length, width }                  a thin box (width = thickness each side)
--   poly    { points = { {forward, side}, ... } }  any outline, up to 16 corners
local Combat = require("src.game.combat")
local util = require("src.core.util")

local HS = {}
HS.show = false          -- draw every hitbox (Test Arena / sandbox toggle)
HS.MAX_LIVE = 24

local function num(v, default, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then v = default end
    return math.max(lo, math.min(hi, v))
end
HS.num = num

local SHAPES = { circle = true, arc = true, cone = true, ring = true, box = true, rect = true, line = true, poly = true }
HS.SHAPES = { "circle", "arc", "ring", "box", "line", "poly" }

-- A clean shape from script numbers. scale = the bug's area bonus (reach grows with it).
function HS.shape(t, scale, kind)
    kind = kind or t.shape
    if not SHAPES[kind] then kind = "circle" end
    if kind == "cone" then kind = "arc" end
    if kind == "rect" then kind = "box" end
    scale = scale or 1
    local s = { kind = kind }
    if kind == "circle" then
        s.r = num(t.radius, 30, 2, 400) * scale
        s.reach = s.r
    elseif kind == "arc" then
        s.r = num(t.radius, 40, 4, 400) * scale
        local arc = t.degrees and math.rad(num(t.degrees, 120, 1, 360)) or num(t.arc, 2, 0.02, math.pi * 2)
        s.half = arc / 2
        s.inner = num(t.inner, 0, 0, 390) * scale
        s.reach = s.r
    elseif kind == "ring" then
        s.r = num(t.radius, 50, 4, 400) * scale
        s.inner = math.min(s.r - 2, num(t.inner, s.r * 0.6, 0, 400) * scale)
        s.reach = s.r
    elseif kind == "box" or kind == "line" then
        s.len = num(t.length, kind == "line" and 80 or 50, 2, 600) * scale
        s.back = num(t.back, 0, 0, 200) * scale
        s.hw = kind == "line" and num(t.width, 6, 1, 80) or num(t.width, 24, 2, 400) / 2
        s.reach = s.len
    else
        local pts, reach = {}, 1
        if type(t.points) == "table" then
            for i = 1, math.min(16, #t.points) do
                local p = t.points[i]
                if type(p) == "table" then
                    local f, sd = num(p[1], 0, -400, 400) * scale, num(p[2], 0, -400, 400) * scale
                    pts[#pts + 1] = { f, sd }
                    reach = math.max(reach, math.sqrt(f * f + sd * sd))
                end
            end
        end
        if #pts < 3 then pts = { { 0, -10 }, { 30, 0 }, { 0, 10 } } reach = 30 end
        s.pts, s.reach = pts, reach
    end
    return s
end

-- Distance of a point to the segment a-b (local coords).
local function segDist2(px, py, ax, ay, bx, by)
    local vx, vy = bx - ax, by - ay
    local l2 = vx * vx + vy * vy + 1e-6
    local k = math.max(0, math.min(1, ((px - ax) * vx + (py - ay) * vy) / l2))
    local dx, dy = ax + vx * k - px, ay + vy * k - py
    return dx * dx + dy * dy
end

-- Is a point (f forward, sd side, from the shape's origin) inside, with `er` of slack (the
-- ant's own radius)? Also returns how far along the reach it is (0 .. 1) for sweet spots.
function HS.inside(s, f, sd, er)
    local k = s.kind
    if k == "circle" then
        local d = math.sqrt(f * f + sd * sd)
        return d <= s.r + er, d / s.r
    elseif k == "arc" then
        local d = math.sqrt(f * f + sd * sd)
        if d > s.r + er or d < s.inner - er then return false end
        local ang = math.abs(math.atan2(sd, f))
        local slack = d > 1 and math.atan(er / d) or math.pi
        return ang <= s.half + slack, d / s.r
    elseif k == "ring" then
        local d = math.sqrt(f * f + sd * sd)
        return d <= s.r + er and d >= s.inner - er, (d - s.inner) / math.max(1, s.r - s.inner)
    elseif k == "box" or k == "line" then
        return f >= -s.back - er and f <= s.len + er and math.abs(sd) <= s.hw + er, math.max(0, f) / s.len
    else
        local pts, inside = s.pts, false
        local j = #pts
        for i = 1, #pts do
            local a, b = pts[i], pts[j]
            if ((a[2] > sd) ~= (b[2] > sd)) and (f < (b[1] - a[1]) * (sd - a[2]) / (b[2] - a[2] + 1e-9) + a[1]) then
                inside = not inside
            end
            j = i
        end
        if not inside and er > 0 then
            j = #pts
            for i = 1, #pts do
                if segDist2(f, sd, pts[j][1], pts[j][2], pts[i][1], pts[i][2]) <= er * er then inside = true break end
                j = i
            end
        end
        return inside, math.sqrt(f * f + sd * sd) / s.reach
    end
end

-- The outline in world coordinates (a flat list x1, y1, x2, y2...), for telegraphs and the
-- hitbox view.
function HS.outline(s, ox, oy, ang)
    local c, sn = math.cos(ang), math.sin(ang)
    local out = {}
    local function put(f, sd)
        out[#out + 1] = ox + f * c - sd * sn
        out[#out + 1] = oy + f * sn + sd * c
    end
    local k = s.kind
    if k == "circle" then
        for i = 0, 24 do local a = i / 24 * math.pi * 2 put(math.cos(a) * s.r, math.sin(a) * s.r) end
    elseif k == "arc" then
        local n = math.max(4, math.floor(s.half * 8))
        for i = 0, n do local a = -s.half + i / n * s.half * 2 put(math.cos(a) * s.r, math.sin(a) * s.r) end
        if s.inner > 0 then
            for i = n, 0, -1 do local a = -s.half + i / n * s.half * 2 put(math.cos(a) * s.inner, math.sin(a) * s.inner) end
        else
            put(0, 0)
        end
        put(math.cos(-s.half) * s.r, math.sin(-s.half) * s.r)
    elseif k == "ring" then
        for i = 0, 24 do local a = i / 24 * math.pi * 2 put(math.cos(a) * s.r, math.sin(a) * s.r) end
        for i = 24, 0, -1 do local a = i / 24 * math.pi * 2 put(math.cos(a) * s.inner, math.sin(a) * s.inner) end
    elseif k == "box" or k == "line" then
        put(-s.back, -s.hw) put(s.len, -s.hw) put(s.len, s.hw) put(-s.back, s.hw) put(-s.back, -s.hw)
    else
        for _, p in ipairs(s.pts) do put(p[1], p[2]) end
        put(s.pts[1][1], s.pts[1][2])
    end
    return out
end

local function toScreen(pts, z)
    local Iso = require("src.core.iso")
    local o = {}
    for i = 1, #pts, 2 do
        local x, y = Iso.toScreen(pts[i], pts[i + 1], z or 2)
        o[#o + 1] = x
        o[#o + 1] = y
    end
    return o
end
HS.toScreen = toScreen

-- An outline flash in the world (fx with its own draw).
function HS.flash(world, s, ox, oy, ang, color, life, fill)
    local pts = HS.outline(s, ox, oy, ang)
    world:addFx({ x = ox, y = oy, r = s.reach * 0.4, life = life or 0.18, color = color, draw = function(fx, k, fade)
        local lg = love.graphics
        local sp = toScreen(pts)
        local c = fx.color or { 1, 1, 1 }
        if fill ~= false and #sp >= 6 and s.kind ~= "ring" then
            lg.setColor(c[1], c[2], c[3], 0.25 * fade)
            local ok, tris = pcall(love.math.triangulate, sp)
            if ok then for _, tr in ipairs(tris) do lg.polygon("fill", tr) end end
        end
        lg.setColor(c[1], c[2], c[3], 0.9 * fade)
        lg.setLineWidth(1)
        if #sp >= 4 then lg.line(sp) end
    end })
end

----------------------------------------------------------------------------------------------
-- Live hitboxes (wind-ups, active windows, sweeps)

-- Where a hitbox is and which way it points right now.
local function placeOf(b, player)
    local ox, oy, ang = b.ox, b.oy, b.ang
    local prog = b.active > 0 and math.min(1, math.max(0, (b.t - b.windup) / b.active)) or 1
    if b.follow then
        ang = (b.aimFollow and math.atan2(player.aimY, player.aimX) or b.baseAng) + b.turn
        local c, s = math.cos(ang), math.sin(ang)
        ox, oy = player.x + c * b.ahead - s * b.side, player.y + s * b.ahead + c * b.side
    end
    if b.sweep then ang = ang + b.sweep[1] + (b.sweep[2] - b.sweep[1]) * prog end
    return ox, oy, ang, prog
end
HS.placeOf = placeOf

-- One pass of a hitbox over the ants. Returns how many it hit.
function HS.strike(b, player, world)
    local s = b.shape
    local ox, oy, ang = placeOf(b, player)
    local c, sn = math.cos(ang), math.sin(ang)
    local cands = Combat.collect(world, ox, oy, s.reach + (s.kind == "box" and s.hw or 0) + (s.back or 0))
    local n = 0
    local now = b.t
    local any = false
    for _, e in ipairs(cands) do
        if n >= b.maxTargets then break end
        local last = b.hit[e]
        if not last or (b.rehit and now - last >= b.rehit) then
            local dx, dy = e.x - ox, e.y - oy
            local f, sd = dx * c + dy * sn, -dx * sn + dy * c
            local inside, along = HS.inside(s, f, sd, (e.radius or 4) + (e.hitPad or 0))
            if inside then
                b.hit[e] = now
                n = n + 1
                any = true
                b.apply(e, ox, oy, ang, along or 0, f, sd)
            end
        end
    end
    if any then b.onContact() end
    if HS.show or b.debug then HS.flash(world, s, ox, oy, ang, { 0.4, 1, 1 }, 0.25, false) end
    return n
end

function HS.add(player, b)
    local list = player.hitboxes or {}
    player.hitboxes = list
    if #list >= HS.MAX_LIVE then return false end
    list[#list + 1] = b
    return true
end

function HS.update(player, world, dt)
    local list = player.hitboxes
    if not list then return end
    for i = #list, 1, -1 do
        local b = list[i]
        local was = b.t
        b.t = b.t + dt
        if b.t >= b.windup then
            if was < b.windup and b.onStart then b.onStart() end
            HS.strike(b, player, world)
        end
        if b.t >= b.windup + b.active then table.remove(list, i) end
    end
    if #list == 0 then player.hitboxes = nil end
end

-- Telegraphs (filling outlines during the wind-up) and sweeps in progress.
function HS.draw(player, world)
    local list = player.hitboxes
    if not list then return end
    local lg = love.graphics
    for _, b in ipairs(list) do
        local ox, oy, ang, prog = placeOf(b, player)
        local c = b.color
        if b.t < b.windup and b.telegraph then
            local k = b.t / math.max(0.01, b.windup)
            local sp = toScreen(HS.outline(b.shape, ox, oy, ang), 1)
            if #sp >= 6 then
                lg.setColor(c[1], c[2], c[3], 0.12 + 0.25 * k)
                local ok, tris = pcall(love.math.triangulate, sp)
                if ok then for _, tr in ipairs(tris) do lg.polygon("fill", tr) end end
            end
            lg.setColor(c[1], c[2], c[3], 0.5 + 0.5 * k)
            lg.setLineWidth(1)
            if #sp >= 4 then lg.line(sp) end
        elseif b.t >= b.windup and b.showActive then
            local sp = toScreen(HS.outline(b.shape, ox, oy, ang), 2)
            lg.setColor(c[1], c[2], c[3], 0.35 * (1 - prog * 0.5))
            local ok, tris = pcall(love.math.triangulate, sp)
            if ok then for _, tr in ipairs(tris) do lg.polygon("fill", tr) end end
            lg.setColor(c[1], c[2], c[3], 0.9)
            lg.setLineWidth(1)
            if #sp >= 4 then lg.line(sp) end
        end
    end
    lg.setColor(1, 1, 1, 1)
end

return HS
