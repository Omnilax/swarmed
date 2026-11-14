-- Seize (dragonfly): hold right click to snatch the nearest ant in the spiny leg basket and
-- carry it for as long as you keep holding. Let go and it's dropped like a bomb from a bomber:
-- it falls on the crowd below and explodes (from the air it keeps some of your speed and blows
-- up bigger). Queens and bosses are too big.
-- params: cooldown (after a drop), reach (grab range, 34), bomb (blast damage when dropped
--         from the air, 22), radius (blast, 30), groundMult (blast x when dropped on the
--         ground, 0.6), squeeze (damage per second to the held ant, 0), color
local Combat = require("src.game.combat")
local Grab = require("src.game.grab")
local Audio = require("src.core.audio")

local function holding(player)
    local c = player.carry
    return c and c.kind == "dfgrab" and c
end

return {
    name = "Seize",
    manual = true,
    range = function(params) return params.reach or 34 end,
    update = function(player, world, dt, params, held, px, py)
        local c = holding(player)
        if c and not Grab.valid(c.h) then player.carry, c = nil, nil end
        if held and not c and player.secondary.timer <= 0 and player.stunT <= 0 then
            local reach = (params.reach or 34) * (1 + player.stats:get("area") / 100) + (player.airborne and 8 or 0)
            local best, bd
            for _, e in ipairs(Combat.collect(world, player.x, player.y, reach)) do
                local d = (e.x - player.x) ^ 2 + (e.y - player.y) ^ 2
                if not e.held and not e.def.boss and not e.def.queen and (not bd or d < bd) then best, bd = e, d end
            end
            if best then
                player.carry = { kind = "dfgrab", h = Grab.hold(best), t = 0 }
                world.particles:burst(best.x, best.y, 5, { { 0.9, 0.9, 0.8 } }, 50, 10)
                Audio.play("hit", { pitch = 1.6 })
            end
            return
        end
        if not c then return end
        c.t = c.t + dt
        -- hanging under the dragonfly in its leg basket
        local fx, fy = math.cos(player.wangle), math.sin(player.wangle)
        if player.airborne then
            Grab.place(c.h, player.x + fx * 2, player.y + fy * 2, math.max(1, (player.z or 0) - 3), player.wangle)
        else
            Grab.place(c.h, player.x + fx * 9, player.y + fy * 9, 3, player.wangle)
        end
        c.squeezeT = (c.squeezeT or 0) + dt
        if c.squeezeT >= 0.5 and (params.squeeze or 0) > 0 then
            c.squeezeT = 0
            Combat.damage(world, c.h.e, params.squeeze * 0.5, { knockback = 0, noCrit = true })
            if not Grab.valid(c.h) then player.carry = nil return end
        end
        if not held then
            local ax, ay = player.aimX, player.aimY
            player:releaseSecondary(ax, ay, px, py)
        end
    end,
    -- the drop (Player:releaseSecondary, on letting go)
    fire = function(player, world, ax, ay, params)
        local c = holding(player)
        if not c then return end
        player.carry = nil
        local col = params.color or { 0.5, 0.85, 1 }
        local area = 1 + player.stats:get("area") / 100
        local k = player.airborne and 1 or (params.groundMult or 0.6)
        local r = (params.radius or 30) * area * (player.airborne and 1 or 0.8)
        local function boom(w, x, y)
            w:addFx({ kind = "ring", x = x, y = y, r = r, life = 0.3, color = { 1, 0.8, 0.45 } })
            w.particles:burst(x, y, 18, { { 1, 0.75, 0.35 }, { 1, 0.95, 0.7 }, { 0.5, 0.4, 0.3 } }, 150, 40, { glow = true, grav = 120 })
            w.camera:shake(player.airborne and 0.14 or 0.08)
            Audio.play("boom", { pitch = 1.2, volume = 0.8 })
        end
        if player.airborne then
            -- bombs away: it keeps some of your speed as it falls
            local vx, vy = (player.vx or 0) * 0.6, (player.vy or 0) * 0.6
            Grab.fling(world, c.h, vx, vy, 0.32, { landDamage = (params.bomb or 22) * k, radius = r, height = 2,
                damage = 6, knockback = 160, spin = 6, color = col, onLand = boom })
            world:floatText(player.x, player.y, "BOMBS AWAY", col, false)
        else
            Grab.fling(world, c.h, ax * 60, ay * 60, 0.2, { landDamage = (params.bomb or 22) * k, radius = r,
                height = 5, damage = 5, knockback = 140, color = col, onLand = boom })
        end
    end,
}
