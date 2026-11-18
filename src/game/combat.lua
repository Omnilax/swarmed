-- Damage resolution and reusable attack helpers. Attacks and item procs call these instead of
-- touching enemy health directly, so crits, knockback, procs, numbers and kills stay consistent.
local Audio = require("src.core.audio")
local util = require("src.core.util")

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 1, 0.8, 0.3 }
local PFX_2 = { 1, 0.45, 0.15 }
local PFX_3 = { 0.4, 0.3, 0.3 }
local PFX_LIST_1 = { PFX_1, PFX_2, PFX_3 }

local Combat = {}

-- Procs may trigger other procs, but only this deep (stops infinite chains). The live limit
-- grows from 2 to 3 in late waves (World.rewards:procDepth, src/config/rewards.lua procs);
-- MAX_PROC_DEPTH is the hard cap, also passed as procDepth by hits that must never proc.
Combat.MAX_PROC_DEPTH = 3

-- opts: coefficient, knockback, kbx, kby (direction), procDepth, noCrit, color, source,
--       corrode = { mul, time } (takes mul x damage from every hit), stun (seconds frozen),
--       slow = { mul, time } (slows the ant), poison = { dps, time } (damage over time),
--       dot (a poison tick: doesn't interrupt the ant)
-- Hidden enemies (e.hidden: burrowed underground) can't be hit at all.
function Combat.damage(world, e, base, opts)
    if e.dead or e.hidden then return 0 end
    -- a grabbed prop (pebble, twig) being squeezed / stung / slammed: it only chips
    if e.isProp then
        if world.props then world.props:struck(e, math.min(1.5, (base or 10) / 15), opts and opts.kbx, opts and opts.kby) end
        return 0
    end
    opts = opts or {}
    local p = world.player
    local stats = p.stats
    local dmg = base * (1 + stats:get("damage") / 100) * (opts.coefficient or 1)
    local crit = false
    if opts.crit or (not opts.noCrit and love.math.random() * 100 < stats:get("critChance")) then
        crit = true
        dmg = dmg * stats:get("critDamage") / 100
    end
    -- Shield-headed ants (def.shield) standing between the player and this ant soak the hit.
    if world.shieldCount > 0 and not e.def.shield and not opts.ignoreShield then
        local blocker = Combat.shieldFor(world, e)
        if blocker then
            dmg = dmg * (1 - (blocker.def.shield.block or 0.75))
            blocker.flash = 0.06
            world.particles:sparks(blocker.x, blocker.y, 2, { 0.8, 0.85, 1 }, e.x - p.x, e.y - p.y, 1.2, 90)
        end
    end
    -- Elite armour, and behaviours that react to being hit (charges get staggered, and a
    -- counter-hit on a charging ant lands harder).
    if e.elite and e.elite.armor then dmg = dmg * (1 - e.elite.armor) end
    -- acid (vinegaroon) eats the shell: corroded ants take more from every hit
    if e.corrodeT > 0 then dmg = dmg * e.corrodeMul end
    -- a queen behind her royal guard (src/game/pacing.lua) shrugs off most of every hit
    if e.guards and e.guards > 0 then dmg = dmg * (e.guardMul or 0.3) end
    -- onHit(e, world, opts, dmg) returns a damage multiplier (dmg is the hit before it)
    if e.behavior.onHit and not opts.dot then dmg = dmg * (e.behavior.onHit(e, world, opts, dmg) or 1) end
    dmg = math.max(1, util.round(dmg))

    -- run summary: damage by source (src/game/runstats.lua), counting only what the ant had left
    local RunStats = require("src.game.runstats")
    local label = RunStats.label(world, opts)
    if world.runStats then world.runStats:dealtHit(math.min(dmg, math.max(0, e.hp)), label) end
    e.hp = e.hp - dmg
    e.flash = 0.09
    e.squash = 0.12
    e.hurtTimer = 2
    if opts.knockback and opts.knockback > 0 and (opts.kbx or opts.kby) then
        local kb = opts.knockback * (1 + stats:get("knockback") / 100) / e.mass
        e.kvx = e.kvx + (opts.kbx or 0) * kb
        e.kvy = e.kvy + (opts.kby or 0) * kb
    end
    if opts.poison then
        e.poisonT = math.max(e.poisonT, opts.poison[2])
        e.poisonDps = math.max(e.poisonDps, opts.poison[1])
        e.poisonSrc = label         -- its venom ticks count for whoever applied it
    end
    if opts.corrode then
        if e.corrodeT <= 0 then e.corrodeMul = 1 end
        e.corrodeMul = math.max(e.corrodeMul, opts.corrode[1])
        e.corrodeT = math.max(e.corrodeT, opts.corrode[2])
    end
    if opts.stun and e.hp > 0 and not e.def.boss and not e.def.noStun then e.stunT = math.max(e.stunT, opts.stun) end
    if opts.slow then
        e.slowT = math.max(e.slowT, opts.slow[2])
        e.slowMul = math.min(e.slowT > opts.slow[2] and e.slowMul or 1, opts.slow[1])
    end
    if opts.cstatus then require("src.game.bugextras").applyStatus(world, e, opts.cstatus) end
    -- a custom bug's own hit look (Bug Creator: hitFx, or a hit's number / sparks)
    local look = opts.look or p.def.hitLook
    if look then
        world:damageNumber(e.x, e.y, dmg, crit, e, crit and look.crit or look.number)
        local n = look.sparkCount or 2
        if n > 0 then world.particles:sparks(e.x, e.y, crit and n + 4 or n, look.sparkColor or (crit and { 1, 0.85, 0.3 } or { 1, 0.95, 0.8 }), opts.kbx or 0, opts.kby or 0) end
        if look.sound then Audio.play(look.sound, { pitch = 0.9 + love.math.random() * 0.2 }) else Audio.play("hit") end
    else
        world:damageNumber(e.x, e.y, dmg, crit, e)
        world.particles:sparks(e.x, e.y, crit and 6 or 2, crit and { 1, 0.85, 0.3 } or { 1, 0.95, 0.8 }, opts.kbx or 0, opts.kby or 0)
        Audio.play("hit")
    end

    local depth = opts.procDepth or 0
    local cap = world.rewards and world.rewards:procDepth() or 2
    local ctx = world:procContext(e, dmg, crit, depth)
    if stats:get("lifesteal") > 0 and love.math.random() * 100 < stats:get("lifesteal") then p:heal(1) end
    world.events:emit("enemy_hit", ctx)
    if depth < cap then p.inventory:trigger("onHit", ctx) end
    if e.hp <= 0 then
        world:killEnemy(e)
        world.events:emit("enemy_killed", ctx)
        if depth < cap then p.inventory:trigger("onKill", ctx) end
    end
    return dmg
