-- Stink shield (stink bug): no dash. Clamps down under its shield-shaped back and blasts out a
-- ring of stench: for a moment nothing can hurt it, and ants are driven out of the ring and
-- kept away until it fades, and it leaves a ring of stink clouds behind.
-- params: time (shielded, 1.6 s), radius (ring, 30), damage (blast, 6)
local Combat = require("src.game.combat")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

local function ward(player, amount, source)
    if (player.stinkShieldT or 0) > 0 then
        if player.blockFxT <= 0 then
            player.blockFxT = 0.15
            player.world.particles:sparks(player.x, player.y, 3, { 0.8, 0.95, 0.4 }, player.aimX, player.aimY, 2.5, 60)
        end
        return true
    end
    return false
end

return {
    name = "Stink Shield",
    description = "No dash. Clamps down under its shield and blasts a ring of stench: briefly untouchable, ants are driven out, and stink clouds hang around you.",
    start = function(player, world, dx, dy, params)
        player.stinkShieldT = params.time or 1.6
        player.ward = ward
        local r = (params.radius or 30) * (1 + player.stats:get("area") / 100)
        Combat.area(world, player.x, player.y, r, params.damage or 6, { knockback = 260, poison = { 3, 2 } })
        world:addFx({ kind = "ring", x = player.x, y = player.y, r = r, life = 0.3, color = { 0.75, 0.9, 0.3 } })
        world.particles:burst(player.x, player.y, 14, { { 0.7, 0.8, 0.3 }, { 0.55, 0.6, 0.25 } }, 90, 20, { grav = -20 })
        -- the blast leaves a ring of stink clouds (content/attacks/stinkcloud.lua)
        local atk = player.attack
        if atk and atk.type.cloud then
            for i = 0, 3 do
                local a = i / 4 * math.pi * 2 + world.time
                atk.type.cloud(world, player, atk.params, player.x + math.cos(a) * r, player.y + math.sin(a) * r, r * 0.55, math.cos(a) * 10, math.sin(a) * 10, 2)
            end
        end
        player.dashT = 0
        Audio.play("equip", { pitch = 0.6 })
    end,
    -- every frame (Player:update calls a dash's tick if it has one): the shield wears off and
    -- keeps ants out of the ring while it lasts
    tick = function(player, world, dt, params)
        local t = player.stinkShieldT or 0
        if t <= 0 then return end
        player.stinkShieldT = t - dt
        local r = (params.radius or 30) * (1 + player.stats:get("area") / 100)
        for _, e in ipairs(Combat.collect(world, player.x, player.y, r)) do
            local ex, ey = e.x - player.x, e.y - player.y
            local d = math.sqrt(ex * ex + ey * ey) + 0.001
            e.kvx, e.kvy = e.kvx + ex / d * 1800 * dt, e.kvy + ey / d * 1800 * dt
        end
    end,
    draw = function(player, world, params)
        local t = player.stinkShieldT or 0
        if t <= 0 or player.dead then return end
        local r = (params.radius or 30) * (1 + player.stats:get("area") / 100)
        local lg = love.graphics
        local pts = {}
        for i = 0, 24 do
            local a = i / 24 * math.pi * 2
            local wob = 1 + 0.06 * math.sin(a * 5 + world.time * 8)
            local sx, sy = Iso.toScreen(player.x + math.cos(a) * r * wob, player.y + math.sin(a) * r * wob, 2)
            pts[#pts + 1], pts[#pts + 2] = sx, sy
        end
        lg.setColor(0.75, 0.9, 0.3, 0.5 * math.min(1, t / 0.4))
        lg.line(pts)
        lg.setColor(1, 1, 1, 1)
    end,
}
