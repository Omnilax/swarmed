-- Charge punch (mantis shrimp): hold left click to cock the smashing club back (the body coils
-- and shakes as it loads), let go to unleash one of the fastest strikes in nature. Damage and
-- knockback grow with the charge, and a beat later the cavitation bubble the club left behind
-- collapses with a second blast. A full charge punches a shockwave through the whole line.
-- Auto-attack: charges about halfway, then punches the nearest ant.
-- params: damage (uncharged), cooldown, reach (30), charge (seconds to full, 0.9), maxMult (4.5),
--         bubble (cavitation blast, x damage, 0.5), radius (bubble, 22), knockback (220), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")
local util = require("src.core.util")

-- the cavitation bubble: swells, wobbles, then implodes in a white flash
local function drawBubble(fx, k, fade)
    local lg = love.graphics
    local x, y = Iso.toScreen(fx.x, fx.y, 4)
    if k < 0.6 then
        local r = fx.r * 0.4 * math.sin(k / 0.6 * math.pi * 0.5)
        lg.setColor(0.7, 0.9, 1, 0.6)
        lg.ellipse("line", x, y, r, r * 0.8)
        lg.setColor(1, 1, 1, 0.8)
        lg.rectangle("fill", math.floor(x - r * 0.4), math.floor(y - r * 0.5), 1, 1)
    else
        local kk = (k - 0.6) / 0.4
        lg.setColor(1, 1, 1, 0.9 * (1 - kk))
        lg.circle("fill", x, y, 3 * (1 - kk) + 1)
    end
end

local function bubble(world, x, y, dmg, r)
    world:addFx({ draw = drawBubble, x = x, y = y, r = r, life = 0.22 })
    world.player:after(0.13, function(p, w)
        Combat.area(w, x, y, r, dmg, { knockback = 120 })
        w:addFx({ kind = "ring", x = x, y = y, r = r, life = 0.2, color = { 0.75, 0.95, 1 } })
        w.particles:burst(x, y, 8, { { 0.85, 0.95, 1 }, { 1, 1, 1 } }, 110, 20, { glow = true, grav = 0 })
        Audio.play("zap", { pitch = 1.6, volume = 0.5 })
    end)
end

local ChargePunch = {
    name = "Charge Punch",
    bubble = bubble,
    manual = true,
    range = function(params, player) return (params.reach or 30) * (1 + player.stats:get("area") / 100) end,
    update = function(player, world, dt, params, down, auto)
        local atk = player.attack
        if atk.timer > 0 then player.punchCharge = nil return end
        local full = params.charge or 0.9
        if down or auto then
            player.punchCharge = (player.punchCharge or 0) + dt
            local f = math.min(1, player.punchCharge / full)
            if f >= 1 and world.time % 0.08 < dt then
                world.particles:spawn(player.x + player.aimX * 6, player.y + player.aimY * 6, 6, 0, 0, 16, 0.25, { 1, 0.5, 0.45 }, 1, { glow = true, grav = -10 })
            end
            if not (auto and not down and f >= 0.5) then return end
        end
        if not player.punchCharge then return end
        local f = math.min(1, player.punchCharge / full)
        player.punchCharge = nil
        player:releaseAttack(player.aimX, player.aimY, f)
    end,
    fire = function(player, world, ax, ay, params, charge)
        local f = charge or 0
        local area = 1 + player.stats:get("area") / 100
        local mult = 1 + ((params.maxMult or 4.5) - 1) * f * f
        local reach = (params.reach or 30) * area * (1 + f * 0.5)
        local ang = math.atan2(ay, ax)
        local hits = Combat.collect(world, player.x, player.y, reach, function(e, dx, dy)
            return math.abs(util.angleDiff(ang, math.atan2(dy, dx))) <= 0.6 end)
        local kb = (params.knockback or 220) * (0.6 + f * 1.6)
        for _, e in ipairs(hits) do
            Combat.damage(world, e, params.damage * mult, { knockback = kb, kbx = ax, kby = ay })
        end
        local ix, iy = player.x + ax * reach * 0.8, player.y + ay * reach * 0.8
        bubble(world, ix, iy, params.damage * mult * (params.bubble or 0.5), (params.radius or 22) * area * (0.6 + f * 0.6))
        world:addFx({ kind = "stab", x = player.x, y = player.y, x2 = player.x + ax * reach, y2 = player.y + ay * reach, w = 2 + f * 3, life = 0.12,
            color = params.color or { 1, 0.45, 0.4 } })
        if f >= 1 then
            -- full power: a shockwave tears through the whole line
            local far = 120 * area
            for _, e in ipairs(Combat.collectLine(world, player.x, player.y, player.x + ax * far, player.y + ay * far, 10)) do
                Combat.damage(world, e, params.damage * 1.5, { knockback = kb * 0.6, kbx = ax, kby = ay })
            end
            world:addFx({ kind = "streak", x = player.x, y = player.y, x2 = player.x + ax * far, y2 = player.y + ay * far, w = 6, life = 0.25, color = { 0.8, 0.95, 1 } })
            world:floatText(ix, iy, "SMASH!", { 1, 0.6, 0.4 }, true)
            world.hitstop = math.max(world.hitstop or 0, 0.06)
        end
        world.camera:shake(0.05 + f * 0.2)
        Audio.play("hit", { pitch = 0.9 - f * 0.4, volume = 0.6 + f * 0.4 })
        if f > 0.5 then Audio.play("boom", { pitch = 1.5, volume = 0.5 }) end
    end,
}

return ChargePunch
