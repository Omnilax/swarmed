-- Ball ride (dung beetle): once the dung ball is bigger than the beetle, hold Shift to climb on
-- top and ride it, burning stamina (src/game/stamina.lua), like the millipede's ball roll. The
-- ball rolls faster than the beetle walks, flattens the ants it runs into (harder the bigger
-- it is) and keeps growing. No bashing or throwing from up there.
-- params: stamina (2.2 s), regen (1/s), speed (x walk speed, 1.5), damage (per bump at a
--         radius-10 ball, 6), knockback (190), every (seconds before the same ant is bumped
--         again, 0.4), minBall (ball radius needed over the beetle's own, 1)
local Stamina = require("src.game.stamina")
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

local function ball(player) return player.dung end

return Stamina.mode({
    name = "Ball Ride",
    description = "Once the ball is bigger than you, hold to climb on and ride it: faster, and it flattens every ant it rolls into.",
    speed = 1.5,
    iframes = 0.2,
    canEnter = function(player, params)
        local d = ball(player)
        return d ~= nil and d.r >= player.radius + (params.minBall or 1)
    end,
    enter = function(player, world, params)
        local d = ball(player)
        d.ride = true
        player.rideHit = setmetatable({}, { __mode = "k" })
        player.liftZ = d.r * 1.4
        world.particles:burst(player.x, player.y, 6, { { 0.5, 0.36, 0.2 } }, 60, 30, { grav = 200 })
        Audio.play("equip", { pitch = 0.7 })
    end,
    tick = function(player, world, dt, params)
        local d = ball(player)
        if not d then return end
        player.liftZ = d.r * 1.4
        player.attack.timer = math.max(player.attack.timer, 0.05)
        if player.secondary then player.secondary.timer = math.max(player.secondary.timer, 0.05) end
        local sp = math.sqrt((player.vx or 0) ^ 2 + (player.vy or 0) ^ 2)
        if sp < 20 then return end
        local now = world.time
        for _, e in ipairs(Combat.collect(world, player.x, player.y, d.r + 3)) do
            if (player.rideHit[e] or -1) < now and e.z < 6 then
                player.rideHit[e] = now + (params.every or 0.4)
                local nx, ny = e.x - player.x, e.y - player.y
                local l = math.sqrt(nx * nx + ny * ny) + 0.001
                Combat.damage(world, e, (params.damage or 6) * d.r / 10, { knockback = params.knockback or 190,
                    kbx = nx / l + player.vx / sp * 0.6, kby = ny / l + player.vy / sp * 0.6 })
                world.particles:burst(e.x, e.y, 2, { { 0.4, 0.28, 0.14 } }, 40, 20, { grav = 200 })
            end
        end
    end,
    exit = function(player, world)
        local d = ball(player)
        if d then d.ride = nil end
        player.rideHit, player.liftZ = nil, nil
        player.iframes = math.max(player.iframes, 0.2)
    end,
})
