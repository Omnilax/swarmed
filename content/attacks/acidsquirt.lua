-- Acid squirt (vinegaroon): the whip tail arches forward and sprays a fine jet of vinegar.
-- Acid burns a little over time and eats the shell: corroded ants take extra damage from every
-- hit for a while. Every few squirts the mist hangs in the air as a stinging cloud.
-- params: damage, cooldown, range (100), drops (3), spread (0.25), corrode ({ mul, time }),
--         burn ({ dps, time }), cloudEvery (5), cloudRadius (26), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Acid Squirt",
    range = function(params, player) return (params.range or 100) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local range = (params.range or 100) * (1 + player.stats:get("area") / 100)
        local base = math.atan2(ay, ax)
        local n, spread = params.drops or 3, params.spread or 0.25
        local c = params.color or { 0.8, 1, 0.45 }
        local atk = player.attack
        atk.count = (atk.count or 0) + 1
        local cloud = atk.count % (params.cloudEvery or 5) == 0
        -- the jet leaves from the tail tip, arched up over the back
        local ox, oy = player.x - ax * 2, player.y - ay * 2
        for i = 1, n do
            local a = base + ((i - 1) / math.max(1, n - 1) - 0.5) * spread + (love.math.random() - 0.5) * 0.06
            local sp = 300 * (0.9 + love.math.random() * 0.2)
            local last = i == n
            world.hazards:friendlyShot({ x = ox, y = oy, z = 12, vx = math.cos(a) * sp, vy = math.sin(a) * sp, vz = 10, grav = 60,
                r = 2.5, damage = params.damage, life = range / sp, color = c, pierce = 1, knockback = 20,
                corrode = params.corrode or { 1.35, 3 }, poison = params.burn,
                onEnd = (cloud and last) and function(w, s)
                    local r = (params.cloudRadius or 26) * (1 + w.player.stats:get("area") / 100)
                    w.hazards:addZone({ kind = "acidcloud", x = s.x, y = s.y, r = r, life = 2.2, t = 0,
                        update = function(ww, z, dt)
                            z.tick = (z.tick or 0) + dt
                            if z.tick < 0.4 then return end
                            z.tick = 0
                            for _, e in ipairs(Combat.collect(ww, z.x, z.y, z.r)) do
                                Combat.damage(ww, e, params.damage * 0.5, { noCrit = true, dot = true, corrode = params.corrode or { 1.35, 3 } })
                            end
                        end,
                        draw = function(z, sx, sy, fade)
                            local lg = love.graphics
                            for k = 0, 4 do
                                local a = k * 1.26 + z.t * 0.8
                                lg.setColor(c[1], c[2], c[3], 0.12 * fade)
                                lg.ellipse("fill", sx + math.cos(a) * z.r * 0.4, sy + math.sin(a) * z.r * 0.2 - 3, z.r * 0.6, z.r * 0.32)
                            end
                        end })
                end or nil })
        end
        world.particles:burst(ox, oy, 4, { { 0.85, 1, 0.6 } }, 50, 30, { glow = true, grav = 50 })
        Audio.play("dash", { pitch = 2.1, volume = 0.5 })
    end,
}
