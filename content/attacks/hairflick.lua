-- Hair flick (tarantula): hold right click and it kicks a stream of barbed hairs off its
-- abdomen toward where you point. Each hair is light and does little on its own, but they
-- itch: every ant they hit is slowed.
-- params: damage (per hair, 0.6), rate (seconds between hairs, 0.09), range (130), spread (0.22),
--         speed (300), slow ({ mul, seconds }), pierce (0), color
local Audio = require("src.core.audio")

return {
    name = "Hair Flick",
    manual = true,
    range = function(params) return params.range or 130 end,
    update = function(player, world, dt, params, held, px, py)
        player.hairT = math.max(0, (player.hairT or 0) - dt)
        if not held or player.stunT > 0 or player.blocking or player.hairT > 0 then return end
        player.hairT = params.rate or 0.07
        local ax, ay = px - player.x, py - player.y
        local l = math.sqrt(ax * ax + ay * ay)
        if l < 1 then ax, ay = player.aimX, player.aimY else ax, ay = ax / l, ay / l end
        player.aimX, player.aimY = ax, ay
        -- the skill tree's onSpecial procs and echoes see each hair as one use of the special
        player:releaseSecondary(ax, ay, px, py)
    end,
    fire = function(player, world, ax, ay, params)
        local range = (params.range or 130) * (1 + player.stats:get("area") / 100)
        local sp = params.speed or 300
        local a = math.atan2(ay, ax) + (love.math.random() - 0.5) * (params.spread or 0.22)
        -- kicked off the back end, arcing up over the body
        local x, y = player.x - ax * 4, player.y - ay * 4
        world.hazards:friendlyShot({ x = x, y = y, z = 7, vz = 20, grav = 40, vx = math.cos(a) * sp, vy = math.sin(a) * sp, r = 1,
            damage = params.damage or 2, life = range / sp, color = params.color or { 1, 0.6, 0.3 }, pierce = params.pierce or 0,
            knockback = 25, slow = params.slow or { 0.6, 1.2 }, poison = params.poison })
        if love.math.random() < 0.3 then Audio.play("hit", { pitch = 2.6, volume = 0.15 }) end
    end,
}
