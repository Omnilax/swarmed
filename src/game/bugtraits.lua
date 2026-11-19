-- Ready-made passives, looks and movement for custom bugs (Bug Creator), set as plain data in a
-- script or picked in the mixer, no code needed:
--
--   passives = { camo = { after = 0.8 }, aura = { radius = 40, dps = 4 }, ... }   see PASSIVES
--   effects  = { glow = { color = "#80ff60", radius = 50, pulse = 2 }, trail = { kind = "spark" },
--                sparkle = { color = "#ffffff", rate = 4 } }
--   movement = { slide = 0.6, hover = 10, bob = 1.5, sideways = { forward = 0.6, side = 1.2 },
--                sprint = { after = 1, speed = 1.4 } }
--   music    = "creep" | { theme = "flute", key = 2 }
--
-- CustomBugs.build calls Traits.build to check and clamp them; the engine calls tick / event /
-- light / drawGlow for custom bugs (src/game/scriptmoves.lua, src/game/world.lua).
local Combat = require("src.game.combat")
local util = require("src.core.util")

local Traits = {}

local function clamp(v, lo, hi, default)
    v = tonumber(v)
    if not v or v ~= v then v = default end
    if v == nil then return nil end
    return math.max(lo, math.min(hi, v))
end
local function hexOr(c, default)
    if type(c) == "string" and (c:match("^#%x%x%x%x%x%x$")) then return util.hex(c) end
    if type(c) == "table" then return { clamp(c[1], 0, 1, 1), clamp(c[2], 0, 1, 1), clamp(c[3], 0, 1, 1) } end
    return default
