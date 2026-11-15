-- A shrinking lawn: the long grass round the edge grows back in as each wave goes on, closing
-- the space you can move in (the ants come through it fine). It is cut back in the breaks.
-- params: most (share of the arena's half-width it can close in, 0.25), time (seconds to close
-- fully, 50), from (first wave it closes in, 1)
local Env = require("src.game.envfx")

return {
    name = "Shrinking Lawn",
    description = "The long grass closes in during each wave, squeezing the space you have.",
    start = function(world, m) m.st.inset = 0 end,
    update = function(world, m, dt)
        local P, st, sp = m.params, m.st, world.spawner
        local most = world.size * 0.5 * (P.most or 0.25)
        local want = 0
        if sp.phase == "wave" and sp.wave >= (P.from or 1) then want = most * math.min(1, sp.waveTime / (P.time or 50)) end
        if want > st.inset then st.inset = math.min(want, st.inset + dt * 20)
        else st.inset = math.max(want, st.inset - dt * 60) end
    end,
    env = function(world, m, env) env.inset = math.max(env.inset, m.st.inset) end,
    drawGround = function(world, m)
        local lg, S, d = love.graphics, world.size, m.st.inset
        if d < 1 then return end
        -- a band of dark long grass between the walls and the line it has reached
        lg.setColor(0.07, 0.16, 0.06, 0.92)
        Env.poly("fill", { 0, 0, S, 0, S, d, 0, d })
        Env.poly("fill", { 0, S - d, S, S - d, S, S, 0, S })
        Env.poly("fill", { 0, d, d, d, d, S - d, 0, S - d })
        Env.poly("fill", { S - d, d, S, d, S, S - d, S - d, S - d })
        -- blades along the edge of it
        local Iso = require("src.core.iso")
        lg.setColor(0.42, 0.72, 0.28, 1)
        local step = 9
        for u = d, S - d, step do
            local sway = math.sin(world.time * 2 + u * 0.1) * 1.5
            for _, pt in ipairs({ { u, d }, { u, S - d }, { d, u }, { S - d, u } }) do
                local sx, sy = Iso.toScreen(pt[1], pt[2])
                lg.line(sx, sy, sx + sway, sy - 11)
                lg.line(sx + 3, sy, sx + 3 + sway * 0.6, sy - 7)
            end
        end
        lg.setColor(0.85, 1, 0.5, 0.5 + 0.3 * math.sin(world.time * 4))
        lg.setLineWidth(2)
        Env.poly("line", { d, d, S - d, d, S - d, S - d, d, S - d })
        lg.setLineWidth(1)
    end,
}
