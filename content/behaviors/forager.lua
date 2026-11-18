-- Desert ant (Saharan silver ant): forages alone in the midday heat that kills everything else.
-- Zigzags around searching, then sprints straight at you at blinding speed, overshoots, and has
-- to stop and cool off. Faster the brighter the day (see the Time of Day setting).
-- params: sight (150), sprint (speed x, 3.2), sprintTime (0.7), rest (cool-off seconds, 0.6),
--         zig (seconds per zigzag leg, 0.45), stagger (0.8)
local AI = require("src.game.ai")
local Combat = require("src.game.combat")

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 0.7, 0.66, 0.58 }
local PFX_2 = { grav = 40 }

return {
    name = "Heat sprinter",
    init = function(e) e.st.mode, e.st.t, e.st.head = "search", 0, 0 end,
    update = function(e, world, dt, params)
        local st = e.st
        local dx, dy, d = AI.toPlayer(e, world)
        local heat = 0.65 + 0.6 * world:daylight()
        if st.mode == "search" then
            st.t = st.t - dt
            if st.t <= 0 then
                st.t = (params.zig or 0.45) * (0.7 + love.math.random() * 0.6)
                st.head = math.atan2(dy, dx) + (love.math.random() < 0.5 and -1 or 1) * (0.5 + love.math.random() * 0.6)
            end
            local s = e.speed * heat
            e.mx, e.my = math.cos(st.head) * s, math.sin(st.head) * s
            if d < (params.sight or 150) then
                st.mode, st.t, st.dx, st.dy, e.hitPad = "sprint", params.sprintTime or 0.7, dx / d, dy / d, 4
            end
        elseif st.mode == "sprint" then
            local s = e.speed * (params.sprint or 3.2) * heat
            e.mx, e.my = st.dx * s, st.dy * s
            st.t = st.t - dt
            if love.math.random() < dt * 20 then
                world.particles:spawn(e.x, e.y, 1, -st.dx * 20, -st.dy * 20, 10, 0.3, PFX_1, 1, PFX_2)
            end
            if st.t <= 0 then st.mode, st.t, e.hitPad = "rest", params.rest or 0.6, 0 end
        else -- rest / stagger: stand still (cooling off on a grass stalk)
            e.mx, e.my = dx / d * 0.5, dy / d * 0.5
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.t = "search", 0 end
        end
    end,
    onHit = function(e, world, opts)
        if e.st.mode ~= "sprint" then return 1 end
        Combat.stagger(world, e, e.params.stagger or 0.8, opts)
        return 1.5
    end,
    draw = function(e) if e.st.mode == "stagger" then Combat.drawDazed(e) end end,
}
