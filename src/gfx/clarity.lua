-- Seeing the player and enemies (Visibility settings in the Lighting tab, plus Accessibility).
-- Each piece has its own setting:
--   Background Dim: the ground and its decor drawn greyer and darker so bugs stand out.
--   Actors Pop: a lighter version of the same, on by default (ground slightly muted).
--   See-Through Silhouettes: your bug (and bosses) show as an outline when buried in a crowd,
--     behind a big body, or inside your own effects.
--   Threat Outlines: a thin gold outline on elites and red on queens and bosses.
--   Enemy Shots On Top: enemy projectiles are drawn again over your effects.
--   Clear Space Around You: damage numbers fade right around your bug.
--   Horde Depth: ants at the back of a big pack draw slightly darker than the ones close to you.
--   Low Health Pulse: a soft red edge with a heartbeat under 25% health.
--   Danger Compass: little wedges on your ground ring pointing at the nearest boss, elite or shot.
local Settings = require("src.core.settings")
local Sprites = require("src.gfx.sprites")
local Iso = require("src.core.iso")

local Clarity = {}

local GROUND = [[
    uniform float desat;
    uniform float dim;
    vec4 effect(vec4 c, Image t, vec2 tc, vec2 sc) {
        vec4 p = Texel(t, tc) * c;
        float l = dot(p.rgb, vec3(0.299, 0.587, 0.114));
        p.rgb = mix(p.rgb, vec3(l), desat) * (1.0 - dim);
        return p;
    }
]]

-- How much the ground is muted: desaturation, darkening (0 = off).
function Clarity.groundMute()
    local dim = Settings.get("backgroundDim") / 100
    local desat = dim * 0.8
    if Settings.get("actorsPop") then desat, dim = desat + 0.14, dim + 0.04 end
    return math.min(0.9, desat), math.min(0.7, dim)
end

-- Shader for the ground pass, or nil when nothing is muted.
function Clarity.groundShader()
    local desat, dim = Clarity.groundMute()
    if desat <= 0 and dim <= 0 then return nil end
    Clarity.gs = Clarity.gs or love.graphics.newShader(GROUND)
    Clarity.gs:send("desat", desat)
    Clarity.gs:send("dim", dim)
    return Clarity.gs
end

local SIL = [[
    uniform vec3 col;
    vec4 effect(vec4 c, Image t, vec2 tc, vec2 sc) { return vec4(col, Texel(t, tc).a * c.a); }
]]
local function silShader(r, g, b)
    Clarity.sil = Clarity.sil or love.graphics.newShader(SIL)
    Clarity.sil:send("col", { r, g, b })
    return Clarity.sil
end

-- Threat Outlines: before the crowd, a coloured copy of each marked enemy nudged 1 px each way.
function Clarity.drawOutlines(world, list, n)
    local mode = Settings.get("threatOutlines")
    if mode == "off" then return end
    local lg = love.graphics
    local p = world.player
    local floor = math.floor
    for pass = 1, 2 do
        local any = false
        for i = 1, n do
            local o = list[i]
            if o ~= p and not o.hidden and o.sprite and not o.def.drawBody then
                local boss = o.def.boss
                local mark = (pass == 1 and o.elite and not boss) or (pass == 2 and boss)
                if mark and (mode == "all" or pass == 1) then
                    if not any then
                        any = true
                        if pass == 1 then lg.setShader(silShader(1, 0.82, 0.3)) else lg.setShader(silShader(1, 0.3, 0.25)) end
                        lg.setColor(1, 1, 1, 0.85)
                    end
                    local s = o.scale or 1
                    local x, y = o._sx, o._sy - (o.z or 0) - (o.dropH or 0)
                    local fr = floor(o.anim) + 1
                    Sprites.draw(o.sprite, fr, x - 1, y, o.angle, false, s, s)
                    Sprites.draw(o.sprite, fr, x + 1, y, o.angle, false, s, s)
                    Sprites.draw(o.sprite, fr, x, y - 1, o.angle, false, s, s)
                    Sprites.draw(o.sprite, fr, x, y + 1, o.angle, false, s, s)
                end
            end
        end
    end
    lg.setShader()
    lg.setColor(1, 1, 1, 1)
end

-- Is the player hard to see right now (crowded, behind a big body, in its own glow)?
local function buried(world)
    local p = world.player
    if #world.fx > 2 then return true end
    local close = 0
    for i = 1, world.enemyCount do
        local e = world.enemies[i]
        local dx, dy = e.x - p.x, e.y - p.y
        local d2 = dx * dx + dy * dy
        if e.def.drawBody and d2 < 90 * 90 then return true end
        if d2 < 22 * 22 then
            close = close + 1
            if close >= 4 then return true end
        end
    end
    return false
end

