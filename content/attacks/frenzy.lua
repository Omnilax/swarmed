-- Frenzy (camel spider): a blur of speed. It darts from ant to ant, biting each one on the way,
-- hopping to the nearest fresh target up to `hops` times. Ants it bites bleed.
-- params: damage, cooldown, hops (5), range (how far each dart looks, 70), radius (bite, 18),
--         bleed ({ dps, time }), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

local HOP_TIME = 0.09

local function hop(player, world, params, left, bitten)
    -- next target: the closest ant not bitten yet, preferring ones ahead
    local best, bd = nil, (params.range or 70) ^ 2
    for _, e in ipairs(Combat.collect(world, player.x, player.y, params.range or 70)) do
        if not bitten[e] and not e.held then
            local d = (e.x - player.x) ^ 2 + (e.y - player.y) ^ 2
            if d < bd then best, bd = e, d end
        end
    end
    if not best then return end
    bitten[best] = true
    local dx, dy = best.x - player.x, best.y - player.y
    local d = math.sqrt(dx * dx + dy * dy) + 0.001
    local x0, y0 = player.x, player.y
    player:lunge(dx / d, dy / d, math.max(2, d - 6), (d - 6) / HOP_TIME / 420 + 0.01)
    player.dashT = HOP_TIME
    player.wangle = math.atan2(dy, dx)
    player:after(HOP_TIME, function(p, w)
        local r = (params.radius or 18) * (1 + p.stats:get("area") / 100)
        for _, e in ipairs(Combat.collect(w, p.x, p.y, r)) do
            local nx, ny = e.x - p.x, e.y - p.y
            Combat.damage(w, e, params.damage, { knockback = 60, kbx = nx, kby = ny, poison = params.bleed })
        end
        w:addFx({ kind = "streak", x = x0, y = y0, x2 = p.x, y2 = p.y, life = 0.2, w = 3, color = params.color or { 1, 0.85, 0.55 } })
        w:addFx({ kind = "arc", x = p.x, y = p.y, r = r, a = p.wangle, arc = 2, life = 0.12, color = params.color or { 1, 0.85, 0.55 } })
        w.particles:burst(p.x, p.y, 5, { { 0.82, 0.72, 0.52 }, { 0.6, 0.5, 0.35 } }, 70, 30, { grav = 250 })
        Audio.play("hit", { pitch = 1.4 + love.math.random() * 0.3 })
        p.lungeT = 0.18
        if left > 1 then hop(p, w, params, left - 1, bitten) end
    end)
end

return {
    name = "Frenzy",
    range = function(params) return params.range or 70 end,
    fire = function(player, world, ax, ay, params)
        Audio.play("dash", { pitch = 1.8 })
        hop(player, world, params, params.hops or 5, {})
    end,
}
