-- Run (tiger beetle): hold Shift to sprint flat out, burning stamina (src/game/stamina.lua).
-- Ants you run into get clipped and knocked aside, which is how you break out of a crowd.
-- params: stamina (2.4 s), regen (1/s), speed (x walk speed, 1.6), ram (damage per clip, 3),
--         knockback (130), every (seconds before the same ant can be clipped again, 0.5)
local Stamina = require("src.game.stamina")
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return Stamina.mode({
    name = "Run",
    description = "Hold to sprint flat out, burning stamina. Ants you run into are clipped and knocked aside.",
    speed = 1.6,
    enter = function(player, world, params)
        player.runHit = setmetatable({}, { __mode = "k" })
        player.runGhostT = 0
        world.particles:burst(player.x, player.y, 6, { { 0.72, 0.66, 0.55 } }, 70, 20, { grav = 200 })
        Audio.play("dash", { pitch = 1.5, volume = 0.6 })
    end,
    tick = function(player, world, dt, params)
        if not player.moving then return end
        local now = world.time
        local vx, vy = player.vx or 0, player.vy or 0
        local l = math.sqrt(vx * vx + vy * vy) + 0.001
        for _, e in ipairs(Combat.collect(world, player.x, player.y, player.radius + 3)) do
            if (player.runHit[e] or -1) < now then
                player.runHit[e] = now + (params.every or 0.5)
                -- knocked to whichever side of your path it was on
                local sx, sy = -vy / l, vx / l
                if (e.x - player.x) * sx + (e.y - player.y) * sy < 0 then sx, sy = -sx, -sy end
                Combat.damage(world, e, params.ram or 3, { knockback = params.knockback or 130, kbx = sx + vx / l * 0.4, kby = sy + vy / l * 0.4 })
            end
        end
        -- afterimages and kicked-up dust
        player.runGhostT = (player.runGhostT or 0) - dt
        if player.runGhostT <= 0 then
            player.runGhostT = 0.05
            player.ghosts[#player.ghosts + 1] = { x = player.x, y = player.y, wangle = player.wangle, anim = player.anim, t = 0.08 }
            world.particles:spawn(player.x, player.y, 1, -vx * 0.1, -vy * 0.1, 12, 0.3, { 0.65, 0.6, 0.52 }, 1, { grav = 80 })
        end
    end,
    exit = function(player) player.runHit = nil end,
})
