-- Palp strike (tailless whip scorpion): one of its two long, spine-lined raptorial palps snaps
-- out far beyond its body. The palps are all reach: the bug itself never has to step in.
--   hand = "left" (left click): the palp rakes sideways across a long arc, hitting everything
--          along it, the spines dragging ants a little toward you.
--   hand = "right" (right click): the palp whips out to full reach and slams down: only its tip
--          hits, a small blast that deals big damage to the ant right under it. Keep your distance.
-- feelers = true also draws the whip-thin feeler legs, always sweeping the ground ahead.
-- params: damage, cooldown, hand, reach (left 74 / right 100), arc (left, 1.9), radius (right, tip
--         blast, 14), splash (right, share of damage to the others in the blast, 0.35),
--         poison ({ dps, time } from the spines), stun (right, seconds the ant under the tip is dazed), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")
local util = require("src.core.util")

local SPINE = { 0.95, 0.85, 0.65 }

-- the palp itself: a jointed, spined arm from the shoulder to (tx, ty)
local function drawPalp(fx, k, fade)
    local lg = love.graphics
    local out = k < 0.3 and k / 0.3 or 1 - (k - 0.3) / 0.7 * 0.8
    local sx, sy = fx.x, fx.y
    local a = fx.a0 + (fx.a1 - fx.a0) * math.min(1, k / 0.35)
    local r = fx.r * out
    local ex, ey = sx + math.cos(a) * r, sy + math.sin(a) * r
    -- elbow bent outward
    local mx, my = (sx + ex) / 2 + math.cos(a + fx.side * 1.57) * r * 0.12, (sy + ey) / 2 + math.sin(a + fx.side * 1.57) * r * 0.12
    local x1, y1 = Iso.toScreen(sx, sy, 5)
    local x2, y2 = Iso.toScreen(mx, my, 7)
    local x3, y3 = Iso.toScreen(ex, ey, 4)
    lg.setColor(0.75, 0.5, 0.3, 0.6 * fade)
    lg.setLineWidth(3)
    lg.line(x1, y1, x2, y2, x3, y3)
    lg.setColor(1, 0.9, 0.75, fade)
    lg.setLineWidth(1)
    lg.line(x1, y1, x2, y2, x3, y3)
    -- spines along the forearm
    for i = 1, 4 do
        local t = i / 5
        local px, py = util.lerp(x2, x3, t), util.lerp(y2, y3, t)
        lg.setColor(SPINE[1], SPINE[2], SPINE[3], 0.9 * fade)
        lg.line(px, py, px + (y3 - y2) * 0.08 * fx.side, py - (x3 - x2) * 0.08 * fx.side)
    end
    -- the hooked tip
    lg.setColor(1, 1, 0.9, fade)
    lg.rectangle("fill", math.floor(x3) - 1, math.floor(y3) - 1, 2, 2)
end

return {
    name = "Palp Strike",
    range = function(params, player) return (params.reach or 74) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local area = 1 + player.stats:get("area") / 100
        local ang = math.atan2(ay, ax)
        local side = params.hand == "right" and 1 or -1
        local shoulderX = player.x + math.cos(ang + side * 1.2) * 5
        local shoulderY = player.y + math.sin(ang + side * 1.2) * 5
        local color = params.color or { 1, 0.85, 0.6 }
        if params.hand ~= "right" then
            -- rake: sweeps from the left side across to the front-right
            local reach = (params.reach or 74) * area
            local half = (params.arc or 1.9) / 2
            for _, e in ipairs(Combat.collect(world, player.x, player.y, reach, function(e, dx, dy)
                return math.abs(util.angleDiff(ang, math.atan2(dy, dx))) <= half end)) do
                local nx, ny = util.normalize(player.x - e.x, player.y - e.y)
                local tx, ty = math.cos(ang - side * 1.57), math.sin(ang - side * 1.57)
                Combat.damage(world, e, params.damage, { knockback = 60, kbx = tx * 0.7 + nx * 0.3, kby = ty * 0.7 + ny * 0.3, poison = params.poison })
            end
            world:addFx({ draw = drawPalp, x = shoulderX, y = shoulderY, a0 = ang + side * half, a1 = ang - side * half * 0.8, r = reach,
                side = side, life = 0.22 })
            world:addFx({ kind = "arc", x = player.x, y = player.y, r = reach, a = ang, arc = half * 2, dir = -side, life = 0.18, color = color })
            Audio.play("dash", { pitch = 1.7, volume = 0.6 })
        else
            -- tip slam: the palp whips out and cracks down at its very tip. Only the tip hits: the
            -- ant under it takes the full blow, the little blast splashes the ones around it.
            local reach = (params.reach or 100) * area
            local tx, ty = shoulderX + ax * reach, shoulderY + ay * reach
            local r = (params.radius or 14) * area
            local hits = Combat.collect(world, tx, ty, r)
            table.sort(hits, function(a, b) return (a.x - tx) ^ 2 + (a.y - ty) ^ 2 < (b.x - tx) ^ 2 + (b.y - ty) ^ 2 end)
            for i, e in ipairs(hits) do
                local nx, ny = util.normalize(e.x - tx, e.y - ty)
                if i == 1 then
                    Combat.damage(world, e, params.damage, { knockback = 120, kbx = ax, kby = ay, stun = params.stun, poison = params.poison })
                else
                    Combat.damage(world, e, params.damage * (params.splash or 0.35), { knockback = 140, kbx = nx, kby = ny, poison = params.poison })
                end
            end
            world:addFx({ draw = drawPalp, x = shoulderX, y = shoulderY, a0 = ang, a1 = ang, r = reach, side = side, life = 0.28 })
            world:addFx({ kind = "ring", x = tx, y = ty, r = r, life = 0.2, color = color })
            world:addFx({ kind = "ring", x = tx, y = ty, r = r * 0.45, life = 0.14, color = { 1, 1, 0.9 } })
            world.particles:burst(tx, ty, 8, { { 0.7, 0.62, 0.52 }, { 0.55, 0.48, 0.4 } }, 80, 50, { grav = 260 })
            world.camera:shake(#hits > 0 and 0.08 or 0.04)
            Audio.play(#hits > 0 and "hit" or "dash", { pitch = 0.8 })
            if #hits > 0 then Audio.play("boom", { pitch = 1.9, volume = 0.4 }) end
        end
    end,
    -- the whip-thin feeler legs, always tapping and sweeping the ground ahead
    draw = function(player, world, params)
        if not params.feelers or player.dead then return end
        local lg = love.graphics
        local t = world.time
        lg.setLineStyle("rough")
        lg.setLineWidth(1)
        for side = -1, 1, 2 do
            local base = player.wangle + side * 0.55 + math.sin(t * 2.3 + side) * 0.35
            local x, y = player.x + math.cos(player.wangle + side * 0.9) * 4, player.y + math.sin(player.wangle + side * 0.9) * 4
            local pts = {}
            local a = base
            for i = 0, 8 do
                local sx, sy = Iso.toScreen(x, y, i == 0 and 4 or 4 + math.sin(i / 8 * math.pi) * 3)
                pts[#pts + 1], pts[#pts + 2] = sx, sy
                a = a + math.sin(t * 3.1 + i * 0.7 + side) * 0.08 - side * 0.05
                x, y = x + math.cos(a) * 5.5, y + math.sin(a) * 5.5
            end
            lg.setColor(0.55, 0.4, 0.3, 0.85)
            lg.line(pts)
        end
        lg.setColor(1, 1, 1, 1)
    end,
}
