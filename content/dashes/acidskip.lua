-- Acid skip (vinegaroon): a double dash. The first scuttle opens a short window to scuttle
-- again in any direction for free, and each push-off squirts a puff of vinegar behind it that
-- corrodes and shoves the ants that were on you.
-- params: distance (each dash, 70), speed (x normal dash speed, 1.1), window (seconds to use
--         the second dash, 0.7), damage (puff, 5), radius (puff, 26), corrode, charges
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

local ACID = { 0.8, 1, 0.45 }

local function puff(player, world, params)
    local r = (params.radius or 26) * (1 + player.stats:get("area") / 100)
    for _, e in ipairs(Combat.collect(world, player.x, player.y, r)) do
        local dx, dy = e.x - player.x, e.y - player.y
        local l = math.sqrt(dx * dx + dy * dy) + 0.001
        Combat.damage(world, e, params.damage or 5, { knockback = 140, kbx = dx / l, kby = dy / l, corrode = params.corrode or { 1.35, 3 } })
    end
    world:addFx({ kind = "ring", x = player.x, y = player.y, r = r, life = 0.25, color = ACID })
    world.particles:burst(player.x, player.y, 8, { ACID, { 0.6, 0.8, 0.3 } }, 70, 30, { glow = true, grav = 120 })
    Audio.play("zap", { pitch = 1.8, volume = 0.35 })
end

return {
    name = "Acid Skip",
    description = "A double dash: scuttle, then scuttle again any way you like. Each push-off leaves a puff of vinegar that corrodes the ants you left behind.",
    start = function(player, world, dx, dy, params)
        puff(player, world, params)
        player:lunge(dx, dy, params.distance or 70, params.speed or 1.1)
        local s = player.skip
        if s and s.t > 0 then
            player.skip = nil       -- that was the second
        else
            player.skip = { t = params.window or 0.7 }   -- the first: the second hop is free
        end
    end,
    free = function(player) return player.skip ~= nil and player.skip.t > 0 end,
    tick = function(player, world, dt, params)
        local s = player.skip
        if not s then return end
        s.t = s.t - dt
        if s.t <= 0 then player.skip = nil end
    end,
}
