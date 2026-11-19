-- Snip in Two (crab): the big claw seizes the nearest ant in reach, lifts it and snips it
-- clean in half. It dies on the spot and the two halves go spinning off to either side,
-- bowling through the crowd and spattering everything they hit. Queens and bosses are too
-- big to cut: they get a brutal crushing pinch instead. A pebble or twig is seized and flicked
-- out ahead.
-- params: damage (halves' impact), cooldown, reach (46), lift (s held before the snip, 0.18),
--         halves (how far they fly, 110), bossDamage (40), targets (ants snipped one after another, 1),
--         halfBurst (halves burst where they land, damage, 0), color
local Combat = require("src.game.combat")
local Grab = require("src.game.grab")
local Audio = require("src.core.audio")
local util = require("src.core.util")

local function snip(player, world, e, params)
    local fx, fy = math.cos(player.wangle), math.sin(player.wangle)
    local x, y = e.x, e.y
    local col = e.def.splat and util.hex(e.def.splat) or { 0.6, 0.75, 0.3 }
    -- the cut: a bright scissor flash and a gush
    world:addFx({ kind = "arc", x = x, y = y, r = 10, a = math.atan2(fy, fx) + math.pi / 2, arc = 2.6, life = 0.14, color = { 1, 1, 0.9 } })
    world.particles:burst(x, y, 14, { col, { 0.9, 0.9, 0.8 } }, 120, 70, { stain = true, grav = 300 })
    world:floatText(x, y, "SNIP!", { 1, 0.75, 0.6 }, true)
    local spr = e.def.sprite
    e.held = nil
    Combat.damage(world, e, e.hp * 100 + 100, { knockback = 0, noCrit = true, ignoreShield = true })
    -- two halves fly off to the sides
    local speed = 320
    for s = -1, 1, 2 do
        local vx, vy = -fy * s * speed + fx * 60, fx * s * speed + fy * 60
        world.hazards:friendlyShot({ x = x, y = y, z = 6, vx = vx, vy = vy, r = 4, damage = params.damage, life = (params.halves or 110) / speed,
            color = col, pierce = 5, knockback = 160, splat = true, grav = 40, vz = 30, half = spr,
            onEnd = (params.halfBurst or 0) > 0 and function(w, sh)
                Combat.explode(w, sh.x, sh.y, 24, params.halfBurst, { knockback = 140, color = col })
            end or nil })
    end
    world.camera:shake(0.12)
    Audio.play("hit", { pitch = 0.5 })
    Audio.play("zap", { pitch = 1.8, volume = 0.6 })
end

return {
    name = "Snip in Two",
    range = function(params) return params.reach or 46 end,
    fire = function(player, world, ax, ay, params)
        local reach = (params.reach or 46) * (1 + player.stats:get("area") / 200)
        local ang = math.atan2(ay, ax)
        local best, bestD
        for _, e in ipairs(Grab.collect(world, player.x, player.y, reach, function(e, dx, dy)
            return not e.held and math.abs(util.angleDiff(ang, math.atan2(dy, dx))) < 0.8 end)) do
            local d = (e.x - player.x) ^ 2 + (e.y - player.y) ^ 2
            if not bestD or d < bestD then best, bestD = e, d end
        end
        world:addFx({ kind = "stab", x = player.x, y = player.y, x2 = player.x + ax * reach, y2 = player.y + ay * reach, life = 0.1, w = 4, color = { 1, 0.6, 0.45 } })
        if not best then Audio.play("dash", { pitch = 1.5 }) return end
        if best.def.boss then
            Combat.damage(world, best, params.bossDamage or 40, { knockback = 80, kbx = ax, kby = ay })
            world.camera:shake(0.1)
            return
        end
        -- clicking again before the last snip finished: let the old catch go first
        if player.carry and player.carry.kind == "snip" then Grab.release(player.carry.h) end
        player.carry = { kind = "snip", h = Grab.hold(best), t = 0, left = (params.targets or 1) - 1 }
        Audio.play("hit", { pitch = 0.9 })
    end,
    update = function(player, world, dt, params)
        local c = player.carry
        if not c or c.kind ~= "snip" then return end
        if not Grab.valid(c.h) then player.carry = nil return end
        c.t = c.t + dt
        local fx, fy = math.cos(player.wangle), math.sin(player.wangle)
        local k = math.min(1, c.t / (params.lift or 0.18))
        Grab.place(c.h, player.x + fx * 16, player.y + fy * 16, 2 + k * 6, player.wangle + math.pi / 2 + math.sin(c.t * 40) * 0.3)
        if k >= 1 then
            local e = c.h.e
            player.carry = nil
            if e.isProp then
                -- a pebble or twig is too tough to cut: the claw flicks it out ahead instead
                local speed = 400
                Grab.fling(world, c.h, fx * speed, fy * speed, (params.halves or 110) / speed,
                    { damage = params.damage, landDamage = params.damage * 0.6, radius = 22, height = 10, spin = 16 })
                world.camera:shake(0.05)
                return
            end
            snip(player, world, e, params)
            -- more snips: seize the next ant in reach
            if c.left > 0 then
                local best, bestD
                for _, o in ipairs(Combat.collect(world, player.x, player.y, (params.reach or 46) + 6)) do
                    local d = (o.x - player.x) ^ 2 + (o.y - player.y) ^ 2
                    if not o.held and not o.def.boss and (not bestD or d < bestD) then best, bestD = o, d end
                end
                if best then player.carry = { kind = "snip", h = Grab.hold(best), t = 0.06, left = c.left - 1 } end
            end
        end
    end,
}
