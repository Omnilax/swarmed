-- Leaf Sway (mantis): a mantis rocks like a leaf in the wind before it strikes. A quick sidestep
-- across your aim (the side you're steering toward, else alternating), still facing the ants,
-- and the next Twin Scythes strike within `primed` seconds is a sure critical hit on both slashes.
-- params: distance (58), speed (x normal dash speed, 1.2), charges (2), primed (seconds, 1.0)
local util = require("src.core.util")
local Audio = require("src.core.audio")

return {
    name = "Leaf Sway",
    description = "Sway sideways across your aim, still facing the ants. Your next strike within a second always crits.",
    start = function(player, world, dx, dy, params)
        local ax, ay = player.aimX, player.aimY
        -- Perpendicular to the aim; pick the side the move input leans toward.
        local sx, sy = -ay, ax
        local side = dx * sx + dy * sy
        if math.abs(side) < 0.2 then
            player.swaySide = -(player.swaySide or -1)
            side = player.swaySide
        end
        if side < 0 then sx, sy = -sx, -sy end
        sx, sy = util.normalize(sx + ax * 0.15, sy + ay * 0.15)
        player:lunge(sx, sy, params.distance or 58, params.speed or 1.2)
        player.dashHop = 3
        local id = {}
        player.swayPrimed = id
        player:after(player.dashT + (params.primed or 1.0), function(p) if p.swayPrimed == id then p.swayPrimed = nil end end)
        world.particles:burst(player.x, player.y, 5, { { 0.6, 0.9, 0.4 }, { 0.45, 0.75, 0.3 } }, 40, 10, { grav = 30 })
        Audio.play("dash", { pitch = 1.9, volume = 0.45 })
    end,
}
