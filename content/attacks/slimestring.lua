-- Slime string (velvet worm): it squirts two jets of sticky slime from the papillae beside its
-- mouth. The strands fly through the whole crowd, gluing every ant they touch so it crawls.
-- A thin strand stays stretched along the shot for a moment.
-- params: damage (per strand, 3), cooldown, range (170), speed (340), slow ({ mul, seconds },
--         { 0.35, 3 }), jets (2), gap (radians between the jets, 0.08), color
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")

local SLIME = { 0.95, 0.92, 0.78 }

return {
    name = "Slime String",
    range = function(params, player) return (params.range or 170) * 0.8 * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local range = (params.range or 170) * (1 + player.stats:get("area") / 100)
        local sp = params.speed or 340
        local jets, gap = params.jets or 2, params.gap or 0.08
        local base = math.atan2(ay, ax)
        local color = params.color or SLIME
        for i = 1, jets do
            local a = base + (i - (jets + 1) / 2) * gap
            local x0, y0 = player.x + ax * 8, player.y + ay * 8
            local s = world.hazards:friendlyShot({ x = x0, y = y0, z = 4, vx = math.cos(a) * sp, vy = math.sin(a) * sp, r = 3,
                damage = params.damage or 3, life = range / sp, color = color, pierce = 999, knockback = 10,
                slow = params.slow or { 0.35, 3 }, slimed = true })
            -- the strand trailing back to the mouth, fading out
            world:addFx({ x = x0, y = y0, life = range / sp + 0.35, draw = function(fx, k, fade)
                local lg = love.graphics
                local x1, y1 = Iso.toScreen(fx.x, fx.y)
                local x2, y2 = Iso.toScreen(s.x, s.y)
                lg.setColor(color[1], color[2], color[3], 0.55 * fade)
                lg.setLineWidth(1)
                lg.line(x1, y1 - 4, x2, y2 - s.z)
            end })
        end
        world.particles:burst(player.x + ax * 9, player.y + ay * 9, 5, { color }, 50, 20, { grav = 120 })
        Audio.play("dash", { pitch = 2.0, volume = 0.4 })
    end,
}
