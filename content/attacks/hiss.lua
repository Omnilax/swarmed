-- Hiss (hissing roach): hold right click to draw air in (the body swells), let go to force it
-- out of the breathing holes in a deafening hiss. Ants caught in the blast are stunned on the
-- spot: they stop, can't bite, and reel. The longer the breath, the wider and longer the stun.
-- A quick tap still gives a short hiss.
-- params: damage (small), cooldown, radius (min blast, 50), maxRadius (110), stun (min, 0.8),
--         maxStun (2.6), charge (seconds to full breath, 1), arc (radians of the blast, 6.3 = all round)
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")

local function drawWaves(fx, k, fade)
    local lg = love.graphics
    for i = 0, 3 do
        local kk = k * 1.3 - i * 0.12
        if kk > 0 and kk < 1 then
            local r = fx.r * kk
            local pts = {}
            for s = 0, 24 do
                local a = s / 24 * math.pi * 2
                local wob = math.sin(a * 9 + fx.t * 60 + i) * 1.4
                local x, y = Iso.toScreen(fx.x + math.cos(a) * (r + wob), fx.y + math.sin(a) * (r + wob), 3)
                pts[#pts + 1], pts[#pts + 2] = x, y
            end
            lg.setColor(0.85, 0.95, 1, 0.55 * (1 - kk) * fade)
            lg.setLineWidth(i == 0 and 2 or 1)
            lg.line(pts)
        end
    end
    lg.setLineWidth(1)
end

local function blow(player, world, params, f)
    local area = 1 + player.stats:get("area") / 100
    local r = ((params.radius or 50) + ((params.maxRadius or 110) - (params.radius or 50)) * f) * area
    local stun = (params.stun or 0.8) + ((params.maxStun or 2.6) - (params.stun or 0.8)) * f
    local n = 0
    for _, e in ipairs(Combat.collect(world, player.x, player.y, r)) do
        local nx, ny = e.x - player.x, e.y - player.y
        Combat.damage(world, e, params.damage * (1 + f), { knockback = 90 + 120 * f, kbx = nx, kby = ny, stun = stun })
        n = n + 1
    end
    -- and blows enemy spit and stones back the way they came
    world.hazards:deflect(player.x, player.y, r)
    world:addFx({ draw = drawWaves, x = player.x, y = player.y, r = r, life = 0.45 + f * 0.2 })
    world.particles:burst(player.x, player.y, 10 + math.floor(f * 14), { { 0.9, 0.95, 1 }, { 0.75, 0.8, 0.85 } }, 120 + f * 100, 30, { grav = 0 })
    world.camera:shake(0.08 + f * 0.15)
    Audio.play("zap", { pitch = 0.45 - f * 0.1, volume = 0.8 })
    Audio.play("dash", { pitch = 0.5 })
    if n > 0 then world:floatText(player.x, player.y - 4, f > 0.9 and "HISSSS!" or "hiss!", { 0.85, 0.95, 1 }, f > 0.9) end
end

return {
    name = "Hiss",
    range = function(params) return params.radius or 50 end,
    fire = function(player, world, ax, ay, params)
        player.hissing = { t = 0, params = params }
        player.moveMul = 0.6
        Audio.play("dash", { pitch = 0.4, volume = 0.4 })
    end,
    update = function(player, world, dt, params, down)
        local h = player.hissing
        if not h then return end
        h.t = h.t + dt
        local f = math.min(1, h.t / (params.charge or 1))
        player.puff = f
        if f >= 1 and world.time % 0.1 < dt then
            world.particles:spawn(player.x, player.y, 6, 0, 0, 20, 0.3, { 0.9, 0.95, 1 }, 1, { glow = true, grav = -20 })
        end
        if not down or h.t > (params.charge or 1) + 0.6 then
            player.hissing, player.puff, player.moveMul = nil, nil, nil
            blow(player, world, params, f)
        end
    end,
}
