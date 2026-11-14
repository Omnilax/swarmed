-- Tail flick (scorpion): springs backwards away from where you're aiming, and as it leaves
-- the tail lashes forward through the spot it just left, stinging the ants that were on it.
-- Back off and punish in one move, made for keeping the sting at its best range.
-- params: distance (70), speed (x normal dash speed, 1.1), hop (6), sting (damage, 14),
--         reach (sting length, 70), width (5), poison ({ dps, seconds }, { 6, 3 })
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Tail Flick",
    description = "Spring backwards away from your aim, lashing your tail forward through the spot you left to sting the ants on it.",
    start = function(player, world, dx, dy, params)
        local ax, ay = player.aimX, player.aimY
        local x0, y0 = player.x, player.y
        local reach = params.reach or 70
        for _, e in ipairs(Combat.collectLine(world, x0, y0, x0 + ax * reach, y0 + ay * reach, params.width or 5)) do
            Combat.damage(world, e, params.sting or 14, { knockback = 120, kbx = ax, kby = ay, poison = params.poison or { 6, 3 } })
        end
        world:addFx({ kind = "stab", x = x0, y = y0, x2 = x0 + ax * reach, y2 = y0 + ay * reach, z = 6, life = 0.16, w = 2, color = { 0.8, 1, 0.4 } })
        player:lunge(-ax, -ay, params.distance or 70, params.speed or 1.1)
        player.dashHop = params.hop or 6
        Audio.play("hit", { pitch = 1.3, volume = 0.7 })
    end,
}
