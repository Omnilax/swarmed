-- Flying ant (alate): flutters above the swarm circling you, then dives in to bite and climbs
-- away again. Only bites when it swoops low enough (see the bite rule in world.lua).
-- params: height (flight height, 16), orbit (circling distance, 75), dive (speed x, 2.3),
--         cooldown ({min, max} seconds between dives, {1.4, 3})
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local util = require("src.core.util")

return {
    name = "Flyer",
    init = function(e, world, params)
        local st = e.st
        st.mode, st.ang, st.dir = "fly", love.math.random() * 6.28, love.math.random() < 0.5 and -1 or 1
        local cd = params.cooldown or { 1.4, 3 }
        st.t = cd[1] + love.math.random() * (cd[2] - cd[1])
        e.z = params.height or 16
    end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local h = params.height or 16
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "fly" then
            st.ang = st.ang + st.dir * dt * 0.9
            local orbit = params.orbit or 75
            AI.goTo(e, p.x + math.cos(st.ang) * orbit, p.y + math.sin(st.ang) * orbit, e.speed)
            e.z = e.z + (h + math.sin(world.time * 7 + e.uid) * 2 - e.z) * math.min(1, dt * 4)
            st.t = st.t - dt
            if st.t <= 0 and d < orbit * 1.8 then st.mode, st.t = "dive", 1.0 end
        elseif st.mode == "dive" then
            -- swoop: home in on the player while dropping to the ground
            local s = e.speed * (params.dive or 2.3)
            e.mx, e.my = dx / d * s, dy / d * s
            e.z = math.max(0, e.z - dt * 45)
            st.t = st.t - dt
            if st.t <= 0 or (d < p.radius + e.radius + 1 and e.z < 3) then
                st.mode, st.t, st.dx, st.dy = "climb", 0.7, dx / d, dy / d
            end
        else -- climb out past the player
            local s = e.speed * 1.6
            e.mx, e.my = st.dx * s, st.dy * s
            e.z = math.min(h, e.z + dt * 35)
            st.t = st.t - dt
            if st.t <= 0 then
                local cd = params.cooldown or { 1.4, 3 }
                st.mode, st.t = "fly", cd[1] + love.math.random() * (cd[2] - cd[1])
                st.ang = math.atan2(e.y - p.y, e.x - p.x)
            end
        end
    end,
    -- warning: a red flicker as it tips into a dive
    draw = function(e)
        if e.st.mode ~= "dive" or e.z < 6 then return end
        local x, y = Iso.toScreen(e.x, e.y)
        love.graphics.setColor(1, 0.3, 0.2, 0.35)
        love.graphics.ellipse("line", x, y, 4, 2)
    end,
}
