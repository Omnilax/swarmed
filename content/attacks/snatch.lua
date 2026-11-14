-- Snatch (mantis): its raptorial forelegs shoot out and snap shut on up to `grabs` ants in front.
-- Hold right click to munch on them (each bite hurts them and heals you); let go to fling the
-- survivors out in a fan where you point. A quick tap snatches and flings at once.
-- params: damage (fling impact), cooldown, reach (52), grabs (3), bite (damage per bite, 6),
--         heal (hp per bite, 2), munch (max hold, 1.6 s), distance (fling, 110)
local Combat = require("src.game.combat")
local Grab = require("src.game.grab")
local Audio = require("src.core.audio")
local util = require("src.core.util")

return {
    name = "Snatch",
    range = function(params) return params.reach or 52 end,
    fire = function(player, world, ax, ay, params)
        local reach = (params.reach or 52) * (1 + player.stats:get("area") / 200)
        local ang = math.atan2(ay, ax)
        local cands = Combat.collect(world, player.x, player.y, reach, function(e, dx, dy)
            return not e.held and not e.def.boss and math.abs(util.angleDiff(ang, math.atan2(dy, dx))) < 0.55
        end)
        table.sort(cands, function(a, b)
            return (a.x - player.x) ^ 2 + (a.y - player.y) ^ 2 < (b.x - player.x) ^ 2 + (b.y - player.y) ^ 2
        end)
        world:addFx({ kind = "stab", x = player.x, y = player.y, x2 = player.x + ax * reach, y2 = player.y + ay * reach, life = 0.08, color = { 0.75, 1, 0.5 } })
        world:addFx({ kind = "stab", x = player.x - ay * 4, y = player.y + ax * 4, x2 = player.x + ax * reach * 0.9, y2 = player.y + ay * reach * 0.9, life = 0.08, color = { 0.75, 1, 0.5 } })
        player.lungeT = 0.18
        if #cands == 0 then Audio.play("dash", { pitch = 1.6 }) return end
        local held = {}
        for i = 1, math.min(params.grabs or 3, #cands) do held[#held + 1] = Grab.hold(cands[i]) end
        player.carry = { kind = "snatch", list = held, t = 0, biteT = 0.15 }
        Audio.play("hit", { pitch = 1.3 })
    end,
    update = function(player, world, dt, params, down, px, py)
        local c = player.carry
        if not c or c.kind ~= "snatch" then return end
        c.t = c.t + dt
        -- held up in the forelegs, wriggling
        local fx, fy = math.cos(player.wangle), math.sin(player.wangle)
        local alive = {}
        for i, h in ipairs(c.list) do
            if Grab.valid(h) then
                local side = (i - (#c.list + 1) / 2) * 5
                Grab.place(h, player.x + fx * 11 - fy * side, player.y + fy * 11 + fx * side, 6 + math.sin(c.t * 25 + i) * 1, player.wangle + math.sin(c.t * 30 + i) * 0.4)
                alive[#alive + 1] = h
            end
        end
        c.list = alive
        if #alive == 0 then player.carry = nil return end
        if down and c.t < (params.munch or 1.6) then
            -- munch
            c.biteT = c.biteT - dt
            if c.biteT <= 0 then
                c.biteT = 0.3
                local h = alive[love.math.random(#alive)]
                Combat.damage(world, h.e, params.bite or 6, { knockback = 0, noCrit = true, dot = true })
                player:heal(params.heal or 2)
                world.particles:burst(h.e.x, h.e.y, 4, { { 0.55, 0.75, 0.3 }, { 0.3, 0.25, 0.2 } }, 40, 30)
                Audio.play("hit", { pitch = 0.9 + love.math.random() * 0.3, volume = 0.5 })
            end
            return
        end
        -- fling the survivors out in a fan
        local dx, dy, d = util.normalize(px - player.x, py - player.y)
        if d < 1 then dx, dy = player.aimX, player.aimY end
        local base = math.atan2(dy, dx)
        local n = #alive
        for i, h in ipairs(alive) do
            local a = base + (i - (n + 1) / 2) * 0.35
            local speed = 380
            Grab.fling(world, h, math.cos(a) * speed, math.sin(a) * speed, (params.distance or 110) / speed,
                { damage = params.damage * 0.5, landDamage = params.damage * 0.6, selfDamage = params.damage, radius = 22,
                  height = 12, spin = 20, color = { 0.75, 1, 0.5 } })
        end
        player.wangle = base
        player.lungeT = 0.18
        player.carry = nil
    end,
}