end
local function statsOf(t, warns, where)
    local Stats = require("src.game.stats")
    local out = {}
    for k, v in pairs(type(t) == "table" and t or {}) do
        if Stats.byId[k] and type(v) == "number" then out[k] = clamp(v, -200, 200, 0)
        else warns[#warns + 1] = where .. ": stat '" .. tostring(k) .. "' dropped" end
    end
    return next(out) and out or nil
end

-- Every passive: what it does (shown in the guide and the mixer) and how its numbers are checked.
Traits.PASSIVES = {
    camo = { name = "Camouflage", desc = "Stand still for a moment to blend in: ants lose track of you. Moving again gives a short damage boost.",
        check = function(t) return { after = clamp(t.after, 0.1, 5, 0.8), alpha = clamp(t.alpha, 0.05, 0.9, 0.3),
            ambush = clamp(t.ambush, 0, 200, 40), ambushTime = clamp(t.ambushTime, 0, 10, 1.5) } end },
    regen = { name = "Rest", desc = "Heal while standing still (and a little while moving).",
        check = function(t) return { still = clamp(t.still, 0, 20, 2), moving = clamp(t.moving, 0, 20, 0) } end },
    aura = { name = "Aura", desc = "Ants near you keep taking damage (and can be slowed).",
        check = function(t) return { radius = clamp(t.radius, 10, 200, 36), dps = clamp(t.dps, 0, 200, 4),
            slow = clamp(t.slow, 0.1, 1, nil), color = hexOr(t.color, { 0.6, 1, 0.5 }) } end },
    thorns = { name = "Thorns", desc = "Getting hit hurts up to 5 ants around you.",
        check = function(t) return { damage = clamp(t.damage, 0, 300, 10), radius = clamp(t.radius, 10, 200, 32) } end },
    feast = { name = "Feast", desc = "Kills can heal you.",
        check = function(t) return { hp = clamp(t.hp, 0, 50, 2), chance = clamp(t.chance, 0, 1, 0.5) } end },
    rampage = { name = "Rampage", desc = "Kills give a short buff (damage by default).",
        check = function(t, warns) return { stat = require("src.game.stats").byId[t.stat or ""] and t.stat or "damage",
            amount = clamp(t.amount, -200, 200, 4), max = clamp(t.max, 1, 50, 10), seconds = clamp(t.seconds, 0.2, 30, 3) } end },
    berserk = { name = "Berserk", desc = "Stronger while badly hurt.",
        check = function(t, warns) return { below = clamp(t.below, 0.05, 0.95, 0.35),
            stats = statsOf(t.stats or { damage = 30, attackSpeed = 20 }, warns, "passives.berserk") } end },
    planted = { name = "Planted", desc = "Stats while standing still (armor by default).",
        check = function(t, warns) return { stats = statsOf(t.stats or { armor = 4 }, warns, "passives.planted") } end },
    momentum = { name = "Momentum", desc = "Stats while moving (damage by default).",
        check = function(t, warns) return { stats = statsOf(t.stats or { damage = 15 }, warns, "passives.momentum") } end },
    venom = { name = "Venomous", desc = "Every hit can poison.",
        check = function(t) return { dps = clamp(t.dps, 0, 100, 3), seconds = clamp(t.seconds, 0.2, 15, 3), chance = clamp(t.chance, 0, 1, 0.5) } end },
    frost = { name = "Chilling", desc = "Every hit can slow.",
        check = function(t) return { mul = clamp(t.mul, 0.1, 1, 0.5), seconds = clamp(t.seconds, 0.2, 10, 1.5), chance = clamp(t.chance, 0, 1, 0.5) } end },
    spark = { name = "Static", desc = "Hits can arc lightning to other ants.",
        check = function(t) return { damage = clamp(t.damage, 0, 300, 5), jumps = math.floor(clamp(t.jumps, 1, 10, 2)),
            chance = clamp(t.chance, 0, 1, 0.2) } end },
    burst = { name = "Burst", desc = "Ants you kill can explode.",
        check = function(t) return { damage = clamp(t.damage, 0, 300, 8), radius = clamp(t.radius, 8, 150, 26), chance = clamp(t.chance, 0, 1, 0.3),
            color = hexOr(t.color, { 1, 0.6, 0.3 }) } end },
    shell = { name = "Hard Shell", desc = "Every few seconds a shell blocks the next hit.",
        check = function(t) return { every = clamp(t.every, 1, 60, 8) } end },
    blink = { name = "Vanish", desc = "Dodging a hit hides you for a moment.",
        check = function(t) return { seconds = clamp(t.seconds, 0.2, 10, 1.5) } end },
    magnet = { name = "Magnet", desc = "Pull pickups from further away.", check = function(t) return { range = clamp(t.range, 0, 300, 60) } end },
    spawn = { name = "Brood", desc = "Every few kills, little helpers hatch and hunt with you.",
        check = function(t) return { every = math.floor(clamp(t.every, 1, 200, 15)), count = math.floor(clamp(t.count, 1, 8, 2)),
            damage = clamp(t.damage, 0, 200, 5), life = clamp(t.life, 1, 30, 8), color = hexOr(t.color, nil) } end },
    stampede = { name = "Stampede", desc = "Running into ants knocks them aside and hurts them.",
        check = function(t) return { damage = clamp(t.damage, 0, 200, 3), push = clamp(t.push, 0, 600, 140) } end },
}
Traits.PASSIVE_ORDER = { "camo", "regen", "aura", "thorns", "feast", "rampage", "berserk", "planted", "momentum",
    "venom", "frost", "spark", "burst", "shell", "blink", "magnet", "spawn", "stampede" }

Traits.TRAILS = { dust = { 0.7, 0.6, 0.45 }, spark = { 1, 0.85, 0.4 }, bubble = { 0.7, 0.9, 1 }, slime = { 0.6, 0.9, 0.4 },
    fire = { 1, 0.5, 0.2 }, frost = { 0.75, 0.9, 1 }, petals = { 1, 0.6, 0.8 }, shadow = { 0.25, 0.2, 0.3 } }

-- Check what a script gave. Sets def.passives / effects / movement / music.
function Traits.build(raw, def, errs, warns)
    if raw.passives ~= nil then
        if type(raw.passives) ~= "table" then errs[#errs + 1] = "passives must be a table like { camo = {} }"
        else
            def.passives = {}
            for k, t in pairs(raw.passives) do
                -- passives = { "camo", "aura" } works too
                local id, args = k, t
                if type(k) == "number" then id, args = t, {} end
                local p = Traits.PASSIVES[id]
                if not p then warns[#warns + 1] = "passives: no passive '" .. tostring(id) .. "' (" .. table.concat(Traits.PASSIVE_ORDER, ", ") .. ")"
                else def.passives[id] = p.check(type(args) == "table" and args or {}, warns) end
            end
            if not next(def.passives) then def.passives = nil end
        end
    end
    local fx = raw.effects
    if fx ~= nil then
        if type(fx) ~= "table" then errs[#errs + 1] = "effects must be a table"
        else
            local e = {}
            if type(fx.glow) == "table" then
                e.glow = { color = hexOr(fx.glow.color, { 1, 0.9, 0.5 }), radius = clamp(fx.glow.radius, 10, 300, 60),
                    intensity = clamp(fx.glow.intensity, 0, 1.5, 0.6), pulse = clamp(fx.glow.pulse, 0, 10, 0) }
            end
            if fx.trail ~= nil then
                local t = type(fx.trail) == "table" and fx.trail or { kind = fx.trail }
                local kind = Traits.TRAILS[t.kind] and t.kind or "dust"
                e.trail = { kind = kind, color = hexOr(t.color, Traits.TRAILS[kind]), every = clamp(t.every, 0.02, 1, 0.08) }
            end
            if type(fx.sparkle) == "table" then
                e.sparkle = { color = hexOr(fx.sparkle.color, { 1, 1, 0.8 }), rate = clamp(fx.sparkle.rate, 0.2, 30, 4) }
            end
            if fx.shimmer ~= nil then e.shimmer = clamp(type(fx.shimmer) == "table" and fx.shimmer.speed or 2, 0.2, 10, 2) end
            def.effects = next(e) and e or nil
        end
    end
    local mv = raw.movement
    if mv ~= nil then
        if type(mv) ~= "table" then errs[#errs + 1] = "movement must be a table"
        else
            local m = { slide = clamp(mv.slide, 0, 0.95, nil), hover = clamp(mv.hover, 0, 30, nil), bob = clamp(mv.bob, 0, 8, nil) }
            if type(mv.sprint) == "table" then m.sprint = { after = clamp(mv.sprint.after, 0, 10, 1), speed = clamp(mv.sprint.speed, 1, 3, 1.4) } end
            if type(mv.sideways) == "table" then
                def.sideways = { forward = clamp(mv.sideways.forward, 0.1, 2, 0.6), side = clamp(mv.sideways.side, 0.1, 2, 1.15) }
            end
            if m.hover and m.hover >= 6 then m.hover = math.max(m.hover, 6) end
            def.movement = next(m) and m or nil
        end
    end
    if raw.music ~= nil then
        local Music = require("src.core.music")
        local ok = {}
        for _, t in ipairs(Music.THEMES) do ok[t] = true end
        local m = raw.music
        local theme = type(m) == "string" and m or type(m) == "table" and m.theme
        if ok[theme] then
            def.music = { theme = theme, key = type(m) == "table" and tonumber(m.key) and math.floor(clamp(m.key, -5, 5, 0)) or nil }
            if not def.music.key then def.music = theme end
        else
            warns[#warns + 1] = "music: pick one of " .. table.concat(Music.THEMES, ", ") .. " (the default fits its tags)"
        end
    end
end

----------------------------------------------------------------------------------------------
-- In play

local function buff(p, key, stats, time)
    local IF = require("src.game.itemfx")
    for stat, v in pairs(stats) do IF.buff(p, "trait_" .. key .. "_" .. stat, stat, v, 0, time) end
end

-- every frame, for a custom bug
function Traits.tick(p, world, dt)
    local def = p.def
    local ps, mv, fx = def.passives, def.movement, def.effects
    local st = p.traits
    if not st then st = { still = 0, moving = 0, tick = 0, shellT = 0, trailT = 0, sparkT = 0 } p.traits = st end
    local moving = p.moving and (p.dashT or 0) <= 0
    if moving then st.still, st.moving = 0, st.moving + dt else st.still, st.moving = st.still + dt, 0 end
    st.tick = st.tick - dt
    local slow = st.tick <= 0
    if slow then st.tick = 0.2 end
    -- movement: hovering, sprinting after a run-up
    if mv then
        if (mv.hover or mv.bob) and not p.holdMode then
            p.liftZ = (mv.hover or 0) + (mv.bob and (1 + math.sin((world.time or 0) * 4)) * mv.bob * 0.5 or 0)
        end
        if mv.sprint then p.traitSpeed = st.moving >= mv.sprint.after and mv.sprint.speed or nil end
    end
    if ps then
        local c = ps.camo
        if c then
            if st.still >= c.after and not p.cloakT then
                p.cloakT, p.alpha, st.camo = "trait_camo", c.alpha, true
                world.particles:burst(p.x, p.y, 6, { { 0.6, 0.75, 0.5 } }, 30, 8)
            elseif moving and st.camo then
                if p.cloakT == "trait_camo" then p.cloakT, p.alpha = nil, nil end
                st.camo = false
                if c.ambush > 0 then buff(p, "ambush", { damage = c.ambush }, c.ambushTime) end
            end
        end
        if ps.regen then
            local r = moving and ps.regen.moving or ps.regen.still
            if r > 0 and st.still > 0.5 or (moving and r > 0) then p.hp = math.min(p.stats:get("maxHp"), p.hp + r * dt) end
        end
        if slow then
            if ps.planted and not moving then buff(p, "planted", ps.planted.stats or {}, 0.3) end
            if ps.momentum and moving then buff(p, "momentum", ps.momentum.stats or {}, 0.3) end
            if ps.berserk and p.hp < p.stats:get("maxHp") * ps.berserk.below then buff(p, "berserk", ps.berserk.stats or {}, 0.3) end
            if ps.magnet then buff(p, "magnet", { pickupRange = ps.magnet.range }, 0.3) end
            local a = ps.aura
            if a then
                for _, e in ipairs(Combat.collect(world, p.x, p.y, a.radius)) do
                    if a.dps > 0 then Combat.damage(world, e, a.dps * 0.2, { dot = true, noCrit = true, procDepth = 2 }) end
                    if a.slow and not e.dead then e.slowT, e.slowMul = math.max(e.slowT, 0.3), math.min(e.slowT > 0 and e.slowMul or 1, a.slow) end
                end
            end
            local sp = ps.stampede
            if sp and moving then
                for _, e in ipairs(Combat.collect(world, p.x, p.y, p.radius + 4)) do
                    local nx, ny = util.normalize(e.x - p.x, e.y - p.y)
                    Combat.damage(world, e, sp.damage, { knockback = sp.push, kbx = nx, kby = ny, noCrit = true, procDepth = 2 })
                end
            end
        end
        if ps.shell then
            if not p.traitShell then
                st.shellT = st.shellT + dt
                if st.shellT >= ps.shell.every then p.traitShell, st.shellT = true, 0 Traits.installWard(p) end
            end
        end
    end
    -- looks: trails and sparkles
    if fx then
        if fx.trail and moving then
            st.trailT = st.trailT - dt
            if st.trailT <= 0 then
                st.trailT = fx.trail.every
                local c = fx.trail.color
                local glow = fx.trail.kind == "spark" or fx.trail.kind == "fire" or fx.trail.kind == "frost"
                world.particles:spawn(p.x - p.aimX * p.radius, p.y - p.aimY * p.radius, 2, 0, 0, 12, 0.5, c, 1,
                    { glow = glow or nil, grav = fx.trail.kind == "bubble" and -20 or (fx.trail.kind == "fire" and -30 or 0) })
            end
        end
        if fx.sparkle then
            st.sparkT = st.sparkT - dt
            if st.sparkT <= 0 then
                st.sparkT = 1 / fx.sparkle.rate
                local a = love.math.random() * math.pi * 2
                world.particles:spawn(p.x + math.cos(a) * p.radius, p.y + math.sin(a) * p.radius, 6, 0, 0, 10, 0.6, fx.sparkle.color, 1,
                    { glow = true, grav = -15 })
            end
        end
    end
end

-- A shell (passive) soaks the next hit; chained onto any other ward the bug has.
function Traits.installWard(p)
    if p.traitWardOn then return end
    p.traitWardOn = true
    local prev = p.ward
    p.ward = function(pl, amount, source)
        if pl.traitShell then
            pl.traitShell = nil
            pl.iframes = math.max(pl.iframes, 0.4)
            pl.world.particles:burst(pl.x, pl.y, 10, { { 1, 0.9, 0.6 }, { 1, 1, 1 } }, 90, 20, { glow = true })
            require("src.core.audio").play("hit", { pitch = 0.6 })
            pl.world:floatText(pl.x, pl.y - 10, "SHELL", { 1, 0.9, 0.6 })
            return true
        end
        if prev then return prev(pl, amount, source) end
    end
end

-- game events (Inventory:trigger), for the passives that react to them
function Traits.event(p, name, ctx)
    local ps = p.def.passives
    if not ps then return end
    local world = ctx.world or p.world
    local depth = (ctx.procDepth or 0)
    if depth >= 2 then return end
    local t = ctx.target
    if name == "onKill" then
        if ps.feast and love.math.random() < ps.feast.chance then p:heal(ps.feast.hp) end
        local r = ps.rampage
        if r then
            p.traits = p.traits or {}
            local st = p.traits
            st.rampN = math.min(r.max, ((st.rampT or 0) > (world.time or 0)) and (st.rampN or 0) + 1 or 1)
            st.rampT = (world.time or 0) + r.seconds
            require("src.game.itemfx").buff(p, "trait_rampage", r.stat, r.amount * st.rampN, 0, r.seconds)
        end
        local b = ps.burst
        if b and ctx.x and love.math.random() < b.chance then
            Combat.area(world, ctx.x, ctx.y, b.radius, b.damage, { knockback = 80, procDepth = depth + 1 })
            world:addFx({ kind = "ring", x = ctx.x, y = ctx.y, r = b.radius, life = 0.2, color = b.color })
        end
        local s = ps.spawn
        if s then
            p.traits = p.traits or {}
            p.traits.kills = (p.traits.kills or 0) + 1
            if p.traits.kills % s.every == 0 then
                local SM = require("src.game.scriptmoves")
                SM.addHelpers(p, { count = s.count, damage = s.damage, life = s.life, color = s.color })
            end
        end
    elseif name == "onHit" and t and not t.dead then
        local v, f, sp = ps.venom, ps.frost, ps.spark
        if v and love.math.random() < v.chance then
            t.poisonT, t.poisonDps = math.max(t.poisonT, v.seconds), math.max(t.poisonDps, v.dps)
        end
        if f and love.math.random() < f.chance then
            t.slowT, t.slowMul = math.max(t.slowT, f.seconds), math.min(t.slowT > 0 and t.slowMul or 1, f.mul)
        end
        if sp and love.math.random() < sp.chance then
            Combat.chain(world, t, sp.jumps, 70, sp.damage, { procDepth = depth + 1, color = { 0.6, 0.85, 1 } })
        end
    elseif name == "onHurt" then
        local th = ps.thorns
        if th then
            Combat.area(world, p.x, p.y, th.radius, th.damage, { knockback = 120, procDepth = depth + 1 })
            world:addFx({ kind = "ring", x = p.x, y = p.y, r = th.radius, life = 0.18, color = { 0.9, 1, 0.6 } })
        end
    elseif name == "onDodge" and ps.blink then
        local id = {}
        p.cloakT, p.alpha = id, 0.3
        p:after(ps.blink.seconds, function(pl) if pl.cloakT == id then pl.cloakT, pl.alpha = nil, nil end end)
    end
end

-- lighting pass: light(x, y, radius, r, g, b, a) in screen space
function Traits.light(p, world, light, px, py)
    local g = p.def.effects and p.def.effects.glow
    if not g then return end
    local k = g.pulse > 0 and (0.75 + 0.25 * math.sin((world.time or 0) * g.pulse * math.pi)) or 1
    light(px, py, g.radius * 2 * k, g.color[1], g.color[2], g.color[3], g.intensity * k)
end

-- additive pass: a soft halo (shows even with lighting off) and the aura ring
function Traits.drawGlow(p, world)
    local def = p.def
    local fx, ps = def.effects, def.passives
    if not (fx or (ps and ps.aura)) or p.dead then return end
    local Iso = require("src.core.iso")
    local Sprites = require("src.gfx.sprites")
    local lg = love.graphics
    local x, y = Iso.toScreen(p.x, p.y, 0)
    local g = fx and fx.glow
    if g then
        local k = g.pulse > 0 and (0.7 + 0.3 * math.sin((world.time or 0) * g.pulse * math.pi)) or 1
        lg.setColor(g.color[1], g.color[2], g.color[3], 0.35 * g.intensity * k)
        lg.draw(Sprites.light, x, y - 4, 0, g.radius * 0.6 / 64, g.radius * 0.45 / 64, 64, 64)
    end
    if fx and fx.shimmer then
        local a = 0.12 + 0.1 * math.sin((world.time or 0) * fx.shimmer * math.pi)
        lg.setColor(1, 1, 1, a)
        lg.draw(Sprites.light, x, y - 4, 0, p.radius * 2.4 / 64, p.radius * 1.6 / 64, 64, 64)
    end
    local a = ps and ps.aura
    if a then
        local c = a.color
        lg.setColor(c[1], c[2], c[3], 0.12 + 0.05 * math.sin((world.time or 0) * 3))
        lg.ellipse("line", x, y, a.radius, a.radius * 0.5)
    end
    lg.setColor(1, 1, 1, 1)
end

-- one line per passive for the Creator's panel
function Traits.describe(def)
    local out = {}
    for _, id in ipairs(Traits.PASSIVE_ORDER) do
        if def.passives and def.passives[id] then out[#out + 1] = Traits.PASSIVES[id].name end
    end
    return out
end

return Traits
