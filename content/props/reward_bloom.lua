-- Reward bloom (src/game/rewardflow.lua): a glowing flower bud that sprouts next to the bug when a
-- wave is cleared. It holds the wave's rewards (the level-up cards waiting, then the item choice).
-- Walk into it to burst it open; Next Wave (E) pulls it to you, and left alone it rolls to you
-- by itself after a few seconds. Ants ignore it and it never holds a wave up.
local Config = require("src.config.bloom")

local GOLD = { 1, 0.85, 0.4 }
local QUEEN = { 1, 0.55, 0.4 }

local function tint(o) return (o.choice and o.choice.boss) and QUEEN or GOLD end

return {
    name = "Reward Bloom",
    description = "The wave's rewards. Walk into it to open it.",
    radius = 11,
    labelZ = 60,
    init = function(world, o)
        o.st.grow, o.st.burst, o.st.speed = 0, nil, Config.driftSpeed
    end,
    update = function(world, o, dt)
        local st, p = o.st, world.player
        st.grow = math.min(1, st.grow + dt * 2.2)
        if st.burst then
            st.burst = st.burst + dt
            if st.burst > 0.6 then o.dead = true end
            return
        end
        local pc = o.choice
        if not pc or pc.opened or world.pendingChoice ~= pc then
            -- its item choice went some other way (skipped by a test, the final swarm...)
            st.burst = 0.3
            return
        end
        if p.dead then return end
        local dx, dy = p.x - o.x, p.y - o.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d < p.radius + o.r + 2 then
            st.burst = 0
            world.rewardFlow:open(pc, o.x, o.y)
            return
        end
        -- rolls to you after a while (or at once when pulled with Next Wave)
        if o.pulled or o.t > Config.driftAfter then
            local target = o.pulled and Config.pullSpeed or st.speed
            st.speed = math.min(Config.pullSpeed, st.speed + Config.driftAccel * dt)
            local v = math.min(o.pulled and Config.pullSpeed or st.speed, target)
            local step = math.min(d, v * dt)
            o.x, o.y = o.x + dx / d * step, o.y + dy / d * step
        end
    end,
    draw = function(world, o, sx, sy)
        local lg, st = love.graphics, o.st
        local c = tint(o)
        local g = st.grow
        local pulse = 0.5 + 0.5 * math.sin(o.t * 4)
        local fade = st.burst and math.max(0, 1 - st.burst / 0.6) or 1
        -- a ring of light on the ground, so it reads from anywhere on screen
        lg.setColor(c[1], c[2], c[3], (0.18 + 0.12 * pulse) * g * fade)
        lg.ellipse("fill", sx, sy, 26 * g, 12 * g)
        lg.setColor(c[1], c[2], c[3], (0.55 + 0.3 * pulse) * g * fade)
        lg.setLineWidth(1)
        lg.ellipse("line", sx, sy, 28 * g + pulse * 3, 13 * g + pulse * 1.5)
        lg.setColor(0, 0, 0, 0.3 * g * fade)
        lg.ellipse("fill", sx, sy + 1, 8, 3)
        -- the stem
        if not st.burst then
            lg.setColor(0.25, 0.5, 0.2, g)
            lg.setLineWidth(2)
            lg.line(sx, sy, sx + 1, sy - 20 * g)
            lg.setLineWidth(1)
            lg.setColor(0.35, 0.62, 0.26, g)
            lg.polygon("fill", sx, sy - 5 * g, sx - 8 * g, sy - 9 * g, sx - 1, sy - 10 * g)
            lg.polygon("fill", sx + 1, sy - 7 * g, sx + 9 * g, sy - 11 * g, sx + 2, sy - 12 * g)
        end
        lg.setColor(1, 1, 1, 1)
    end,
    drawAir = function(world, o, sx, sy)
        local lg, st = love.graphics, o.st
        local c = tint(o)
        local g = st.grow
        local cx, cy = sx + 1, sy - 20 * g - 8
        if st.burst then
            -- petals fly open and fade
            local k = math.min(1, st.burst / 0.6)
            for i = 0, 5 do
                local a = i / 6 * math.pi * 2 + k
                local r = 6 + k * 22
                lg.setColor(c[1], c[2], c[3], 1 - k)
                lg.ellipse("fill", cx + math.cos(a) * r, cy + math.sin(a) * r * 0.55, 4, 2.5)
            end
            lg.setColor(1, 1, 1, 1)
            return
        end
        -- a beam of light above it
        local pulse = 0.5 + 0.5 * math.sin(o.t * 4)
        lg.setColor(c[1], c[2], c[3], (0.12 + 0.08 * pulse) * g)
        lg.rectangle("fill", cx - 4, cy - 90 * g, 8, 90 * g)
        lg.setColor(1, 1, 1, (0.1 + 0.06 * pulse) * g)
        lg.rectangle("fill", cx - 1, cy - 90 * g, 2, 90 * g)
        -- the bud: closed petals that breathe
        local sway = math.sin(o.t * 2.3) * 1.2
        local s = (1.35 + 0.12 * pulse) * g
        for i = -1, 1 do
            lg.setColor(c[1] * 0.75, c[2] * 0.6, c[3] * 0.5, g)
            lg.ellipse("fill", cx + i * 4 * s + sway, cy, 4.2 * s, 7.5 * s)
        end
        lg.setColor(c[1], c[2], c[3], g)
        lg.ellipse("fill", cx + sway, cy - 1, 4.5 * s, 8 * s)
        lg.setColor(1, 1, 0.9, (0.6 + 0.4 * pulse) * g)
        lg.circle("fill", cx + sway, cy - 3 * s, 1.6 * s)
        lg.setColor(1, 1, 1, 1)
    end,
    labels = function(world, o)
        if o.st.burst or o.st.grow < 0.5 then return nil end
        local pc = o.choice
        local c = tint(o)
        local head = pc and pc.boss and "QUEEN'S PRIZE" or (pc and pc.endless and "LEVEL REWARDS") or ("WAVE " .. ((pc and pc.wave) or "") .. " REWARDS")
        local what = world.rewardFlow and world.rewardFlow:contents() or ""
        local hint = o.pulled and "coming to you..." or "walk in to open"
        return {
            { text = head, color = c, z = 68 },
            { text = what ~= "" and (what .. "  ·  " .. hint) or hint, color = { 1, 0.95, 0.85 }, z = 58 },
        }
    end,
}
