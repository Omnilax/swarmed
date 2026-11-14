-- Scorpion: two quick pincer snaps in front, then the tail stings far forward in a line.
-- params: damage, cooldown, radius (pincers, 34), stingRange (80), stingMult (2.5), knockback, color,
--         combo (strikes per cycle, the last is the sting, 3)
local Combat = require("src.game.combat")
local util = require("src.core.util")
local Audio = require("src.core.audio")

return {
    name = "Pinch & Sting",
    range = function(params, player) return (params.stingRange or 80) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local area = 1 + player.stats:get("area") / 100
        local atk = player.attack
        local cycle = math.max(2, params.combo or 3)
        atk.combo = (atk.combo or 0) % cycle + 1
        local ang = math.atan2(ay, ax)
        if atk.combo < cycle then
            local radius = (params.radius or 34) * area
            local side = atk.combo == 1 and -0.35 or 0.35
            for _, e in ipairs(Combat.collect(world, player.x, player.y, radius, function(e, dx, dy)
                return math.abs(util.angleDiff(ang + side, math.atan2(dy, dx))) <= 0.8 end)) do
                local nx, ny = util.normalize(e.x - player.x, e.y - player.y)
                Combat.damage(world, e, params.damage, { knockback = params.knockback or 60, kbx = nx, kby = ny, poison = params.poison })
            end
            world:addFx({ kind = "arc", x = player.x, y = player.y, r = radius, a = ang + side, arc = 1.6, life = 0.1, color = params.color })
        else
            -- the sting: a long thrust that pierces a line of ants
            local reach = (params.stingRange or 80) * area
            local x2, y2 = player.x + ax * reach, player.y + ay * reach
            for _, e in ipairs(Combat.collectLine(world, player.x, player.y, x2, y2, 5)) do
                Combat.damage(world, e, params.damage * (params.stingMult or 2.5), { knockback = 140, kbx = ax, kby = ay, poison = params.stingPoison or params.poison })
            end
            world:addFx({ kind = "stab", x = player.x, y = player.y, x2 = x2, y2 = y2, life = 0.14, color = { 0.8, 1, 0.4 } })
            Audio.play("zap", { pitch = 0.8 })
            world.camera:shake(0.08)
        end
    end,
}
