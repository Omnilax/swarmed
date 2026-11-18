-- Shadows, rim light and sky effects (Lighting tab). Each has its own setting:
--   Sun Shadows: bugs and props cast a long soft shadow away from the sun, short at noon, long
--     at sunrise and sunset; at night they point away from your own light.
--   Contact Shadows: a dark core right under each bug and prop so it sits on the ground.
--   Rim Light: a thin bright edge on the side of each bug that faces the light.
--   Cloud Shadows: big soft shadows drift over the arena by day (stronger when cloudy or windy).
--   Sun Rays: faint light shafts at golden hour and dawn.
--   Wet Ground: after rain the ground darkens and lights shine back from puddles.
local Settings = require("src.core.settings")
local Daylight = require("src.game.daylight")
local Iso = require("src.core.iso")
local Sprites = require("src.gfx.sprites")

local Shading = {}

local cos, sin, atan2, floor = math.cos, math.sin, math.atan2, math.floor

-- Where the sun is: returns dx, dy (screen direction shadows fall in), length factor, strength
-- 0..1, and night (true: shadows point away from the player's light instead).
local FIXED = { day = 0.35, sunset = 0.9, evening = 0.95, dawn = 0.08 }
function Shading.sun(world)
    local mode = Settings.get("timeOfDay")
    local prog
    if mode == "cycle" then
        local f = Daylight.phase(world.time) or 0.2
        prog = ((f - 0.94) % 1) / 0.62      -- 0 at dawn .. 1 just after sunset
        if prog > 1 then prog = nil end
    elseif mode ~= "night" then
        prog = FIXED[mode] or 0.35
    end
    if not prog then return 0, 0, 1.4, 0.8, true end
    -- the sun crosses from the left to the right of the screen; shadows fall the other way
    local a = math.pi * (0.15 + 0.7 * prog)
    local dx, dy = cos(a), -sin(a) * 0.5
    dx, dy = -dx, -dy
    local len = 0.5 + 2.6 * math.abs(prog - 0.5) * 2
    local strength = math.min(1, 0.4 + world:daylight() * 0.6)
    return dx, dy, len, strength, false
end

local function blob(x, y, ang, lenPx, widePx, a)
    local lg = love.graphics
    lg.setColor(0.05, 0.03, 0.06, a)
    lg.draw(Sprites.atlas, Sprites.glow, x, y, ang, lenPx / 16, widePx / 16, 8, 8)
end

local function castOne(o, sx, sy, r, dx, dy, len, a, night, px, py)
    if night then
        local vx, vy = sx - px, sy - py
        local d = math.sqrt(vx * vx + vy * vy)
        if d < 4 or d > 200 then return end
        dx, dy = vx / d, vy / d
        a = a * (1 - d / 200)
        len = 0.8 + d / 90
    end
    local L = r * (1 + len * 1.1)
    blob(sx + dx * L * 0.42, sy + 1 + dy * L * 0.42, atan2(dy, dx), L * 1.3, r * 1.1, a)
end

-- Under the actors and props, before their blob shadows.
function Shading.drawGround(world, list, n)
    local sunOn, contactOn = Settings.get("sunShadows"), Settings.get("contactShadows")
    if not sunOn and not contactOn then return end
    local lg = love.graphics
    local p = world.player
    local px, py = p._sx or 0, p._sy or 0
    local dx, dy, len, strength, night = Shading.sun(world)
    local a = 0.28 * strength
    for i = 1, n do
        local o = list[i]
        if not o.hidden and (o.z or 0) < 8 and not o.dropH then
            local r = (o.radius or 6) * (o.scale or 1)
            if sunOn then castOne(o, o._sx, o._sy, r, dx, dy, len, a, night, px, py) end
            if contactOn then blob(o._sx, o._sy + 1, 0, r * 1.5, r * 0.75, 0.32) end
        end
    end
    for _, o in ipairs(world.props.list) do
        if not o.dead and o.def.draw and (o.z or 0) < 4 then
            local sx, sy = Iso.toScreen(o.x, o.y)
            local r = o.r or 6
            if sunOn then castOne(o, sx, sy, r, dx, dy, len, a, night, px, py) end
            if contactOn then blob(sx, sy + 1, 0, r * 1.6, r * 0.8, 0.3) end
        end
    end
    lg.setColor(1, 1, 1, 1)
end

local RIM = [[
    uniform vec3 rim;
    vec4 effect(vec4 c, Image t, vec2 tc, vec2 sc) { return vec4(rim, Texel(t, tc).a * c.a); }
]]

-- The rim's offset (1 px towards the light) and colour, or nil when Rim Light is off.
function Shading.rim(world)
    if not Settings.get("rimLight") then return nil end
    local dx, dy, _, strength, night = Shading.sun(world)
    Shading.rimShader = Shading.rimShader or love.graphics.newShader(RIM)
    local c
    if night then c = { 0.75, 0.8, 1 } else c = { 1, 0.92, 0.75 } end
    local k = night and 0.8 or (0.6 + 0.4 * strength)
    Shading.rimShader:send("rim", { c[1] * k, c[2] * k, c[3] * k })
    -- towards the light = against the shadow
    local l = math.sqrt(dx * dx + dy * dy)
    if night or l < 0.01 then return 0, -1, true end
    return -dx / l, -dy / l, false
end

-- The enemy rims in one batch (before the crowd itself is drawn, so bodies cover all but the edge).
function Shading.drawRims(world, list, n)
    local rx, ry, night = Shading.rim(world)
    if not rx then return end
    local lg = love.graphics
    local p = world.player
    lg.setShader(Shading.rimShader)
    lg.setColor(1, 1, 1, 0.9)
    for i = 1, n do
        local o = list[i]
        if o ~= p and not o.hidden and o.sprite and not o.model and not o.def.drawBody and (o.alpha or 1) >= 1 then
            local ox, oy = rx, ry
            if night then
                local vx, vy = (p._sx or 0) - o._sx, (p._sy or 0) - o._sy
                local d = math.sqrt(vx * vx + vy * vy) + 0.001
                if d > 180 then ox, oy = 0, -1 else ox, oy = vx / d, vy / d end
            end
            local s = o.scale or 1
            Sprites.draw(o.sprite, floor(o.anim) + 1, o._sx + ox * 1.5, o._sy - (o.z or 0) - (o.dropH or 0) + oy * 1.5, o.angle, false, s, s)
        end
    end
    lg.setShader()
    lg.setColor(1, 1, 1, 1)
end

-- The player's rim: called with the same arguments the model is drawn with.
function Shading.drawPlayerRim(world, model, frame, x, y, facing, sxs, sys, pose)
    local rx, ry, night = Shading.rim(world)
    if not rx then return end
    if night then rx, ry = 0, -1 end
    local lg = love.graphics
    local r, g, b, a = lg.getColor()
    local prev = lg.getShader()
    lg.setShader(Shading.rimShader)
    lg.setColor(1, 1, 1, a)
    Sprites.drawModel(model, frame, x + rx * 1.5, y + ry * 1.5, facing, false, sxs, sys, a, pose)
    lg.setShader(prev)
    lg.setColor(r, g, b, a)
end

-- Cloud Shadows: subtracted from the light map (called inside the light pass, light-map coords).
function Shading.clouds(world, light, ox, oy, vw, vh)
    local mode = Settings.get("cloudShadows")
    if mode == "off" then return end
    local w = world.weather
    local id = w.def and w.def.id
    local cloudy = id == "rain" or id == "storm" or id == "drizzle" or id == "windy" or id == "fog"
    if mode == "weather" and not cloudy then return end
    local day = world:daylight()
    if day < 0.2 then return end
    local k = (cloudy and 0.32 or 0.18) * day
    local speed = id == "windy" and 26 or 10
    local span = vw + 700
    for i = 1, 7 do
        local seed = i * 97.31
        local x = ox - 350 + ((seed * 13 + world.time * speed * (0.8 + (i % 3) * 0.2)) % span)
        local y = oy - 100 + ((seed * 7.7) % (vh + 200)) + sin(world.time * 0.05 + i) * 20
        light(x, y, 260 + (i % 4) * 70, k)
    end
end

-- Sun Rays: faint shafts from the top of the view at golden hour and dawn (additive, after lighting).
function Shading.drawRays(world, ox, oy, vw, vh)
    if not Settings.get("sunRays") then return end
    local f = Daylight.phase(world.time)
    local k
    if f then
        local golden = math.max(0, 1 - math.abs(f - 0.46) / 0.06)
        local dawn = math.max(0, 1 - math.abs(f - 0.97) / 0.04)
        k = math.max(golden, dawn)
    else
        local m = Settings.get("timeOfDay")
        k = (m == "sunset" or m == "dawn") and 0.8 or 0
    end
    if k <= 0.01 then return end
    local lg = love.graphics
    local glare = require("src.gfx.lighting").glareMul()
    lg.setBlendMode("add")
    local L = Sprites.light
    for i = 1, 5 do
        local x = ox + vw * (i / 6) + sin(world.time * 0.15 + i * 1.7) * 30
        local a = 0.05 * k * glare * (0.7 + 0.3 * sin(world.time * 0.4 + i))
        lg.setColor(1, 0.85, 0.6, a)
        lg.draw(L, x, oy + vh * 0.35, 0.45, 0.35 + (i % 2) * 0.15, vh / 64, 64, 64)
    end
    lg.setBlendMode("alpha")
    lg.setColor(1, 1, 1, 1)
end

-- Wet Ground: how wet the arena is rises in rain and dries slowly after.
function Shading.update(world, dt)
    local w = world.weather
    local id = w.def and w.def.id
    local raining = id == "rain" or id == "storm" or id == "drizzle"
    local target = raining and (id == "drizzle" and 0.5 or 1) * w:strength() or 0
    local wet = world.wetness or 0
    if target > wet then wet = math.min(target, wet + dt / 12) else wet = math.max(target, wet - dt / 60) end
    world.wetness = wet
end

-- Darker ground and soft glossy puddles (after the ground, under everything else).
function Shading.drawWet(world, ox, oy, vw, vh)
    local wet = world.wetness or 0
    if wet < 0.02 or not Settings.get("wetGround") then return end
    local lg = love.graphics
    lg.setColor(0.1, 0.12, 0.2, 0.22 * wet)
    lg.rectangle("fill", ox, oy, vw, vh)
    -- puddles: fixed spots on the ground with a sky-coloured sheen
    lg.setBlendMode("add")
    local r0, g0, b0 = Daylight.ambient(world.stage, world.time)
    local L = Sprites.light
    for i = 1, 14 do
        local wx = ((i * 211.7) % 900) - 450
        local wy = ((i * 137.3) % 900) - 450
        local sx, sy = Iso.toScreen(wx, wy)
        if sx > ox - 60 and sx < ox + vw + 60 and sy > oy - 40 and sy < oy + vh + 40 then
            local r = 18 + (i % 5) * 6
            lg.setColor(r0 * 0.5, g0 * 0.55, b0 * 0.7, 0.18 * wet * (0.85 + 0.15 * sin(world.time * 1.3 + i)))
            lg.draw(L, sx, sy, 0, r / 64, r / 128, 64, 64)
        end
    end
    lg.setBlendMode("alpha")
    lg.setColor(1, 1, 1, 1)
end

return Shading
