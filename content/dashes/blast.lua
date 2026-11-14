-- Blast-off (bombardier): detonates its spray chamber, hurting everything around, and the
-- recoil launches it the opposite way to where you're pointing.
-- params: damage (18), radius (38), distance (110)
local Combat = require("src.game.combat")

return {
    name = "Blast-off",
    description = "Detonates a burst of boiling spray that hurts everything around you, and the blast flings you away from where you point.",
    start = function(player, world, dx, dy, params, px, py)
        local r = (params.radius or 38) * (1 + player.stats:get("area") / 100)
        Combat.explode(world, player.x, player.y, r, params.damage or 18, { color = { 1, 0.9, 0.55 }, knockback = 200 })
        local ax, ay = px - player.x, py - player.y
        local l = math.sqrt(ax * ax + ay * ay)
        if l < 1 then ax, ay, l = player.aimX, player.aimY, 1 end
        player:lunge(-ax / l, -ay / l, params.distance or 110, 1.2)
        player.dashHop = 14
        world.particles:burst(player.x, player.y, 10, { { 1, 1, 0.9 }, { 0.9, 0.85, 0.75 } }, 90, 60, { glow = true, grav = -20 })
    end,
}
