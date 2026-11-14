-- Liquefy (assassin bug): plunges the rostrum into the nearest ant in front and pumps it full
-- of digestive saliva. Pinned on the beak, the ant shrivels as you drink it, healing you with
-- every gulp, then bursts in a spray of dissolving juices that eats into the ants around.
-- You can walk while you feed. Bosses and queens are too big to lift: they take a deep
-- draining stab instead.
-- params: damage (per gulp), cooldown, reach (50), gulps (6), gulpTime (0.18 s),
--         heal (hp per gulp, 3), burst (splash damage, 14), burstRadius (30),
--         chain (after a kill the rostrum stabs into up to this many more ants nearby, 0)
local Combat = require("src.game.combat")
local Grab = require("src.game.grab")
local Audio = require("src.core.audio")
local util = require("src.core.util")

local function burst(player, world, e, params)
    local r = (params.burstRadius or 30) * (1 + player.stats:get("area") / 100)
    local x, y = e.x, e.y
    Combat.area(world, x, y, r, params.burst or 14, { knockback = 110, poison = { (params.burst or 14) * 0.3, 3 } })
    world:addFx({ kind = "ring", x = x, y = y, r = r, life = 0.25, color = { 0.95, 0.5, 0.3 } })
    world.particles:burst(x, y, 14, { { 0.9, 0.55, 0.25 }, { 0.75, 0.2, 0.1 }, { 1, 0.85, 0.5 } }, 110, 60, { stain = true, grav = 260 })
    world.pendingSplats[#world.pendingSplats + 1] = { kind = "splat", x, y, { 0.6, 0.35, 0.15 }, 6, 0, 0 }
    Audio.play("boom", { pitch = 1.4, volume = 0.7 })
end

return {
    name = "Liquefy",
    range = function(params) return params.reach or 50 end,
    fire = function(player, world, ax, ay, params)
        local reach = (params.reach or 50) * (1 + player.stats:get("area") / 200)
        local ang = math.atan2(ay, ax)
        local best, bestD
        for _, e in ipairs(Combat.collect(world, player.x, player.y, reach, function(e, dx, dy)
            return not e.held and math.abs(util.angleDiff(ang, math.atan2(dy, dx))) < 0.7 end)) do
            local d = (e.x - player.x) ^ 2 + (e.y - player.y) ^ 2
            if not bestD or d < bestD then best, bestD = e, d end
        end
        world:addFx({ kind = "stab", x = player.x, y = player.y, x2 = player.x + ax * reach, y2 = player.y + ay * reach, life = 0.12, w = 2, color = { 1, 0.4, 0.3 } })
        if not best then Audio.play("dash", { pitch = 1.7 }) return end
        if best.def.boss then
            -- too big to lift: one deep draining stab
            local dmg = Combat.damage(world, best, (params.damage or 6) * (params.gulps or 6) * 0.6, { knockback = 60, kbx = ax, kby = ay })
            player:heal(dmg * 0.4)
            Audio.play("hit", { pitch = 0.8 })
            return
        end
        player.carry = { kind = "liquefy", h = Grab.hold(best), t = 0, gulpT = params.gulpTime or 0.18, gulps = 0 }
        Audio.play("hit", { pitch = 1.2 })
    end,
    update = function(player, world, dt, params)
        local c = player.carry
        if not c or c.kind ~= "liquefy" then return end
        c.t = c.t + dt
        local e = c.h.e
        local fx, fy = math.cos(player.wangle), math.sin(player.wangle)
        if not Grab.valid(c.h) then player.carry = nil return end
        local k = c.gulps / (params.gulps or 6)
        e.scale = e.baseScale * (1 - 0.45 * k)
        Grab.place(c.h, player.x + fx * 15, player.y + fy * 15, 5 + math.sin(c.t * 30) * 0.6, player.wangle + math.sin(c.t * 22) * 0.3)
        c.gulpT = c.gulpT - dt
        if c.gulpT > 0 then return end
        c.gulpT = params.gulpTime or 0.18
        c.gulps = c.gulps + 1
        local last = c.gulps >= (params.gulps or 6)
        -- the final gulp always finishes it
        Combat.damage(world, e, last and math.max(params.damage or 6, e.hp * 10) or (params.damage or 6), { knockback = 0, noCrit = not last, dot = true })
        player:heal(params.heal or 3)
        world.particles:spawn(e.x, e.y, 6, -fx * 40, -fy * 40, 25, 0.4, { 0.9, 0.3, 0.2 }, 1, { glow = true, grav = 0 })
        Audio.play("hit", { pitch = 0.7 + k * 0.6, volume = 0.5 })
        if e.dead or last then
            burst(player, world, e, params)
            Grab.release(c.h)
            player.carry = nil
            -- chain feeding: straight on to the next ant in reach
            if (c.chained or 0) < (params.chain or 0) then
                local best, bestD
                for _, o in ipairs(Combat.collect(world, player.x, player.y, (params.reach or 50) + 10)) do
                    local d = (o.x - player.x) ^ 2 + (o.y - player.y) ^ 2
                    if not o.held and not o.def.boss and (not bestD or d < bestD) then best, bestD = o, d end
                end
                if best then
                    player.carry = { kind = "liquefy", h = Grab.hold(best), t = 0, gulpT = params.gulpTime or 0.18, gulps = 0, chained = (c.chained or 0) + 1 }
                    world:addFx({ kind = "stab", x = player.x, y = player.y, x2 = best.x, y2 = best.y, life = 0.12, w = 2, color = { 1, 0.4, 0.3 } })
                end
            end
        end
    end,
}
