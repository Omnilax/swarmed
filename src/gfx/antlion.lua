-- The antlion boss, painted (src/gfx/paint.lua) in the bug sprites' style: a bristly larva
-- dug in at the bottom of its pit with only its head, thorax and two long sickle jaws showing,
-- and the pit itself, a cone of loose sand lit from the upper left that blends into the floor.
--   Antlion.drawBody(o, world, sx, sy, kx, ky, flash)   (content/enemies/predators.lua)
--   Antlion.drawPit(x, y, R, time)                       (content/behaviors/antlion.lua)
local Paint = require("src.gfx.paint")
local Iso = require("src.core.iso")

local Antlion = {}

local hex, ramp = Paint.hex, Paint.ramp
local floor, sqrt, max, min, abs = math.floor, math.sqrt, math.max, math.min, math.abs
local cos, sin, atan2 = math.cos, math.sin, math.atan2 or math.atan

local C = {
    body = ramp("#3a2c20", "#56432f", "#735c40", "#8f7652", "#a88e66"),
    spot = hex("#2a1e14"),
    bristle = hex("#c2a87a"),
    head = ramp("#3b2615", "#573a20", "#73502e", "#8c6640"),
    jaw = ramp("#2a160c", "#4a2a14", "#6e3e1c", "#92582c"),
    tooth = hex("#d8c49a"),
    eye = hex("#120c08"),
    sand = ramp("#5e4c34", "#7e6846", "#a08660", "#bea472", "#d6be8c", "#e8d4a4"),
}

