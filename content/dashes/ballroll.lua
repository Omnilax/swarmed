-- Ball roll (millipede, like a pill bug): hold Shift to curl up tight into an armoured ball
-- (the body is drawn as one rolling, banded ball) and roll,
-- burning stamina (src/game/stamina.lua). Rolling is faster than walking, takes less damage,
-- and bumps the ants it runs into, knocking them aside. Can't attack while curled up.
-- params: stamina (2.5 s), regen (1/s), speed (x walk speed, 1.55), damage (per bump, 5),
--         knockback (170), every (seconds before the same ant is bumped again, 0.4),
--         guard (damage taken x while rolling, 0.5)
local Stamina = require("src.game.stamina")
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")

-- curled up: the whole chain tucked inside the ball, so nothing trails behind it
local function wheel(player)
    for _, seg in ipairs(player.chain) do seg.x, seg.y = player.x, player.y end
end

local R = 7     -- ball radius on screen

return Stamina.mode({
    name = "Ball Roll",
    description = "Hold to curl up into an armoured ball like a pill bug and roll: faster, tougher, and every ant you bump into is knocked aside.",
    speed = 1.55,
    iframes = 0.15,
    enter = function(player, world, params)
        -- rolling straight out of a coil: the coil just ends (no burst)
        if player.coil then player.coil, player.moveMul = nil, nil end
        player.rollT = 0
        player.rollHit = setmetatable({}, { __mode = "k" })
        player.guardMul = params.guard or 0.5
        if player.chain then player.chainPose = wheel end
        player.hidden = true       -- the ball is drawn instead of the body
        local rx, ry = player.vx or 0, player.vy or 0
        if rx * rx + ry * ry < 1 then rx, ry = math.cos(player.wangle), math.sin(player.wangle) end
        player.rollDir = math.atan2(ry, rx)
        world.particles:burst(player.x, player.y, 6, { { 0.55, 0.3, 0.22 } }, 40, 20, { grav = 150 })
        Audio.play("equip", { pitch = 0.6 })
    end,
    tick = function(player, world, dt, params)
        local sp = math.sqrt((player.vx or 0) ^ 2 + (player.vy or 0) ^ 2)
        player.rollT = (player.rollT or 0) + dt * (0.3 + sp / 60)
        if sp > 5 then player.rollDir = math.atan2(player.vy, player.vx) end
        player.attack.timer = math.max(player.attack.timer, 0.05)
        if sp < 20 then return end
        local now = world.time
        for _, e in ipairs(Combat.collect(world, player.x, player.y, player.radius + 5)) do
            if (player.rollHit[e] or -1) < now then
                player.rollHit[e] = now + (params.every or 0.4)
                local nx, ny = e.x - player.x, e.y - player.y
                local l = math.sqrt(nx * nx + ny * ny) + 0.001
                Combat.damage(world, e, params.damage or 5, { knockback = params.knockback or 170,
                    kbx = nx / l + player.vx / sp * 0.6, kby = ny / l + player.vy / sp * 0.6 })
                world.particles:burst(e.x, e.y, 2, { { 0.75, 0.4, 0.3 } }, 40, 20, { grav = 150 })
            end
        end
    end,
    -- a pill-bug ball: dark armour bands roll over it in the direction of travel
    draw = function(player, world, params)
        if not player.rollHit or player.dead then return end
        local lg = love.graphics
        local gx, gy = Iso.toScreen(player.x, player.y)
        local hx, hy = Iso.toScreen(player.x + math.cos(player.rollDir or 0), player.y + math.sin(player.rollDir or 0))
        local dx, dy = hx - gx, hy - gy
        local dl = math.sqrt(dx * dx + dy * dy) + 0.0001
        dx, dy = dx / dl, dy / dl
        local cx, cy = math.floor(gx) + 0.5, math.floor(gy - R + 2) + 0.5
        lg.setColor(0, 0, 0, 0.35)
        lg.ellipse("fill", cx, gy + 2, R + 1, (R + 1) * 0.45)
        lg.setColor(0.32, 0.12, 0.09, 1)
        lg.circle("fill", cx, cy, R)
        lg.setColor(0.6, 0.25, 0.17, 1)
        lg.circle("fill", cx - 0.6, cy - 0.8, R - 1.2)
        -- the plates: bands across the roll direction, scrolling with the roll
        local roll = (player.rollT or 0) * 2.2
        lg.setLineWidth(1)
        for i = 0, 6 do
            local th = ((i / 7 + roll) % 1) * math.pi
            local off, half = math.cos(th) * (R - 0.8), math.sin(th) * (R - 0.8)
            local lit = 0.35 + 0.65 * math.sin(th)
            lg.setColor(0.18 * lit + 0.08, 0.06, 0.04, 0.9)
            lg.line(cx + dx * off - dy * half, cy + dy * off + dx * half, cx + dx * off + dy * half, cy + dy * off - dx * half)
        end
        -- rim of legs tucked in, and a glint
        lg.setColor(0.75, 0.25, 0.16, 0.9)
        lg.circle("line", cx, cy, R)
        lg.setColor(1, 0.75, 0.6, 0.55)
        lg.circle("fill", cx - 2.5, cy - 3, 1.6)
        lg.setColor(1, 1, 1, 1)
    end,
    exit = function(player)
        player.hidden = nil
        player.rollHit = nil
        if player.guardMul and not player.coil then player.guardMul = nil end
        if player.chainPose == wheel then player.chainPose = nil end
    end,
})
