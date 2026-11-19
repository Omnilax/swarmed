-- Stingless bee: no sting, but it smears sticky plant resin. Every bee that dives into you
-- gums up your jaws a little more: your attacks recharge slower (it stacks), then wears off.
-- params: gum (attack speed x per smear, 0.8), gumTime (3.5), cooldown (1.3), height (6)
local AI = require("src.game.ai")

local RESIN = { 0.95, 0.65, 0.2 }

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { grav = 150, stain = true }

return {
    name = "Resin smear",
    init = function(e) e.st.cd, e.st.ph = love.math.random(), love.math.random() * 6.28 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        e.biteCd = 1
        st.cd = st.cd - dt
        st.ph = st.ph + dt * 8
        local back = st.cd > 0 and d < 40 and -0.7 or 1       -- peel off after a smear
        local nx, ny = dx / d * back + math.cos(st.ph) * 0.6, dy / d * back + math.sin(st.ph) * 0.6
        local l = math.sqrt(nx * nx + ny * ny) + 0.0001
        e.mx, e.my = nx / l * e.speed, ny / l * e.speed
        AI.hover(e, world, dt, (st.cd <= 0 and d < 26) and 1 or (params.height or 6))
        if st.cd <= 0 and d < p.radius + e.radius + 1.5 and e.z < 3 and p.dashT <= 0 and not p.dead then
            st.cd = params.cooldown or 1.3
            AI.sting(e, world, 1)
            p:gum(params.gum or 0.8, params.gumTime or 3.5)
            world.particles:burst(p.x, p.y, 4, { RESIN }, 30, 25, PFX_1)
            if p.gumMul < 0.6 and not world.flags.resinHint then
                world.flags.resinHint = true
                world:floatText(p.x, p.y, "Jaws gummed up with resin!", { 1, 0.75, 0.3 }, false)
            end
        end
    end,
}
