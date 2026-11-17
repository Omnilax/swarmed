-- Grab & Stab (emperor scorpion): the pincers shoot out and each clamps an ant (up to one per
-- claw). Held up in front, they get stung by the tail over and over; every sting pumps venom
-- that splashes onto the ants around them. Hold right click to keep stinging (up to `stabs`),
-- let go and the scorpion slams whatever is left into the ground.
-- params: damage (per sting), cooldown, reach (44), stabs (max stings, 6), minStabs (3),
--         stabTime (0.2 s), splash (venom splash radius, 16), poison ({ dps, time }),
--         slam (slam damage, 20), grabs (ants held at once, 2), color
local Combat = require("src.game.combat")
local Grab = require("src.game.grab")
local Audio = require("src.core.audio")
local util = require("src.core.util")

local function slam(player, world, c, params)
    for _, h in ipairs(c.list) do
        if Grab.valid(h) then
            local e = h.e
            -- (a held pebble stays out of its own slam, then bounces off the ground)
            if not e.isProp then Grab.release(h) end
            Combat.explode(world, e.x, e.y, 22 * (1 + player.stats:get("area") / 100), params.slam or 20,
                { knockback = 160, color = { 0.6, 0.7, 1 } })
            if not e.dead then Combat.damage(world, e, params.slam or 20, { knockback = 40 }) end
            if e.isProp then
                Grab.release(h)
                e.z, e.vz = 0, 120
            end
        end
    end
    player.carry = nil
    player.lungeT = 0.18
end

return {
    name = "Grab & Stab",
    range = function(params) return params.reach or 44 end,
    fire = function(player, world, ax, ay, params)
        local reach = (params.reach or 44) * (1 + player.stats:get("area") / 200)
        local ang = math.atan2(ay, ax)
        local cands = Grab.collect(world, player.x, player.y, reach, function(e, dx, dy)
            return not e.held and not e.def.boss and math.abs(util.angleDiff(ang, math.atan2(dy, dx))) < 0.75
        end)
        table.sort(cands, function(a, b)
            return (a.x - player.x) ^ 2 + (a.y - player.y) ^ 2 < (b.x - player.x) ^ 2 + (b.y - player.y) ^ 2
        end)
        for s = -1, 1, 2 do
            world:addFx({ kind = "stab", x = player.x - ay * s * 5, y = player.y + ax * s * 5, x2 = player.x + ax * reach - ay * s * 7,
                y2 = player.y + ay * reach + ax * s * 7, life = 0.1, w = 3, color = { 0.6, 0.7, 1 } })
        end
        if #cands == 0 then
            -- nothing to grab: the claws snap shut on whatever is right in front
            Combat.area(world, player.x + ax * 20, player.y + ay * 20, 14, params.damage, { knockback = 120 })
            Audio.play("hit", { pitch = 0.8 })
            return
        end
        local held = {}
        for i = 1, math.min(params.grabs or 2, #cands) do held[i] = Grab.hold(cands[i]) end
        player.carry = { kind = "grabstab", list = held, t = 0, stabT = 0.12, stabs = 0, next = 1 }
        Audio.play("hit", { pitch = 0.7 })
    end,
    update = function(player, world, dt, params, down)
        local c = player.carry
        if not c or c.kind ~= "grabstab" then return end
        c.t = c.t + dt
        local fx, fy = math.cos(player.wangle), math.sin(player.wangle)
        local alive = {}
        for i, h in ipairs(c.list) do
            if Grab.valid(h) then
                local side = (i - (#c.list + 1) / 2) * 7
                Grab.place(h, player.x + fx * 17 - fy * side, player.y + fy * 17 + fx * side, 5 + math.sin(c.t * 28 + i) * 0.8,
                    player.wangle + math.sin(c.t * 34 + i) * 0.5)
                alive[#alive + 1] = h
            end
        end
        c.list = alive
        if #alive == 0 then player.carry = nil return end
        local maxStabs = params.stabs or 6
        if c.stabs >= maxStabs or (not down and c.stabs >= (params.minStabs or 3)) then
            slam(player, world, c, params)
            return
        end
        c.stabT = c.stabT - dt
        if c.stabT > 0 then return end
        c.stabT = params.stabTime or 0.2
        c.stabs = c.stabs + 1
        c.next = c.next % #alive + 1
        local e = alive[c.next].e
        -- the tail arcs over the back and drives the sting in
        world:addFx({ kind = "stab", x = player.x - fx * 8, y = player.y - fy * 8, x2 = e.x, y2 = e.y, z = 10, life = 0.12, w = 2, color = params.color or { 0.75, 1, 0.4 } })
        Combat.damage(world, e, params.damage, { knockback = 0, poison = params.poison })
        local r = (params.splash or 16) * (1 + player.stats:get("area") / 100)
        for _, o in ipairs(Combat.collect(world, e.x, e.y, r)) do
            if not o.held then
                local nx, ny = util.normalize(o.x - e.x, o.y - e.y)
                Combat.damage(world, o, params.damage * 0.4, { knockback = 50, kbx = nx, kby = ny, poison = params.poison, procDepth = 1 })
            end
        end
        world.particles:burst(e.x, e.y, 6, { { 0.7, 1, 0.3 }, { 0.5, 0.85, 0.2 } }, 60, 30, { glow = true })
        Audio.play("zap", { pitch = 1.1 + love.math.random() * 0.2, volume = 0.6 })
    end,
}
