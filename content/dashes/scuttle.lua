-- Sideways scuttle (crab): crabs run sideways, so the dash shoots you out to the side of where
-- you're facing (the side you're steering towards), knocking aside any ant you clip.
-- params: distance (80), speed (1.3), charges (2), ram (damage, 5), knockback (140)
local Combat = require("src.game.combat")
local util = require("src.core.util")

return {
    name = "Sideways Scuttle",
    description = "Scuttles sideways, crab style: shoots out to the left or right of where you face, bumping ants aside. Two charges.",
    start = function(player, world, dx, dy, params)
        -- perpendicular to the aim, on the side the stick / keys point to (or alternating)
        local sx, sy = -player.aimY, player.aimX
        local d = dx * sx + dy * sy
        if math.abs(d) < 0.2 then
            player.scuttleSide = -(player.scuttleSide or 1)
            d = player.scuttleSide
        end
        if d < 0 then sx, sy = -sx, -sy end
        player:lunge(sx, sy, params.distance or 80, params.speed or 1.3)
        player.dashHit = {}
        world.particles:burst(player.x, player.y, 6, { { 0.75, 0.68, 0.55 } }, 50, 30, { grav = 200 })
    end,
    update = function(player, world, dt, params)
        if not player.dashHit then return end
        for _, e in ipairs(Combat.collect(world, player.x, player.y, player.radius + 4)) do
            if not player.dashHit[e] then
                player.dashHit[e] = true
                local nx, ny = util.normalize(e.x - player.x, e.y - player.y)
                Combat.damage(world, e, params.ram or 5, { knockback = params.knockback or 140, kbx = nx, kby = ny })
            end
        end
    end,
}
