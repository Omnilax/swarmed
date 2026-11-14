-- Stealth (assassin bug): hold Shift to go invisible, burning stamina (src/game/stamina.lua).
-- Cloaked (player.cloakT) the ants lose track of it and stop biting, it creeps a little faster,
-- and every attack from the shadows hits far harder (player.stealthMul, read by its attacks).
-- Attacking doesn't break the cloak, but each strike costs a bite of stamina.
-- params: stamina (4 s), regen (0.8/s), speed (x walk speed, 1.15), bonus (damage x while
--         cloaked, 2.5), strikeCost (stamina per attack while cloaked, 0.3)
local Stamina = require("src.game.stamina")
local Audio = require("src.core.audio")

local SHIMMER = { { 0.7, 0.75, 0.9 }, { 0.5, 0.5, 0.65 } }

return Stamina.mode({
    name = "Stealth",
    description = "Hold to turn invisible: the ants lose you, and your stabs and shoves from the shadows hit far harder.",
    speed = 1.15,
    iframes = 0.15,
    enter = function(player, world, params)
        player.stealthId = {}
        player.cloakT = player.stealthId
        player.alpha = 0.25
        player.stealthMul = params.bonus or 2.5
        player.stealthSwings = (player.attack and player.attack.timer or 0)
        world.particles:burst(player.x, player.y, 10, SHIMMER, 60, 30, { grav = -20 })
        Audio.play("zap", { pitch = 1.6, volume = 0.35 })
    end,
    tick = function(player, world, dt, params)
        player.stealthMul = params.bonus or 2.5
        if player.cloakT ~= player.stealthId then player.cloakT = player.stealthId end
        -- each strike from the shadows costs a little stamina (attack timer jumps up on a swing)
        local t = (player.attack and player.attack.timer or 0) + (player.secondary and player.secondary.timer or 0)
        if t > (player.stealthSwings or 0) + 0.05 and Stamina.spend then Stamina.spend(player, params.strikeCost or 0.3, 0.3) end
        player.stealthSwings = t
        if love.math.random() < dt * 6 then
            world.particles:spawn(player.x + (love.math.random() - 0.5) * 10, player.y + (love.math.random() - 0.5) * 10, 3,
                0, 0, 8, 0.4, SHIMMER[1], 1, { grav = -15 })
        end
    end,
    exit = function(player, world)
        if player.cloakT == player.stealthId then player.cloakT = nil end
        player.stealthId, player.stealthMul, player.alpha, player.stealthSwings = nil, nil, nil, nil
        if not player.dead then world.particles:burst(player.x, player.y, 8, SHIMMER, 50, 30, { grav = -20 }) end
    end,
})