-- See-Through Silhouettes: after everything else, a faint copy of your bug on top.
function Clarity.drawSilhouette(world, pose)
    if not Settings.get("silhouettes") then return end
    local p = world.player
    if p.dead or not p.model or p.alpha or not p._sx then return end
    world._buriedT = (world._buriedT or 0)
    local want = buried(world) and 1 or 0
    world._buriedT = world._buriedT + (want - world._buriedT) * 0.2
    if world._buriedT < 0.05 then return end
    local lg = love.graphics
    lg.setShader(silShader(1, 0.95, 0.6))
    lg.setColor(1, 1, 1, 0.35 * world._buriedT)
    local facing = p.reversed and p.wangle + math.pi or p.wangle
    Sprites.drawModel(p.model, math.floor(p.anim) + 1, p._sx, p._sy - p.z - (p.dropH or 0), facing, false,
        p.def.scale or 1, p.def.scale or 1, 0.35 * world._buriedT, p._pose)
    lg.setShader()
    lg.setColor(1, 1, 1, 1)
end

-- Horde Depth: colour for an ant this far (world units) from the player, or nil for plain white.
function Clarity.depthShade(d)
    if d < 140 then return nil end
    local k = 1 - math.min(0.22, (d - 140) / 260 * 0.22)
    return k
end

-- Danger Compass: wedges on the ground ring around the player.
function Clarity.drawCompass(world)
    if not Settings.get("dangerCompass") then return end
    local p = world.player
    if p.dead then return end
    local lg = love.graphics
    local px, py = Iso.toScreen(p.x, p.y)
    local function wedge(tx, ty, r, g, b, a)
        local dx, dy = tx - p.x, ty - p.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d < 30 or d > 320 then return end
        local ux, uy = dx / d, dy / d
        local R = 18
        local ax, ay = Iso.toScreen(p.x + ux * R, p.y + uy * R)
        local bx, by = Iso.toScreen(p.x + ux * (R + 7), p.y + uy * (R + 7))
        local sx, sy = -uy * 3.5, ux * 3.5
        local cx, cy = Iso.toScreen(p.x + ux * R + sx, p.y + uy * R + sy)
        local ex, ey = Iso.toScreen(p.x + ux * R - sx, p.y + uy * R - sy)
        lg.setColor(r, g, b, a * (1 - d / 320 * 0.6))
        lg.polygon("fill", bx, by, cx, cy, ex, ey)
        lg.setColor(0, 0, 0, 0.5 * a)
        lg.polygon("line", bx, by, cx, cy, ex, ey)
    end
    -- the biggest threats: bosses and elites, nearest few
    local shown = 0
    for i = 1, world.enemyCount do
        local e = world.enemies[i]
        if not e.hidden and (e.def.boss or e.def.encounter or e.elite) then
            local boss = e.def.boss or e.def.encounter
            wedge(e.x, e.y, boss and 1 or 1, boss and 0.3 or 0.8, boss and 0.25 or 0.3, 0.9)
            shown = shown + 1
            if shown >= 4 then break end
        end
    end
    -- enemy shots heading your way
    for _, s in ipairs(world.hazards.shots) do
        if not s.friendly then
            local dx, dy = p.x - s.x, p.y - s.y
            if (s.vx or 0) * dx + (s.vy or 0) * dy > 0 then wedge(s.x, s.y, 1, 1, 1, 0.8) end
        end
    end
    lg.setColor(1, 1, 1, 1)
    local _ = px + py
end

-- Clear Space Around You: alpha multiplier for world text at window position (wx, wy).
function Clarity.textFade(world, wx, wy)
    if not Settings.get("clearSpace") then return 1 end
    local p = world.player
    if p.dead then return 1 end
    local px, py = world:toWindow(p.x, p.y, 0)
    local d = math.sqrt((wx - px) ^ 2 + (wy - py) ^ 2)
    local r = 70 * (love.graphics.getHeight() / 540)
    if d >= r then return 1 end
    return 0.25 + 0.75 * d / r
end

-- Low Health Pulse (drawn by the HUD at window size).
function Clarity.drawLowHealth(p, maxHp, w, h)
    if not Settings.get("lowHealthPulse") or p.dead then return end
    local f = p.hp / math.max(1, maxHp)
    if f >= 0.25 then return end
    local lg = love.graphics
    local t = love.timer.getTime()
    -- heartbeat: two quick beats then a rest
    local ph = (t * 1.2) % 1
    local beat = math.max(0, 1 - math.abs(ph - 0.1) * 10) + 0.7 * math.max(0, 1 - math.abs(ph - 0.3) * 10)
    local k = (0.18 + 0.22 * beat) * (1 - f / 0.25 * 0.5)
    if Settings.get("reduceFlashing") then k = 0.2 * (1 - f / 0.25 * 0.5) end
    if not Clarity.vig then
        local verts = { { 0.5, 0.5, 0, 0, 0.55, 0.05, 0.05, 0 } }
        for i = 0, 40 do
            local a = i / 40 * math.pi * 2
            verts[#verts + 1] = { 0.5 + math.cos(a) * 0.8, 0.5 + math.sin(a) * 0.8, 0, 0, 0.55, 0.05, 0.05, 1 }
        end
        Clarity.vig = lg.newMesh(verts, "fan", "static")
    end
    lg.setColor(1, 1, 1, k)
    lg.draw(Clarity.vig, 0, 0, 0, w, h)
    lg.setColor(1, 1, 1, 1)
end

return Clarity
