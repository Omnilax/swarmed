-- Leap slam (tarantula): springs up on all eight legs and comes crashing down where you're
-- heading, flattening and dazing the ants it lands among. A jump, so it's untouchable for
-- nearly the whole leap.
-- params: distance (80), speed (x normal dash speed, 0.85), hop (height, 16), damage (landing, 14),
--         radius (36), stun (seconds dazed, 0.6), knockback (200)
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Leap Slam",
    description = "Leap up and crash down on the ants ahead, flattening and dazing everything you land among.",
    jump = true,
    start = function(player, world, dx, dy, params)
        player:lunge(dx, dy, params.distance or 80, params.speed or 0.85)
        player.dashHop = params.hop or 16
        player.leapT = player.dashT
        world.particles:burst(player.x, player.y, 6, { { 0.7, 0.62, 0.52 } }, 60, 10, { grav = 220 })
    end,
    update = function(player, world, dt, params)
        if not player.leapT or player.dashT > dt then return end
        player.leapT = nil
        local r = (params.radius or 36) * (1 + player.stats:get("area") / 100)
        local hits = Combat.area(world, player.x, player.y, r, params.damage or 14,
            { knockback = params.knockback or 200, stun = params.stun or 0.6 })
        world:addFx({ kind = "ring", x = player.x, y = player.y, r = r, life = 0.25, color = { 1, 0.6, 0.3 } })
        world.particles:burst(player.x, player.y, 14, { { 0.7, 0.62, 0.52 }, { 0.5, 0.42, 0.36 } }, 100, 40, { grav = 260 })
        world.camera:shake(0.1 + math.min(0.15, hits * 0.006))
        Audio.play("hit", { pitch = 0.55 })
        player.iframes = math.max(player.iframes, 0.12)
    end,
}
