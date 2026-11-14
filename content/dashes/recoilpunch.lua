-- Recoil punch (mantis shrimp): hold Shift to cock the smashing club back (the body coils and
-- shakes as it loads, and it shuffles slowly), let go to throw one huge punch at where you
-- point. The longer the charge, the harder it hits and the further the recoil launches you
-- backwards out of trouble; a full charge also punches a shockwave down the line. The ants it
-- hits go flying the other way. Uses a dash charge (refilled by Dash Cooldown).
-- params: damage (24, at no charge), reach (34), distance (launch, 100), charge (s to full, 0.8),
--         maxMult (damage x at full charge, 3), launchMult (extra launch at full, 1.2),
--         slow (move speed x while charging, 0.55), charges
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local util = require("src.core.util")
local Anim = require("src.gfx.anim")
local Charge = require("content.dashes._charge")

local function punch(player, world, params, f)
    local px, py = player:pointer()
    local ax, ay, l = util.normalize(px - player.x, py - player.y)
    if l < 1 then ax, ay = player.aimX, player.aimY end
    local area = 1 + player.stats:get("area") / 100
    local reach = (params.reach or 34) * area * (1 + f * 0.4)
    local dmg = (params.damage or 24) * (1 + ((params.maxMult or 3) - 1) * f)
    local ang = math.atan2(ay, ax)
    for _, e in ipairs(Combat.collect(world, player.x, player.y, reach, function(e, ex, ey)
        return math.abs(util.angleDiff(ang, math.atan2(ey, ex))) <= 0.8 end)) do
        Combat.damage(world, e, dmg, { knockback = 300 + f * 300, kbx = ax, kby = ay })
    end
    if f >= 1 then
        -- full charge: the shockwave tears down the whole line
        local far = 130 * area
        for _, e in ipairs(Combat.collectLine(world, player.x, player.y, player.x + ax * far, player.y + ay * far, 10)) do
            Combat.damage(world, e, dmg * 0.5, { knockback = 260, kbx = ax, kby = ay })
        end
        world:addFx({ kind = "streak", x = player.x, y = player.y, x2 = player.x + ax * far, y2 = player.y + ay * far, w = 6, life = 0.25, color = { 0.8, 0.95, 1 } })
        world:floatText(player.x + ax * reach, player.y + ay * reach, "SMASH!", { 1, 0.6, 0.4 }, true)
        world.hitstop = math.max(world.hitstop or 0, 0.06)
    end
    world:addFx({ kind = "stab", x = player.x, y = player.y, x2 = player.x + ax * reach, y2 = player.y + ay * reach, w = 4 + f * 3, life = 0.14, color = { 1, 0.5, 0.4 } })
    world:addFx({ kind = "ring", x = player.x + ax * reach * 0.7, y = player.y + ay * reach * 0.7, r = reach * 0.6, life = 0.22, color = { 0.8, 0.95, 1 } })
    world.camera:shake(0.1 + f * 0.15)
    Audio.play("boom", { pitch = 1.7 - f * 0.5, volume = 0.5 + f * 0.4 })
    player:lunge(-ax, -ay, (params.distance or 100) * (1 + (params.launchMult or 1.2) * f), 1.1)
    player.dashHop = 8
    player.aimX, player.aimY = ax, ay
    player.wangle = ang
end

return {
    name = "Recoil Punch",
    description = "Hold to wind up a punch, let go to throw it where you point. The longer the wind-up, the harder it hits and the further the recoil launches you backwards.",
    hold = true,
    update = function(player, world, dt, params, held)
        local c = player.recoil
        if c and (player.stunT > 0 or player.dead) then
            player.recoil, player.moveMul = nil, nil
            Anim.stop(player, "dash")
            return
        end
        if held and not c then
            if not Charge.ready(player) then return end
            c = { t = 0 }
            player.recoil = c
            player.moveMul = params.slow or 0.55
            Anim.move(player, "dash", params)
            Audio.play("equip", { pitch = 0.7, volume = 0.5 })
        elseif held then
            c.t = c.t + dt
            local full = params.charge or 0.8
            if c.t >= full and world.time % 0.08 < dt then
                world.particles:spawn(player.x + player.aimX * 6, player.y + player.aimY * 6, 6, 0, 0, 16, 0.25, { 1, 0.5, 0.45 }, 1, { glow = true, grav = -10 })
            end
            if c.t >= full and not c.ready then
                c.ready = true
                Audio.play("zap", { pitch = 2, volume = 0.4 })
            end
        elseif c then
            local f = math.min(1, c.t / (params.charge or 0.8))
            player.recoil, player.moveMul = nil, nil
            Charge.spend(player)
            punch(player, world, params, f)
            -- a launch: untouchable for nearly the whole flight
            player.iframes = math.max(player.iframes, player.dashT * 0.95)
            Charge.fired(player, world, params, false)
        end
    end,
}
