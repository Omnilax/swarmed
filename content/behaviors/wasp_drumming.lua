-- Warrior wasp (Synoeca): when the nest is disturbed the whole colony drums on it in unison,
-- a loud rhythmic warning, and then attacks together. These ones surround you in a ring and
-- drum (the beat speeds up), then every one of them dives at once. Break out of the ring
-- during the drumming, or be where they aren't when the beat stops.
-- params: ring (radius, 70), drum (seconds, 1.8), strike (0.55), rest (1.6), dive (speed x, 3.4)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

return {
    name = "War drums",
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local list, g = AI.group(world, e.def.id)
        local n = #list
        -- the first wasp keeps the colony's rhythm
        if st.rank == 1 then
            g.phase = g.phase or "gather"
            g.t = (g.t or 2.5) - dt
            g.rot = (g.rot or 0) + dt * 0.3
            if g.phase == "drum" then
                g.beat = (g.beat or 0) - dt
                if g.beat <= 0 then
                    g.beat = 0.12 + 0.25 * math.max(0, g.t / (params.drum or 1.8))
                    g.pulse = 1
                    Audio.play("hit", { pitch = 0.35 })
                end
            end
            g.pulse = math.max(0, (g.pulse or 0) - dt * 6)
            if g.t <= 0 then
                if g.phase == "gather" then g.phase, g.t = "drum", params.drum or 1.8
                elseif g.phase == "drum" then g.phase, g.t = "strike", params.strike or 0.55
                elseif g.phase == "strike" then g.phase, g.t = "rest", params.rest or 1.6
                else g.phase, g.t = "gather", 1.2 end
            end
        end
        local phase = g.phase or "gather"
        local dx, dy, d = AI.toPlayer(e, world)
        e.biteCd = 1
        if phase == "strike" then
            if not st.dived then st.dived, st.dx, st.dy = true, dx / d, dy / d end
            AI.hover(e, world, dt, 1)
            local s = e.speed * (params.dive or 3.4)
            e.mx, e.my = st.dx * s, st.dy * s
            if not st.stung and d < p.radius + e.radius + 2 and not p.dead then
                st.stung = true
                AI.sting(e, world, 1)
            end
        else
            st.dived, st.stung = nil, nil
            local a = (st.rank or 1) / math.max(1, n) * math.pi * 2 + (g.rot or 0)
            local r = params.ring or 70
            AI.hover(e, world, dt, phase == "drum" and 4 + (g.pulse or 0) * 3 or 8)
            AI.goTo(e, p.x + math.cos(a) * r, p.y + math.sin(a) * r, e.speed * (phase == "rest" and 0.8 or 1.4))
            if phase == "drum" then
                -- face you while drumming
                e.mx, e.my = e.mx + dx / d * 3, e.my + dy / d * 3
                e.squash = (g.pulse or 0) * 0.1
            end
        end
    end,
    -- each beat sends a little ring out from every drummer
    draw = function(e, world)
        local _, g = AI.group(world, e.def.id)
        if g.phase ~= "drum" or (g.pulse or 0) <= 0 then return end
        local x, y = Iso.toScreen(e.x, e.y)
        local k = 1 - g.pulse
        love.graphics.setColor(1, 0.6, 0.25, 0.6 * g.pulse)
        love.graphics.ellipse("line", x, y, 4 + k * 10, 2 + k * 5)
    end,
}
