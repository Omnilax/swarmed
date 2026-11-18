-- Helpers for item procs that need more than one hit's worth of logic: per-item state, timers
-- that fire every few seconds, timed stat buffs, damaging ground patches and little orbiting
-- critters. Inventory:update runs the timed parts every frame (see the "onTick" trigger).
local Combat = require("src.game.combat")

local ItemFx = {}

-- A scratch table for one item on this player (cooldowns, charges used this wave...).
function ItemFx.state(player, id)
    local all = player.itemState
    if not all then all = {}; player.itemState = all end
    local s = all[id]
    if not s then s = {}; all[id] = s end
    return s
end

-- For onTick procs: true once every `period` seconds (per item id).
function ItemFx.every(ctx, id, period)
    local s = ItemFx.state(ctx.player, id)
    s.clock = (s.clock or 0) + ctx.dt
    if s.clock >= period then
        s.clock = s.clock - period
        if s.clock > period then s.clock = 0 end
        return true
    end
    return false
end

-- A stat change that wears off after `time` seconds. Same key again refreshes it (and replaces
-- the amount), so stacking comes from the caller passing a bigger amount.
function ItemFx.buff(player, key, stat, add, mult, time)
    player.itemBuffs = player.itemBuffs or {}
    local source = "buff:" .. key
    player.stats:removeSource(source)
    player.stats:addModifier(source, stat, add or 0, mult or 0)
    player.itemBuffs[source] = time
end

-- Base damage for a proc that repeats part of a hit that already counted the Damage stat
-- (so it isn't multiplied by it twice): pass as opts.coefficient.
function ItemFx.unscaled(player)
    return 1 / (1 + player.stats:get("damage") / 100)
end

-- A random live ant within r of (x, y), or nil.
function ItemFx.randomEnemy(world, x, y, r)
    local list = Combat.collect(world, x, y, r)
    if #list > 0 then return list[love.math.random(#list)] end
end

-- A patch on the ground that hurts ants standing in it: poison `dps` (topped up while they stay)
-- and an optional slow. Drawn as a hazard zone. { x, y, r, life, dps, slow, color, hurtPlayer }
-- hurtPlayer: damage a second to the player standing in it too (a curse).
function ItemFx.patch(world, z)
    world.itemPatches = world.itemPatches or {}
    local list = world.itemPatches
    if #list >= 12 then
        list[1].zone.t = list[1].zone.maxLife
        table.remove(list, 1)
    end
    require("src.game.runstats").tag(world, z)
    z.zone = world.hazards:addZone({ kind = "item", x = z.x, y = z.y, r = z.r, life = z.life, color = z.color })
    z.t, z.tick = 0, 0
    list[#list + 1] = z
end

-- A trail left on the ground (Snail Slime): small zones that live `life` seconds, at most `max`
-- per key. Ants inside are slowed to `slow`; Player-side effects are up to the item (ItemFx.onTrail).
-- opts = { r, life, slow, color, max }
function ItemFx.trail(world, key, x, y, opts)
    world.itemTrails = world.itemTrails or {}
    local list = world.itemTrails[key]
    if not list then list = {}; world.itemTrails[key] = list end
    if #list >= (opts.max or 24) then
        local old = table.remove(list, 1)
        old.zone.t = old.zone.maxLife
    end
    local z = { x = x, y = y, r = opts.r or 10, life = opts.life or 3, slow = opts.slow, t = 0, tick = 0 }
    z.zone = world.hazards:addZone({ kind = "item", x = x, y = y, r = z.r, life = z.life, color = opts.color or { 0.7, 0.8, 0.9 } })
    list[#list + 1] = z
end

-- Whether (x, y) is on a trail of this key.
function ItemFx.onTrail(world, key, x, y)
    local list = world.itemTrails and world.itemTrails[key]
    if not list then return false end
    for _, z in ipairs(list) do
        local dx, dy = x - z.x, y - z.y
        if dx * dx + dy * dy <= z.r * z.r then return true end
    end
    return false
end

-- Take only `mul` of every bite for `time` seconds (Pill Bug Plates curling up). Player:hurt
-- multiplies by ItemFx.guardMul(player).
function ItemFx.guard(player, mul, time)
    player.itemGuardT = math.max(player.itemGuardT or 0, time)
    player.itemGuardMul = math.min(player.itemGuardT > time and player.itemGuardMul or 1, mul)
end

function ItemFx.guardMul(player)
    if (player.itemGuardT or 0) > 0 then return player.itemGuardMul or 1 end
    return 1
end

-- Runs from Inventory:update: buffs wearing off and ground patches doing their thing.
function ItemFx.update(world, player, dt)
    if (player.itemGuardT or 0) > 0 then player.itemGuardT = player.itemGuardT - dt end
    if world.itemTrails then
        for _, list in pairs(world.itemTrails) do
            for i = #list, 1, -1 do
                local z = list[i]
                z.t, z.tick = z.t + dt, z.tick + dt
                if z.t >= z.life then
                    table.remove(list, i)
                elseif z.slow and z.tick >= 0.25 then
                    z.tick = 0
                    for _, e in ipairs(Combat.collect(world, z.x, z.y, z.r)) do
                        e.slowT, e.slowMul = math.max(e.slowT, 0.4), math.min(e.slowT > 0 and e.slowMul or 1, z.slow)
                    end
                end
            end
        end
    end
    if player.itemBuffs then
        for source, t in pairs(player.itemBuffs) do
            t = t - dt
            if t <= 0 then
                player.stats:removeSource(source)
                player.itemBuffs[source] = nil
            else
                player.itemBuffs[source] = t
            end
        end
    end
    local list = world.itemPatches
    if list then
        for i = #list, 1, -1 do
            local z = list[i]
            z.t, z.tick = z.t + dt, z.tick + dt
            if z.t >= z.life then
                table.remove(list, i)
            elseif z.tick >= 0.25 then
                z.tick = 0
                for _, e in ipairs(Combat.collect(world, z.x, z.y, z.r)) do
                    if z.dps then
                        e.poisonT = math.max(e.poisonT, 1)
                        e.poisonDps = math.max(e.poisonDps, z.dps)
                        e.poisonSrc = z._src or e.poisonSrc
                    end
                    if z.slow then e.slowT, e.slowMul = math.max(e.slowT, 0.4), math.min(e.slowT > 0 and e.slowMul or 1, z.slow) end
                end
                -- a cursed patch (Zombie Fungus) bites you too while you stand in it
                if z.hurtPlayer and not player.dead then
                    local dx, dy = player.x - z.x, player.y - z.y
                    if dx * dx + dy * dy <= z.r * z.r then player:hurt(z.hurtPlayer * 0.25, "curse") end
                end
                if love.math.random() < 0.6 then
                    local a, r = love.math.random() * math.pi * 2, love.math.random() * z.r
                    world.particles:spawn(z.x + math.cos(a) * r, z.y + math.sin(a) * r, 1, 0, 0, 14, 0.7, z.color, 1, { glow = true, grav = -6 })
                end
            end
        end
    end
end

-- Little critters circling the player (gnats). Positions for this frame, n of them, radius r.
function ItemFx.orbit(world, player, n, r, speed)
    local pts = {}
    local t = world.time * (speed or 3)
    for i = 1, n do
        local a = t + i / n * math.pi * 2
        local wob = math.sin(t * 2.3 + i * 1.7) * 3
        pts[i] = { player.x + math.cos(a) * (r + wob), player.y + math.sin(a) * (r + wob) }
    end
    return pts
end

return ItemFx
