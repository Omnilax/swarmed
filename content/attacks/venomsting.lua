-- Venom strike (scorpion tail, jumping spider fangs): a short, aimed stab that pumps venom into
-- every ant in a narrow line. Venom keeps hurting for a few seconds.
-- params: damage, cooldown, range (60), width (6), poison ({dps, seconds}, {8, 4}), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Venom Strike",
    range = function(params) return params.range or 60 end,
    fire = function(player, world, ax, ay, params)
        local reach = (params.range or 60) * (1 + player.stats:get("area") / 100)
        local x2, y2 = player.x + ax * reach, player.y + ay * reach
        for _, e in ipairs(Combat.collectLine(world, player.x, player.y, x2, y2, params.width or 6)) do
            Combat.damage(world, e, params.damage, { knockback = 60, kbx = ax, kby = ay, poison = params.poison or { 8, 4 } })
            world.particles:burst(e.x, e.y, 3, { { 0.6, 1, 0.3 } }, 40, 30, { glow = true })
        end
        world:addFx({ kind = "stab", x = player.x, y = player.y, x2 = x2, y2 = y2, life = 0.15, color = params.color or { 0.6, 1, 0.3 } })
        Audio.play("zap", { pitch = 0.7 })
    end,
}