-- the larva, facing right; origin between the jaws' roots. S: picture pixels per unit
local S = 1.6
local function paintBody()
    local p = Paint.pic(floor(44 * S), floor(32 * S), floor(29 * S), floor(16 * S))
    -- abdomen, its back half under the sand: broad, flat, mottled, a fringe of bristles
    p:blob(-14 * S, 0, 12 * S, 10 * S, 0, C.body, function(u, v, i, a, b)
        local h = Paint.hash(floor(u / 2), floor(v / 2), 5)
        if h > 0.74 and i < 0.8 then return C.spot end
        if math.abs(v) < 1 and u > -20 * S then return C.body[max(1, floor(i * #C.body))] end   -- the mid-line
        if (a / (12 * S)) ^ 2 + (b / (10 * S)) ^ 2 > 0.78 and Paint.hash(u, v, 8) > 0.55 then return C.bristle end
        return C.body[floor(i * #C.body) + 1]
    end)
    -- thorax and the narrow neck
    p:blob(-3.5 * S, 0, 5 * S, 5.5 * S, 0, C.body, nil, 0.05)
    p:blob(0, 0, 2.5 * S, 3 * S, 0, C.head)
    -- the head: flat and square-ish, dark, two eye bumps on the sides
    p:blob(3.5 * S, 0, 4.2 * S, 4.4 * S, 0, C.head, nil, 0.05)
    for side = -1, 1, 2 do
        p:set(3 * S, side * 4.4 * S, C.eye); p:set(3 * S + 1, side * 4.4 * S, C.eye)
        p:set(3 * S, side * 4.4 * S - side, C.eye)
    end
    -- the sand it is dug into, piled over its back end (the pit's floor colours)
    for v = floor(-14 * S), floor(14 * S) do
        for u = floor(-30 * S), floor(-12 * S) do
            local edge = -19 * S + 4 * S * sin(v * 0.35) + (Paint.hash(u, v, 2) - 0.5) * 5
            if u < edge and (u + 14 * S) ^ 2 / (190 * S * S) + v * v / (150 * S * S) < 1 then
                local i = 0.3 + (-u - 14 * S) * 0.015 - v * 0.02 + (Paint.hash(u, v, 4) - 0.5) * 0.45
                p:set(u, v, C.sand[max(1, min(#C.sand, floor(i * #C.sand) + 1))])
            end
        end
    end
    p:outline()
    return p
end

-- one jaw (the upper one; drawn mirrored for the other), root at the origin, curving forward
-- and in, with three teeth on its inner edge
local function paintJaw()
    local L = 13 * S
    local p = Paint.pic(floor(L + 4), floor(10 * S), 2, floor(7 * S))
    local pts = {}
    for k = 0, 12 do
        local t = k / 12
        -- out, then hooking back in toward the other jaw
        pts[#pts + 1] = { t * L + 0.5, (-5 * sin(math.pi * t * 0.8) + 3.5 * t * t) * S }
    end
    for k = 1, #pts - 1 do
        local t = (k - 1) / (#pts - 1)
        local r = 1.9 * (1 - t) + 0.45
        p:stroke(pts[k][1], pts[k][2], pts[k + 1][1], pts[k + 1][2], r, r - 0.15, C.jaw)
    end
    for _, k in ipairs({ 5, 7, 9 }) do
        p:set(pts[k][1], pts[k][2] + 2, C.tooth); p:set(pts[k][1], pts[k][2] + 3, C.tooth)
    end
    p:outline()
    return p
end

-- The pit: a cone of sand, radius `R` picture pixels, painted once at full size.
local PIT_R = 100
local function paintPit()
    local R = PIT_R
    local p = Paint.pic(2 * R + 5, 2 * R + 5, R + 2, R + 2)
    -- light from the screen's upper left, as a world direction
    local lx, ly = -0.95, -0.32
    for v = -R - 2, R + 2 do
        for u = -R - 2, R + 2 do
            local d = sqrt(u * u + v * v)
            local t = d / R
            local n = Paint.hash(u, v, 11)
            if t < 1.04 then
                -- the slope faces the middle, so its far side catches the light
                local nx, ny = -u / (d + 0.01), -v / (d + 0.01)
                local lit = (nx * lx + ny * ly) * 0.45
                local i
                if t > 0.9 then
                    -- the raised rim, lit on the outside instead, with a ragged fade into the floor
                    lit = -lit * 0.8
                    i = 0.62 + lit + (n - 0.5) * 0.3
                    if t > 0.97 and n < (t - 0.97) / 0.07 + 0.25 then i = nil end
                else
                    -- deeper is darker; a little streaking where sand slid down
                    local streak = (Paint.hash(floor(math.atan2(v, u) * 30), 0, 7) - 0.5) * 0.12
                    i = 0.08 + t * t * 0.55 + lit * (0.4 + t) + streak + (n - 0.5) * 0.18
                end
                if i then
                    local col = C.sand[max(1, min(#C.sand, floor(i * #C.sand) + 1))]
                    p:set(u, v, { col[1], col[2], col[3], t > 0.9 and 0.95 or 1 })
                end
            elseif t < 1.25 and n > 0.93 then
                local col = C.sand[n > 0.97 and 5 or 4]
                p:set(u, v, { col[1], col[2], col[3], 0.8 })      -- grains thrown out of the pit
            end
        end
    end
    return p
end

local tf
function Antlion.drawPit(x, y, R)
    local pic = Paint.get("antlion_pit", paintPit)
    local k = R / PIT_R
    tf = tf or love.math.newTransform()
    -- picture (u, v) -> world (x + k u, y + k v) -> screen
    local sx, sy = Iso.toScreen(x, y)
    tf:setMatrix(k, -k, 0, sx, k * 0.5, k * 0.5, 0, sy, 0, 0, 1, 0, 0, 0, 0, 1)
    local lg = love.graphics
    lg.push()
    lg.applyTransform(tf)
    lg.setColor(1, 1, 1, 1)
    lg.draw(pic.image, -pic.ox, -pic.oy)
    lg.pop()
end

function Antlion.drawBody(o, world, sx, sy, kx, ky, flash)
    local st = o.st
    local body = Paint.get("antlion_body", paintBody)
    local jaw = Paint.get("antlion_jaw", paintJaw)
    -- face the player (screen angle of the world direction)
    local p = world.player
    local wa = p and atan2(p.y - o.y, p.x - o.x) or 0
    st.look = st.look and st.look + (((wa - st.look + math.pi) % (2 * math.pi)) - math.pi) * 0.08 or wa
    local c, s = cos(st.look), sin(st.look)
    local th = atan2((c + s) * 0.5, c - s)
    local open = st.snap and (0.15 + 0.85 * max(0, 1 - st.snap / 0.25)) or (0.55 + 0.35 * sin(world.time * 3))
    local x, y = sx, sy - 2
    Paint.draw(body, x, y, th, kx, ky, 1, flash)
    local ct, stt = cos(th), sin(th)
    for side = -1, 1, 2 do
        -- jaw root, just in front of the head, either side
        local ju, jv = 7 * S, side * 2.2 * S
        local jx, jy = x + (ju * ct - jv * stt) * kx, y + (ju * stt + jv * ct) * ky
        Paint.draw(jaw, jx, jy, th + side * (open * 0.55 - 0.1), kx, -side * ky, 1, flash)
    end
end

return Antlion
