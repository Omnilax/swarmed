-- Chemical grenade (bombardier): lobs a pressurised blob where you point; it lands and explodes.
-- params: damage, cooldown, range (150), radius (blast, 42), color,
--         cluster (bomblets scattered by the blast, 0), burn ({dps, seconds}: a scalding pool left behind)
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

local GRAV = 320

return {
    name = "Chemical Grenade",
    range = function(params) return params.range or 150 end,
    fire = function(player, world, ax, ay, params, px, py)
        local range = params.range or 150
        local tx, ty = px or player.x + ax * range, py or player.y + ay * range
        local dx, dy = tx - player.x, ty - player.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d > range then tx, ty, d = player.x + dx / d * range, player.y + dy / d * range, range end
        local T = 0.45 + d / 500
        local z0 = 8
        local area = 1 + player.stats:get("area") / 100
        world.hazards:friendlyShot({ x = player.x, y = player.y, z = z0, vx = (tx - player.x) / T, vy = (ty - player.y) / T,
            vz = (1 - z0 + GRAV * T * T / 2) / T, grav = GRAV, r = 3, damage = 0, life = T + 0.2, color = { 1, 0.8, 0.3 },
            bomb = true, lob = nil,
            onEnd = function(w, s)
                Combat.explode(w, s.x, s.y, (params.radius or 42) * area, params.damage, { color = { 1, 0.85, 0.4 }, knockback = 220 })
                w.particles:burst(s.x, s.y, 12, { { 1, 1, 0.85 }, { 0.9, 0.85, 0.75 } }, 120, 80, { glow = true, grav = -20 })
                if params.burn then
                    require("src.game.itemfx").patch(w, { x = s.x, y = s.y, r = (params.radius or 42) * area * 0.7, life = params.burn[2],
                        dps = params.burn[1], color = { 1, 0.6, 0.2 } })
                end
                -- bomblets: little lobs that pop a moment later around the blast
                for i = 1, math.floor(params.cluster or 0) do
                    local a, d = i / params.cluster * math.pi * 2 + love.math.random() * 0.5, 30 + love.math.random() * 25
                    local bx, by = s.x + math.cos(a) * d, s.y + math.sin(a) * d
                    w.hazards:friendlyShot({ x = s.x, y = s.y, z = 2, vx = (bx - s.x) / 0.4, vy = (by - s.y) / 0.4, vz = 60, grav = 300,
                        r = 2, damage = 0, life = 0.42, color = { 1, 0.7, 0.3 }, bomb = true,
                        onEnd = function(w2, b)
                            Combat.explode(w2, b.x, b.y, 20 * area, params.damage * 0.4, { color = { 1, 0.7, 0.3 }, knockback = 120, procDepth = 1 })
                        end })
                end
            end })
        Audio.play("dash", { pitch = 0.8 })
    end,
}
