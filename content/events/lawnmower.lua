-- The lawnmower: an engine starts somewhere past the edge, a wide lane across the arena lights
-- up with warning stripes, and a few seconds later the blades tear along it. Nothing in the
-- lane survives the cut: get the ants in, get yourself out.
local Env = require("src.game.envfx")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

local WARN, PASS, W = 3.2, 0.9, 28

return {
    name = "Lawnmower!",
    description = "Get out of the striped lane before the blades come through.",
    color = { 1, 0.4, 0.3 },
    kind = "hazard",
    weight = 6, minWave = 7,
    start = function(world, ev)
        local st, p = ev.st, world.player
        st.x1, st.y1, st.x2, st.y2 = Env.crossing(world, p.x, p.y, 80)
        st.phase, st.pt, st.hit = "warn", 0, {}
        Audio.play("rumble", { pitch = 0.5 })
    end,
    update = function(world, ev, dt)
        local st = ev.st
        st.pt = st.pt + dt
        if st.phase == "warn" then
            if love.math.random() < dt * 3 then Audio.play("rumble", { pitch = 0.45 + st.pt / WARN * 0.3, volume = 0.5 }) end
            if st.pt >= WARN then
                -- place the mower at the lane start now: drawAir can run before the next update
                st.phase, st.pt, st.bx, st.by = "cut", 0, st.x1, st.y1
                Audio.play("boom", { pitch = 0.4 })
            end
        elseif st.phase == "cut" then
            local k = math.min(1, st.pt / PASS)
            st.bx, st.by = st.x1 + (st.x2 - st.x1) * k, st.y1 + (st.y2 - st.y1) * k
            local dx, dy = st.x2 - st.x1, st.y2 - st.y1
            local l = math.sqrt(dx * dx + dy * dy) + 0.0001
            -- the blades: the part of the lane under the mower right now
            local ax, ay = st.bx - dx / l * 30, st.by - dy / l * 30
            local kills = Env.strikeLane(world, ax, ay, st.bx, st.by, W, 999, { force = 260, kx = -dy, ky = dx, bossMul = 0.3 })
            st.kills = (st.kills or 0) + kills
            if not st.hitPlayer and Env.playerInLane(world, ax, ay, st.bx, st.by, W) then
                st.hitPlayer = true
                local p = world.player
                Env.hurtPlayer(world, 22, p.x - dy / l, p.y + dx / l, { force = 260 })
            end
            world.camera:shake(0.25)
            if love.math.random() < 0.8 then
                world.particles:burst(st.bx, st.by, 3, { { 0.35, 0.6, 0.25 }, { 0.5, 0.75, 0.3 } }, 160, 90, { grav = 300 })
            end
            if k >= 1 then
                st.phase, st.pt = "after", 0
                if st.kills >= 5 then world:floatText(st.x2, st.y2, st.kills .. " MOWED DOWN", { 1, 0.6, 0.4 }, true) end
            end
        elseif st.phase == "after" and st.pt >= 3 then
            ev.done = true
        end
    end,
    drawGround = function(world, ev)
        local st, lg = ev.st, love.graphics
        if st.phase == "warn" then
            local k = st.pt / WARN
            Env.warnLane(st.x1, st.y1, st.x2, st.y2, W, k, world.time, { 1, 0.75, 0.15 })
            -- hazard stripes crawling along the lane
            local dx, dy = st.x2 - st.x1, st.y2 - st.y1
            local l = math.sqrt(dx * dx + dy * dy) + 0.0001
            lg.setColor(0.1, 0.08, 0.05, 0.35 + 0.3 * k)
            local step = 34
            local off = (world.time * 60) % step
            for s = off, l - 12, step do
                local x, y = st.x1 + dx / l * s, st.y1 + dy / l * s
                Env.lane("fill", x, y, x + dx / l * 12, y + dy / l * 12, W)
            end
        elseif st.phase == "cut" or st.phase == "after" then
            -- a freshly mown strip
            local k = st.phase == "cut" and math.min(1, st.pt / PASS) or 1
            local a = st.phase == "after" and math.max(0, 1 - st.pt / 3) or 1
            lg.setColor(0.6, 0.75, 0.4, 0.25 * a)
            Env.lane("fill", st.x1, st.y1, st.x1 + (st.x2 - st.x1) * k, st.y1 + (st.y2 - st.y1) * k, W)
        end
    end,
    drawAir = function(world, ev)
        local st, lg = ev.st, love.graphics
        -- (the first frame of the pass is drawn before update has placed the deck)
        if st.phase ~= "cut" or not st.bx then return end
        -- the mower deck: a red box with a spinning glint
        local sx, sy = Iso.toScreen(st.bx, st.by, 10)
        lg.setColor(0, 0, 0, 0.4)
        lg.ellipse("fill", sx, sy + 12, 44, 20)
        lg.setColor(0.75, 0.15, 0.12, 1)
        lg.rectangle("fill", sx - 34, sy - 16, 68, 26, 6)
        lg.setColor(0.95, 0.3, 0.2, 1)
        lg.rectangle("fill", sx - 34, sy - 16, 68, 8, 6)
        lg.setColor(0.15, 0.12, 0.1, 1)
        lg.circle("fill", sx - 24, sy + 10, 7)
        lg.circle("fill", sx + 24, sy + 10, 7)
        lg.setColor(1, 1, 1, 0.8)
        local a = world.time * 40
        lg.line(sx - math.cos(a) * 20, sy + 4 - math.sin(a) * 4, sx + math.cos(a) * 20, sy + 4 + math.sin(a) * 4)
    end,
}
