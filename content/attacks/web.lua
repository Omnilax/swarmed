-- Orb weaver web: flings a ball of silk that bursts into a web where it lands. Ants in the web
-- are slowed to a crawl; the impact hurts everything there.
-- params: damage, cooldown, range (90), radius (web size, 30), slow (0.3), duration (4), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Web Shot",
    range = function(params, player) return params.range or 90 end,
    fire = function(player, world, ax, ay, params)
        local target = world:nearestEnemy(player.x + ax * 40, player.y + ay * 40, params.range or 90)
        local dist = params.range or 90
        if target then dist = math.min(dist, math.sqrt((target.x - player.x) ^ 2 + (target.y - player.y) ^ 2)) end
        local sp = 280
        local area = 1 + player.stats:get("area") / 100
        world.hazards:friendlyShot({ x = player.x, y = player.y, z = 5, vx = ax * sp, vy = ay * sp, r = 3,
            damage = params.damage * 0.5, life = dist / sp, color = { 0.95, 0.95, 0.9 }, pierce = 0,
            onEnd = function(w, s)
                local r = (params.radius or 30) * area
                Combat.area(w, s.x, s.y, r, params.damage, { knockback = 20, slow = { params.slow or 0.3, 1 } })
                w.hazards:addZone({ kind = "web", web = true, x = s.x, y = s.y, r = r, life = params.duration or 4,
                    enemySlow = params.slow or 0.3, color = { 0.95, 0.95, 0.9 } })
                w:addFx({ kind = "ring", x = s.x, y = s.y, r = r, life = 0.15, color = { 1, 1, 1 } })
            end })
        Audio.play("dash", { pitch = 2.2 })
    end,
}
