-- Charge dash (tiger beetle): hold left click to dig in and wind up (you slow to a crawl and a
-- line shows where you'll go), let go to shoot forward through the swarm. The longer the wind-up
-- the further and harder it hits. You're untouchable for the whole dash and a moment after, and
-- you land with a shove that clears room around you, so you're never stuck in the crowd.
-- Auto-attack: winds up about halfway, then goes.
-- params: damage (uncharged, 14), cooldown, charge (seconds to full, 0.75), distance (uncharged, 50),
--         maxDistance (full, 150), width (9), maxMult (damage x at full, 3), knockback (160),
--         guard (untouchable after landing, 0.35), crawl (move speed x while winding up, 0.45),
--         poison ({dps, seconds}), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")
local Anim = require("src.gfx.anim")

local function reach(params, player, f)
    local d = (params.distance or 50) + ((params.maxDistance or 150) - (params.distance or 50)) * f
    return d * (1 + player.stats:get("area") / 200)
end

return {
    name = "Charge Dash",
    manual = true,
    range = function(params, player) return reach(params, player, 0.6) end,
    update = function(player, world, dt, params, down, auto)
        local atk = player.attack
        if atk.timer > 0 then
            if player.dashCharge then player.dashCharge, player.moveMul = nil, nil Anim.stop(player, "charge") end
            return
        end
        local full = params.charge or 0.75
        if down or auto then
            if not player.dashCharge then
                local clip = Anim.find(player.def, "charge", "chargedash.charge")
                if clip then Anim.play(player, clip, "charge", { params = params }) end
            end
            player.dashCharge = (player.dashCharge or 0) + dt
            player.moveMul = params.crawl or 0.45
            local f = math.min(1, player.dashCharge / full)
            if world.time % 0.06 < dt then
                world.particles:spawn(player.x - player.aimX * 5, player.y - player.aimY * 5, 1, -player.aimX * 30, -player.aimY * 30, 14, 0.3,
                    f >= 1 and { 0.7, 1, 0.75 } or { 0.65, 0.6, 0.52 }, 1, { grav = 80, glow = f >= 1 })
            end
            if not (auto and not down and f >= 0.6) then return end
        end
        if not player.dashCharge then return end
        local f = math.min(1, player.dashCharge / full)
        player.dashCharge, player.moveMul = nil, nil
        Anim.stop(player, "charge")
        player:releaseAttack(player.aimX, player.aimY, f)
    end,
    fire = function(player, world, ax, ay, params, charge)
        local f = math.max(0, math.min(1, charge or 0.5))
        local dist = reach(params, player, f)
        local mult = 1 + ((params.maxMult or 3) - 1) * f
        local x2, y2 = player.x + ax * dist, player.y + ay * dist
        local hits = Combat.collectLine(world, player.x, player.y, x2, y2, (params.width or 9) * (1 + f * 0.4))
        for _, e in ipairs(hits) do
            local sx, sy = -ay, ax
            if (e.x - player.x) * sx + (e.y - player.y) * sy < 0 then sx, sy = -sx, -sy end
            Combat.damage(world, e, params.damage * mult, { knockback = (params.knockback or 160) * (0.7 + f * 0.6),
                kbx = sx + ax * 0.5, kby = sy + ay * 0.5, poison = params.poison })
        end
        world:addFx({ kind = "streak", x = player.x, y = player.y, x2 = x2, y2 = y2, w = 4 + f * 4, life = 0.22, color = params.color })
        player:lunge(ax, ay, dist, 1.5 + f * 0.6)
        -- the whole dash and a beat after landing are safe; then a shove makes room
        player.iframes = math.max(player.iframes, player.dashT + (params.guard or 0.35))
        player:after(player.dashT, function(p) p:releaseShove({ releaseRadius = 26 + f * 10, releaseShove = 220 }) end)
        Audio.play("dash", { pitch = 1.1 - f * 0.3 })
        if f >= 1 then world:floatText(player.x, player.y, "CHARGE!", { 0.7, 1, 0.75 }, true) end
        world.camera:shake(0.04 + f * 0.1 + math.min(0.15, #hits * 0.006))
    end,
    -- while winding up: a line on the ground showing how far the dash will go
    draw = function(player, world, params)
        local c = player.dashCharge
        if not c or player.dead then return end
        local f = math.min(1, c / (params.charge or 0.75))
        local dist = reach(params, player, f)
        local lg = love.graphics
        local x1, y1 = Iso.toScreen(player.x + player.aimX * 6, player.y + player.aimY * 6)
        local x2, y2 = Iso.toScreen(player.x + player.aimX * dist, player.y + player.aimY * dist)
        local col = params.color or { 0.6, 1, 0.7 }
        lg.setColor(col[1], col[2], col[3], 0.25 + 0.45 * f)
        lg.setLineWidth(1)
        local n = 10
        for i = 0, n - 1, 2 do
            local a, b = i / n, (i + 1) / n
            lg.line(x1 + (x2 - x1) * a, y1 + (y2 - y1) * a, x1 + (x2 - x1) * b, y1 + (y2 - y1) * b)
        end
        lg.circle(f >= 1 and "fill" or "line", x2, y2, 2)
        lg.setColor(1, 1, 1, 1)
    end,
}
