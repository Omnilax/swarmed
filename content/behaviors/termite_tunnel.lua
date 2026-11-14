-- Termite worker: travels underground. While buried it is a ridge of churned soil racing toward
-- you that nothing can hit; it bursts up right beside you, chews for a few seconds, then digs
-- back in and comes up somewhere else. Hit them while they are up.
-- params: surface (distance from the player where it breaks out, 22), up ({min, max} seconds
--         above ground before digging in again, {2.2, 3.4}), dig (seconds to dig in, 0.45),
--         under (speed x underground, 1.35), away (how far it tunnels off before turning back, 70)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

local SOIL = { { 0.36, 0.26, 0.17 }, { 0.5, 0.38, 0.24 }, { 0.24, 0.17, 0.11 } }

local function bury(e)
    e.hidden = true
    e.st.mode = "under"
end

-- Break out of the ground (also used by eggs hatching: the hatchlings start above ground).
local function surface(e, world, params)
    local st = e.st
    e.hidden = nil
    st.mode = "up"
    local up = (params and params.up) or { 2.2, 3.4 }
    st.t = up[1] + love.math.random() * (up[2] - up[1])
    e.squash = 0.25
    world.particles:burst(e.x, e.y, 7, SOIL, 60, 70, { grav = 300, stain = true })
end

return {
    name = "Tunneler",
    surface = surface,
    init = function(e, world, params)
        local st = e.st
        st.wt, st.side = love.math.random() * 6.28, love.math.random() < 0.5 and -1 or 1
        st.away = 0
        bury(e)
    end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "under" then
            st.wt = st.wt + dt * 4
            local s = e.speed * (params.under or 1.35)
            local nx, ny = dx / d, dy / d
            if st.away > 0 then
                -- tunnelling off sideways before swinging back in
                st.away = st.away - dt
                nx, ny = -ny * st.side - nx * 0.3, nx * st.side - ny * 0.3
            end
            local w = math.sin(st.wt) * 0.35
            e.mx, e.my = (nx - ny * w) * s, (ny + nx * w) * s
            if st.away <= 0 and d < (params.surface or 22) and not p.dead then surface(e, world, params) end
        elseif st.mode == "up" then
            e.mx, e.my = dx / d * e.speed, dy / d * e.speed
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.t = "dig", params.dig or 0.45 end
        else -- digging in: stops, sinks, and is gone
            e.mx, e.my = 0, 0
            st.t = st.t - dt
            if love.math.random() < dt * 20 then
                world.particles:spawn(e.x, e.y, 2, (love.math.random() - 0.5) * 50, (love.math.random() - 0.5) * 50, 40, 0.5, SOIL[love.math.random(3)], 1, { grav = 300 })
            end
            if st.t <= 0 then
                bury(e)
                st.away = ((params.away or 70) / math.max(1, e.speed)) * (0.6 + love.math.random() * 0.6)
                st.side = -st.side
            end
        end
    end,
    -- the tunnel: a ridge of soil heaving up behind it as it goes
    drawUnder = function(e, world)
        local st = e.st
        if st.mode == "up" then return end
        local lg = love.graphics
        local x, y = Iso.toScreen(e.x, e.y)
        if st.mode == "dig" then
            lg.setColor(0.3, 0.22, 0.14, 0.8)
            lg.ellipse("fill", x, y + 1, 4, 2)
            return
        end
        local vx, vy = e.mx, e.my
        local l = math.sqrt(vx * vx + vy * vy) + 0.001
        for i = 3, 0, -1 do
            local bx, by = Iso.toScreen(e.x - vx / l * i * 2.5, e.y - vy / l * i * 2.5)
            local h = 1 + math.sin(world.time * 14 + i + e.uid) * 0.5
            lg.setColor(0.2, 0.14, 0.09, 0.5 - i * 0.1)
            lg.ellipse("fill", bx, by + 1, 3 - i * 0.4, 1.6 - i * 0.2)
            lg.setColor(0.42, 0.31, 0.2, 0.9 - i * 0.2)
            lg.rectangle("fill", math.floor(bx - 1), math.floor(by - h), 2, 1)
        end
        lg.setColor(0.55, 0.42, 0.28, 0.9)
        lg.rectangle("fill", math.floor(x), math.floor(y - 2), 1, 1)
    end,
}
