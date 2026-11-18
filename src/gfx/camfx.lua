-- Camera helpers the world drives each frame (Camera tab). Each has its own setting:
--   Smart Auto-Zoom (Off / Subtle / Full), Horde Framing, Boss Intro Camera, Wave Clear Zoom,
--   Zoom By Bug Size, Foreground Grass (parallax blades at the bottom of the view).
-- Camera Height lives in src/core/screen.lua; Shake Style and Camera Punch in src/game/camera.lua.
local Settings = require("src.core.settings")
local Iso = require("src.core.iso")

local CamFx = {}

-- Once per frame, before camera:follow.
function CamFx.update(world, dt)
    local cam, p = world.camera, world.player
    -- how crowded it is around you, the centre of the crowd, any boss about
    local n, cx, cy, boss = 0, 0, 0, false
    for i = 1, world.enemyCount do
        local e = world.enemies[i]
        if not e.hidden then
            local dx, dy = e.x - p.x, e.y - p.y
            local d2 = dx * dx + dy * dy
            if d2 < 340 * 340 then
                n = n + 1
                cx, cy = cx + dx, cy + dy
                if e.def.boss or e.def.encounter then boss = true end
            end
        end
    end
    cam:setCrowd(n / 140, boss)
    -- Horde Framing: lean up to 30 px towards the crowd
    local fx, fy = 0, 0
    if Settings.get("hordeFraming") and n >= 8 then
        cx, cy = cx / n, cy / n
        local l = math.sqrt(cx * cx + cy * cy)
        if l > 20 then
            local sx, sy = Iso.toScreen(cx / l, cy / l)
            local k = math.min(1, n / 40) * 30
            fx, fy = sx * k, sy * k
        end
    end
    local damp = math.min(1, dt * 1.5)
    cam.frameX = cam.frameX + (fx - cam.frameX) * damp
    cam.frameY = cam.frameY + (fy - cam.frameY) * damp
    -- Zoom By Bug Size: big bugs see a bit further, tiny ones a bit closer
    local target = 1
    if Settings.get("zoomBySize") then
        local s = (p.def.scale or 1) * (p.radius or 7) / 7
        target = math.max(0.8, math.min(1.15, 1 / math.sqrt(s)))
    end
    cam.sizeMul = cam.sizeMul + (target - cam.sizeMul) * math.min(1, dt * 2)
end

-- A boss or a beast walked in (Boss Intro Camera).
function CamFx.onSpawn(world, e)
    local def = e.def
    if not (def.boss or def.encounter) or not Settings.get("bossIntro") then return end
    if world.flags.demo or world.mode ~= "run" then return end
    local sx, sy = Iso.toScreen(e.x, e.y)
    world.camera:glance(sx, sy, 1.6)
    world.bossCard = { name = def.name or def.id, t = 0, life = 1.8 }
end

-- The wave's last ant fell (Wave Clear Zoom).
function CamFx.onWaveCleared(world)
    if Settings.get("waveClearZoom") then world.camera.kick = math.max(world.camera.kick, 0.12) end
end

-- Letterbox bars and the boss's name while the intro glance runs (HUD, window pixels).
function CamFx.drawBossCard(world, w, h, font)
    local c = world.bossCard
    if not c then return end
    c.t = c.t + love.timer.getDelta()
    if c.t >= c.life then world.bossCard = nil return end
    local k = math.sin(math.min(1, c.t / c.life) * math.pi)
    k = math.min(1, k * 2)
    local lg = love.graphics
    local bar = math.floor(h * 0.08 * k)
    lg.setColor(0, 0, 0, 0.85)
    lg.rectangle("fill", 0, 0, w, bar)
    lg.rectangle("fill", 0, h - bar, w, bar)
    lg.setFont(font)
    lg.setColor(1, 0.85, 0.5, k)
    lg.printf(c.name, 0, h - bar - font:getHeight() - 8, w, "center")
    lg.setColor(1, 1, 1, 1)
end

-- Foreground Grass: dark blades along the bottom of the view that drift faster than the ground.
function CamFx.drawForeground(world, ox, oy, vw, vh)
    if not Settings.get("foregroundGrass") then return end
    local lg = love.graphics
    local p = world.player
    local _, py = Iso.toScreen(p.x, p.y)
    -- fade out when you walk down behind them
    local near = (oy + vh) - py
    local fade = math.max(0.25, math.min(1, (near - 30) / 80))
    local par = 0.35       -- extra drift: blades move 1.35x as fast as the ground
    local shift = (ox * par) % 24
    local wind = world.wind or 0
    local t = world.time
    for i = -1, math.ceil(vw / 12) + 2 do
        local seed = (i + math.floor(ox * par / 24) * 2) % 17
        local x = ox + i * 12 - shift + (seed % 5)
        local hgt = 14 + (seed * 7) % 22
        local sway = math.sin(t * 1.4 + seed) * 2 + wind * 6
        local base = oy + vh + 2
        local g = 0.06 + (seed % 3) * 0.02
        lg.setColor(g * 0.6, g * 1.3, g * 0.5, 0.9 * fade)
        lg.polygon("fill", x - 2.5, base, x + 2.5, base, x + sway + 0.5, base - hgt)
    end
    lg.setColor(1, 1, 1, 1)
end

return CamFx
