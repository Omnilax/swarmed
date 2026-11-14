-- Scurry (hissing roach): a flat, quick dart. It startles the ants it bolts away from (a puff
-- that dazes the ones touching it) and comes out of it still running: a short burst of speed
-- afterwards. Three charges, so it can zig-zag out of almost anything.
-- params: distance (60), speed (x normal dash speed, 1.3), charges (3), startle (daze seconds
--         on the ants touching you as you go, 0.4), radius (startle reach, 20), burst (move
--         speed x afterwards, 1.35), burstTime (0.6)
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Scurry",
    description = "A flat, quick dart that startles the ants touching you, and leaves you running faster for a moment. Three charges.",
    start = function(player, world, dx, dy, params)
        local r = params.radius or 20
        for _, e in ipairs(Combat.collect(world, player.x, player.y, r)) do
            Combat.damage(world, e, 1, { knockback = 110, kbx = e.x - player.x, kby = e.y - player.y, stun = params.startle or 0.4, noCrit = true })
        end
        world.particles:burst(player.x, player.y, 6, { { 0.85, 0.8, 0.7 } }, 60, 15, { grav = 60 })
        player:lunge(dx, dy, params.distance or 60, params.speed or 1.3)
        local id = {}
        player.scurryId = id
        player:after(player.dashT, function(p)
            if p.scurryId ~= id then return end
            p.moveMul = params.burst or 1.35
            p:after(params.burstTime or 0.6, function(q) if q.scurryId == id then q.moveMul, q.scurryId = nil, nil end end)
        end)
        Audio.play("dash", { pitch = 1.6, volume = 0.5 })
    end,
}
