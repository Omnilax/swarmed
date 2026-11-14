-- Web grapple (orb weaver): fires a silk line where you point. Once it sticks, the line reels you
-- in like a real grappling hook: you speed up as you go, swing around the anchor if you were
-- moving sideways, and when you let go of Shift (or arrive) you fly on with all that momentum,
-- bowling ants over. Untouchable while on the line.
-- params: range (max length, 170), hookSpeed (line flight, 900), pull (acceleration, 1700),
--         reel (line shortening per second, 260), maxSpeed (520), ram (damage to ants hit fast, 6),
--         carry (share of speed kept when you let go, 0.95)
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local Combat = require("src.game.combat")
local util = require("src.core.util")

local function letGo(player, params)
    local g = player.grapple
    if g and g.state == "pull" and player.ropeVX then
        local carry = params.carry or 0.95
        player.momX, player.momY = player.ropeVX * carry, player.ropeVY * carry
        player.momDamp = 2.2
        player.dashHop, player.dashT, player.dashT0 = 0, 0, nil
    end
    player.ropeVX, player.ropeVY, player.grapple = nil, nil, nil
end

return {
    name = "Web Grapple",
    description = "Shoots a silk line where you point and reels you in with real momentum: swing around corners and let go of Shift to fly on.",
    start = function(player, world, dx, dy, params, px, py)
        local range = params.range or 170
        local tx, ty = px - player.x, py - player.y
        local d = math.sqrt(tx * tx + ty * ty)
        if d < 10 then tx, ty, d = dx * range, dy * range, range end
        d = math.min(d, range)
        local l = math.sqrt(tx * tx + ty * ty) + 0.001
        tx, ty = tx / l, ty / l
        player.grapple = { state = "fly", t = 0, hx = player.x, hy = player.y, tx = player.x + tx * d, ty = player.y + ty * d,
            dx = tx, dy = ty, hit = {} }
        player.dashT = 0
        Audio.play("dash", { pitch = 2 })
    end,
    update = function(player, world, dt, params)
        local g = player.grapple
        if not g then return end
        g.t = g.t + dt
        if g.state == "fly" then
            -- the silk shoots out to the target
            local sp = (params.hookSpeed or 900) * dt
            local rx, ry = g.tx - g.hx, g.ty - g.hy
            local rl = math.sqrt(rx * rx + ry * ry)
            if rl <= sp then
                g.hx, g.hy, g.state, g.t = g.tx, g.ty, "pull", 0
                g.len = math.sqrt((g.hx - player.x) ^ 2 + (g.hy - player.y) ^ 2)
                player.ropeVX, player.ropeVY = player.vx or 0, player.vy or 0
                world.particles:burst(g.hx, g.hy, 6, { { 1, 1, 0.95 } }, 50, 20)
                Audio.play("hit", { pitch = 2.2 })
            else
                g.hx, g.hy = g.hx + rx / rl * sp, g.hy + ry / rl * sp
            end
            return
        end
        -- reeling in: accelerate toward the anchor, the taut line turns sideways speed into a swing
        local ax, ay = g.hx - player.x, g.hy - player.y
        local d = math.sqrt(ax * ax + ay * ay) + 0.001
        local nx, ny = ax / d, ay / d
        local vx, vy = player.ropeVX, player.ropeVY
        local pull = params.pull or 1700
        vx, vy = vx + nx * pull * dt, vy + ny * pull * dt
        g.len = math.max(0, g.len - (params.reel or 260) * dt)
        if d > g.len then
            local out = -(vx * nx + vy * ny)
            if out > 0 then vx, vy = vx + nx * out, vy + ny * out end
        end
        local sp = math.sqrt(vx * vx + vy * vy)
        local maxSp = params.maxSpeed or 520
        if sp > maxSp then vx, vy, sp = vx / sp * maxSp, vy / sp * maxSp, maxSp end
        player.ropeVX, player.ropeVY = vx, vy
        player.iframes = math.max(player.iframes, 0.1)
        player.z = math.min(6, sp / 80)
        -- bowling through ants at speed
        if sp > 220 then
            for _, e in ipairs(Combat.collect(world, player.x, player.y, player.radius + 3)) do
                if not g.hit[e] then
                    g.hit[e] = true
                    local kx, ky = util.normalize(e.x - player.x, e.y - player.y)
                    Combat.damage(world, e, params.ram or 6, { knockback = sp * 0.6, kbx = kx + vx / sp, kby = ky + vy / sp })
                end
            end
        end
        if world.time % 0.03 < dt then
            world.particles:spawn(player.x, player.y, 3, 0, 0, 16, 0.25, { 0.95, 0.95, 0.9 }, 1, { grav = 0 })
        end
        local held = Input.down("dash") and not world.flags.demo
        if d < 12 or g.t > 1.4 or (not held and g.t > 0.12) then letGo(player, params) end
    end,
    draw = function(player, world)
        local g = player.grapple
        if not g then return end
        local Iso = require("src.core.iso")
        local x1, y1 = Iso.toScreen(player.x, player.y, 4 + (player.z or 0))
        local x2, y2 = Iso.toScreen(g.hx, g.hy, 2)
        local lg = love.graphics
        lg.setColor(0.95, 0.95, 0.9, 0.9)
        if g.state == "fly" then
            -- a loose line snaking out behind the silk ball
            local pts = {}
            for i = 0, 8 do
                local k = i / 8
                local wob = math.sin(k * math.pi) * math.sin(g.t * 40 + k * 9) * 2
                pts[#pts + 1], pts[#pts + 2] = x1 + (x2 - x1) * k, y1 + (y2 - y1) * k + wob
            end
            lg.line(pts)
        else
            lg.line(x1, y1, x2, y2)
        end
        lg.circle("fill", x2, y2, 1.5)
    end,
}
