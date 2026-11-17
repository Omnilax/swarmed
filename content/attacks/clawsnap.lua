-- Claw snap (lobster): hold left click and the crusher claw gapes open, wider and wider the
-- longer you hold; let go and it snaps shut in front of you. The bite grows with the hold, and
-- so does the damage. A full hold crushes everything in a huge pincer. Auto-attack: holds about
-- halfway, then snaps.
-- params: damage (quick snap, 10), cooldown, charge (seconds to full, 1.1), radius (quick snap, 16),
--         maxRadius (full, 40), offset (26), maxMult (damage x at full, 3.5), knockback (220), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")
local Anim = require("src.gfx.anim")

local function size(params, player, f)
    local area = 1 + player.stats:get("area") / 100
    local r = ((params.radius or 16) + ((params.maxRadius or 40) - (params.radius or 16)) * f) * area
    return r, ((params.offset or 26) + r * 0.35) * area
end

return {
    name = "Claw Snap",
    manual = true,
    range = function(params, player) local r, off = size(params, player, 0.5) return r + off end,
    update = function(player, world, dt, params, down, auto)
        local atk = player.attack
        if atk.timer > 0 then
            if player.clawCharge then player.clawCharge = nil Anim.stop(player, "charge") end
            return
        end
        local full = params.charge or 1.1
        if down or auto then
            if not player.clawCharge then
                player.clawCharge = 0
                local clip = Anim.find(player.def, "charge", "clawsnap.charge")
                if clip then Anim.play(player, clip, "charge", { params = params }) end
                Audio.play("equip", { pitch = 0.6, volume = 0.5 })
            end
            player.clawCharge = player.clawCharge + dt
            local f = math.min(1, player.clawCharge / full)
            if f >= 1 and world.time % 0.1 < dt then
                local r, off = size(params, player, f)
                world.particles:spawn(player.x + player.aimX * off, player.y + player.aimY * off, 6, 0, 0, 14, 0.3, { 1, 0.6, 0.45 }, 1, { glow = true, grav = -10 })
            end
            if not (auto and not down and f >= 0.5) then return end
        end
        if not player.clawCharge then return end
        local f = math.min(1, player.clawCharge / full)
        player.clawCharge = nil
        Anim.stop(player, "charge")
        player:releaseAttack(player.aimX, player.aimY, f)
    end,
    fire = function(player, world, ax, ay, params, charge)
        local f = math.max(0, math.min(1, charge or 0.5))
        local r, off = size(params, player, f)
        local x, y = player.x + ax * off, player.y + ay * off
        local mult = 1 + ((params.maxMult or 3.5) - 1) * f
        local hits = Combat.area(world, x, y, r, params.damage * mult, { knockback = (params.knockback or 220) * (0.5 + f) })
        -- the two halves of the claw slamming together
        local a = math.atan2(ay, ax)
        local col = params.color or { 1, 0.6, 0.45 }
        world:addFx({ kind = "arc", x = x, y = y, r = r * 0.9, a = a + 1.2, arc = 2, dir = -1, life = 0.14, color = col })
        world:addFx({ kind = "arc", x = x, y = y, r = r * 0.9, a = a - 1.2, arc = 2, dir = 1, life = 0.14, color = col })
        world:addFx({ kind = "ring", x = x, y = y, r = r, life = 0.2, color = { 1, 0.85, 0.75 } })
        world.hazards:deflect(x, y, r, a, 1.2)
        world.camera:shake(0.06 + f * 0.2 + math.min(0.2, hits * 0.008))
        Audio.play(f > 0.6 and "boom" or "hit", { pitch = 1.4 - f * 0.6, volume = 0.6 + f * 0.4 })
        if f >= 1 then
            world:floatText(x, y, "CRUNCH!", { 1, 0.6, 0.45 }, true)
            world:hitStop(0.05)
            world.particles:burst(x, y, 14, { { 0.6, 0.55, 0.5 }, { 0.75, 0.7, 0.62 } }, 100, 60, { grav = 300 })
        end
    end,
    -- while held: the claw's reach outlined on the ground, gaping wider as it charges
    draw = function(player, world, params)
        local c = player.clawCharge
        if not c or player.dead then return end
        local f = math.min(1, c / (params.charge or 1.1))
        local r, off = size(params, player, f)
        local ax, ay = player.aimX, player.aimY
        local cx, cy = player.x + ax * off, player.y + ay * off
        local a = math.atan2(ay, ax)
        local gape = 0.25 + f * 0.9
        local lg = love.graphics
        local col = params.color or { 1, 0.6, 0.45 }
        lg.setLineWidth(1)
        for s = -1, 1, 2 do
            -- each jaw: an arc from the hinge (behind the bite) out round one side
            local pts = {}
            for i = 0, 8 do
                local t = i / 8
                local ang = a + s * (math.pi - gape) * (1 - t) + s * gape * 0.2
                local rr = r * (0.5 + 0.5 * math.sin(t * math.pi * 0.5 + math.pi * 0.5 * (1 - t)))
                local sx, sy = Iso.toScreen(cx + math.cos(ang) * rr, cy + math.sin(ang) * rr, 2)
                pts[#pts + 1], pts[#pts + 2] = sx, sy
            end
            lg.setColor(col[1], col[2], col[3], 0.35 + 0.5 * f)
            lg.line(pts)
        end
        local hx, hy = Iso.toScreen(cx, cy, 2)
        lg.setColor(1, 0.9, 0.8, f >= 1 and 0.9 or 0.4)
        lg.circle("line", hx, hy, 1 + f * 2)
        lg.setColor(1, 1, 1, 1)
    end,
}