end

-- A shielding ant between the player and `e`, if any (within its shield reach).
function Combat.shieldFor(world, e)
    local p = world.player
    local ex, ey = e.x - p.x, e.y - p.y
    local el = math.sqrt(ex * ex + ey * ey) + 0.0001
    local list, n = world:queryEnemies(e.x, e.y, 30)
    for i = 1, n do
        local o = list[i]
        if o ~= e and not o.dead and o.def.shield then
            local ox, oy = o.x - p.x, o.y - p.y
            local along = (ox * ex + oy * ey) / el          -- how far along the line to e
            local across = math.abs(ox * ey - oy * ex) / el  -- distance off the line
            if along > 0 and along < el and across < o.radius * (o.def.shield.width or 2.2) then return o end
        end
    end
end

-- Fresh list of live enemies touching the circle, optionally filtered by filter(e, dx, dy).
function Combat.collect(world, x, y, radius, filter)
    local list, n = world:queryEnemies(x, y, radius + 16)
    local out = {}
    for i = 1, n do
        local e = list[i]
        local dx, dy = e.x - x, e.y - y
        local r = radius + e.radius + e.hitPad
        if not e.dead and not e.hidden and dx * dx + dy * dy <= r * r and (not filter or filter(e, dx, dy)) then
            out[#out + 1] = e
        end
    end
    return out
end

-- Stagger an ant out of whatever it is winding up (used by behaviours' onHit). It stops,
-- reels back along the blow and is left dazed for `time` seconds.
function Combat.stagger(world, e, time, opts)
    local st = e.st
    st.mode, st.t = "stagger", time
    e.hitPad = 0
    local kx, ky = opts and opts.kbx, opts and opts.kby
    if not kx then kx, ky = util.normalize(e.x - world.player.x, e.y - world.player.y) end
    e.kvx, e.kvy = e.kvx + kx * 140 / e.mass ^ 0.5, e.kvy + ky * 140 / e.mass ^ 0.5
    e.z = 0
    if e.hp > 0 then world:floatText(e.x, e.y, "STAGGER", { 1, 0.85, 0.4 }, false) end
    world.particles:sparks(e.x, e.y, 6, { 1, 0.9, 0.5 }, kx, ky, 1.5, 140)
    Audio.play("hit", { pitch = 0.7 })
end

-- Drawn over a staggered ant: little stars circling its head.
function Combat.drawDazed(e)
    local Iso = require("src.core.iso")
    local x, y = Iso.toScreen(e.x, e.y)
    local t = love.timer.getTime() * 6
    for i = 0, 2 do
        local a = t + i * 2.09
        love.graphics.setColor(1, 0.9, 0.4, 0.9)
        love.graphics.rectangle("fill", math.floor(x + math.cos(a) * 5), math.floor(y - 7 + math.sin(a) * 2), 1, 1)
    end
end

-- Live enemies near the segment (x1, y1)-(x2, y2), within `width` of it.
function Combat.collectLine(world, x1, y1, x2, y2, width)
    local mx, my = (x1 + x2) / 2, (y1 + y2) / 2
    local vx, vy = x2 - x1, y2 - y1
    local len2 = vx * vx + vy * vy + 0.0001
    local out = {}
    for _, e in ipairs(Combat.collect(world, mx, my, math.sqrt(len2) / 2 + width)) do
        local t = math.max(0, math.min(1, ((e.x - x1) * vx + (e.y - y1) * vy) / len2))
        local dx, dy = x1 + vx * t - e.x, y1 + vy * t - e.y
        local r = width + e.radius + e.hitPad
        if dx * dx + dy * dy <= r * r then out[#out + 1] = e end
    end
    return out
end

-- Hit every enemy within `radius` of (x, y). Returns the number hit.
function Combat.area(world, x, y, radius, base, opts)
    local hits = 0
    for _, e in ipairs(Combat.collect(world, x, y, radius)) do
        local nx, ny = util.normalize(e.x - x, e.y - y)
        local o = { kbx = nx, kby = ny }
        for k, v in pairs(opts or {}) do o[k] = v end
        Combat.damage(world, e, base, o)
        hits = hits + 1
    end
    return hits
end

-- Explosion: area damage plus a visible blast ring, sound and shake.
function Combat.explode(world, x, y, radius, base, opts)
    world:addFx({ kind = "ring", x = x, y = y, r = radius, life = 0.25, color = (opts and opts.color) or { 1, 0.6, 0.2 } })
    world.particles:burst(x, y, 10, PFX_LIST_1, 120, 90)
    world.camera:shake(0.15)
    Audio.play("boom")
    local o = { knockback = 120 }
    for k, v in pairs(opts or {}) do o[k] = v end
    -- blasts scatter the pebbles and twigs lying about
    if world.props then world.props:blast(x, y, radius, 180 + math.min(200, (base or 10) * 4)) end
    return Combat.area(world, x, y, radius, base, o)
end

-- Lightning that jumps between up to `jumps` nearby enemies.
function Combat.chain(world, from, jumps, range, base, opts)
    local visited = { [from] = true }
    local cur = from
    local hits = 0
    for _ = 1, jumps do
        local best, bestD = nil, range * range
        local list, n = world:queryEnemies(cur.x, cur.y, range)
        for i = 1, n do
            local e = list[i]
            if not visited[e] and not e.dead and not e.hidden then
                local dx, dy = e.x - cur.x, e.y - cur.y
                local d = dx * dx + dy * dy
                if d < bestD then best, bestD = e, d end
            end
        end
        if not best then break end
        visited[best] = true
        world:addFx({ kind = "bolt", x = cur.x, y = cur.y, x2 = best.x, y2 = best.y, life = 0.15, color = (opts and opts.color) or { 0.6, 0.9, 1 } })
        Combat.damage(world, best, base, opts)
        cur = best
        hits = hits + 1
    end
    if hits > 0 then Audio.play("zap") end
    return hits
end

return Combat
