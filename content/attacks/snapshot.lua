-- Snap shot (pistol shrimp): the big claw snaps shut so fast it fires a jet of cavitation
-- bubble across the arena, a sniper shot that pierces every ant in a long line. Where it ends
-- the bubble collapses in a flash hotter than the sun's surface (sonoluminescence) and a
-- burst. Fired from the cloak it hits twice as hard. Hold right click to aim (a sight line shows
-- the shot, steadying as you hold), let go to fire: a rushed shot hits for half.
-- params: damage, cooldown, range (300), width (5), radius (end flash, 28), cloakMult (2),
--         aim (seconds to a full-power shot, 0.5), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")

local function drawShot(fx, k, fade)
    local lg = love.graphics
    local x1, y1 = Iso.toScreen(fx.x, fx.y, 4)
    local x2, y2 = Iso.toScreen(fx.x2, fx.y2, 4)
    local head = math.min(1, k / 0.15)
    local hx, hy = x1 + (x2 - x1) * head, y1 + (y2 - y1) * head
    lg.setColor(0.6, 0.85, 1, 0.35 * fade)
    lg.setLineWidth(5 * fade + 1)
    lg.line(x1, y1, hx, hy)
    lg.setColor(1, 1, 1, 0.9 * fade)
    lg.setLineWidth(1)
    lg.line(x1, y1, hx, hy)
    -- bubbles strung along the trail
    for i = 1, 10 do
        local t = i / 11
        if t < head then
            local bx, by = x1 + (x2 - x1) * t, y1 + (y2 - y1) * t
            lg.setColor(0.85, 0.95, 1, 0.6 * fade)
            lg.circle("line", bx + math.sin(i * 3.1) * 2, by + math.cos(i * 2.3) * 2 - k * 6, 1 + (i % 3) * 0.5)
        end
    end
    if k > 0.12 then
        -- the flash of light where the bubble collapses
        local f = 1 - (k - 0.12) / 0.88
        lg.setColor(1, 1, 0.85, f)
        lg.circle("fill", x2, y2, 2 + 6 * f)
    end
    lg.setLineWidth(1)
end

local function aimDir(player, px, py)
    local ax, ay = px - player.x, py - player.y
    local l = math.sqrt(ax * ax + ay * ay)
    if l < 1 then return player.aimX, player.aimY end
    return ax / l, ay / l
end

return {
    name = "Snap Shot",
    manual = true,
    range = function(params) return params.range or 300 end,
    update = function(player, world, dt, params, held, px, py)
        if player.secondary.timer > 0 or player.stunT > 0 then player.snapAim = nil return end
        if held then
            player.snapAim = (player.snapAim or 0) + dt
            player.aimX, player.aimY = aimDir(player, px, py)
            return
        end
        if not player.snapAim then return end
        local f = math.min(1, player.snapAim / (params.aim or 0.5))
        player.snapAim = nil
        local ax, ay = aimDir(player, px, py)
        player:releaseSecondary(ax, ay, px, py, f)
    end,
    -- the sight line while aiming: faint and shaky at first, steady and bright when fully aimed
    draw = function(player, world, params)
        local t = player.snapAim
        if not t or player.dead then return end
        local f = math.min(1, t / (params.aim or 0.5))
        local px, py = player:pointer()
        local ax, ay = aimDir(player, px, py)
        local wob = (1 - f) * 0.06 * math.sin(world.time * 23)
        local c, s = math.cos(wob), math.sin(wob)
        ax, ay = ax * c - ay * s, ax * s + ay * c
        local range = (params.range or 300) * (1 + player.stats:get("area") / 200)
        local cx, cy = player.x + ax * 8 - ay * 4, player.y + ay * 8 + ax * 4
        local x1, y1 = Iso.toScreen(cx, cy, 4)
        local x2, y2 = Iso.toScreen(cx + ax * range, cy + ay * range, 4)
        local lg = love.graphics
        lg.setLineWidth(1)
        lg.setColor(0.8, 0.95, 1, 0.15 + 0.45 * f)
        lg.line(x1, y1, x2, y2)
        if f >= 1 then
            lg.setColor(1, 1, 0.85, 0.8)
            lg.circle("line", x2, y2, 3)
        end
        lg.setColor(1, 1, 1, 1)
    end,
    fire = function(player, world, ax, ay, params, px, py, charge)
        local Cloak = require("content.dashes.cloak")
        local fromCloak = Cloak.reveal(player)
        local mult = (fromCloak and (params.cloakMult or 2) or 1) * (0.5 + 0.5 * (charge or 1))
        local range = (params.range or 300) * (1 + player.stats:get("area") / 200)
        local cx, cy = player.x + ax * 8 - ay * 4, player.y + ay * 8 + ax * 4
        local x2, y2 = cx + ax * range, cy + ay * range
        local hits = Combat.collectLine(world, cx, cy, x2, y2, params.width or 5)
        for _, e in ipairs(hits) do
            Combat.damage(world, e, params.damage * mult, { knockback = 160, kbx = ax, kby = ay, noCrit = false })
        end
        world:addFx({ draw = drawShot, x = cx, y = cy, x2 = x2, y2 = y2, life = 0.45, color = { 1, 1, 0.85 } })
        player:after(0.06, function(p, w)
            local r = (params.radius or 28) * (1 + p.stats:get("area") / 100)
            Combat.explode(w, x2, y2, r, params.damage * 0.6 * mult, { color = { 1, 1, 0.8 }, knockback = 160 })
        end)
        player:knock(-ax, -ay, 140)
        world.camera:shake(0.15)
        if fromCloak then world:floatText(player.x, player.y, "AMBUSH!", { 0.8, 0.95, 1 }, true) end
        Audio.play("boom", { pitch = 2.2, volume = 0.7 })
        Audio.play("zap", { pitch = 0.8 })
    end,
}
