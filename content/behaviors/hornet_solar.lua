-- Oriental hornet: the yellow band on its abdomen really does catch sunlight and turn it into
-- energy. It soaks up light (glowing brighter, much faster in full day than at night) and when
-- it's full it blazes: a straight, very fast charge that leaves a trail of burning ground.
-- params: soak (charge per second at night, 0.08), sun (extra per second in full day, 0.32),
--         windup (0.5), dash (speed x, 4.2), dashTime (0.55), trail (fire damage per second, 8),
--         stagger (0.9)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

local function fireDraw(z, sx, sy, fade)
    local lg = love.graphics
    local f = 0.7 + 0.3 * math.sin(z.t * 25 + z.x)
    lg.setColor(1, 0.45, 0.1, 0.45 * fade * f)
    lg.ellipse("fill", sx, sy, z.r * 1.3, z.r * 0.65)
    lg.setColor(1, 0.85, 0.35, 0.6 * fade * f)
    lg.ellipse("fill", sx, sy, z.r * 0.6, z.r * 0.3)
end

return {
    name = "Solar charge",
    init = function(e) e.st.mode, e.st.charge = "hunt", love.math.random() * 0.4 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "hunt" then
            AI.hover(e, world, dt, d < 26 and 1 or 7)
            e.mx, e.my = dx / d * e.speed, dy / d * e.speed
            st.charge = st.charge + dt * ((params.soak or 0.08) + (params.sun or 0.32) * world:daylight())
            if st.charge >= 1 and d < 150 then st.mode, st.t = "windup", params.windup or 0.5 end
        elseif st.mode == "windup" then
            e.mx, e.my = dx / d * 2, dy / d * 2
            AI.hover(e, world, dt, 3)
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.t, st.dx, st.dy, st.drop = "blaze", params.dashTime or 0.55, dx / d, dy / d, 0 end
        elseif st.mode == "blaze" then
            e.biteCd = 1
            AI.hover(e, world, dt, 1)
            local s = e.speed * (params.dash or 4.2)
            e.mx, e.my = st.dx * s, st.dy * s
            st.t = st.t - dt
            st.drop = st.drop - dt
            if st.drop <= 0 then
                st.drop = 0.06
                world.hazards:addZone({ kind = "fire", x = e.x, y = e.y, r = 7, life = 2.5, damage = params.trail or 8,
                    color = { 1, 0.5, 0.1 }, draw = fireDraw })
            end
            if not st.stung and d < p.radius + e.radius + 2 and not p.dead then
                st.stung = true
                AI.sting(e, world, 1.5)
            end
            if st.t <= 0 then st.mode, st.charge, st.stung = "hunt", 0, nil end
        else -- staggered
            e.mx, e.my = 0, 0
            st.t = st.t - dt
            if st.t <= 0 then st.mode = "hunt" end
        end
    end,
    onHit = function(e, world, opts)
        if e.st.mode == "windup" then
            Combat.stagger(world, e, e.params.stagger or 0.9, opts)
            e.st.charge = 0.5
        end
        return 1
    end,
    -- a glow that builds with the stored sunlight
    drawUnder = function(e)
        local st = e.st
        local c = math.min(1, st.charge or 0)
        if c < 0.15 and st.mode ~= "blaze" then return end
        local x, y = Iso.toScreen(e.x, e.y)
        love.graphics.setColor(1, 0.85, 0.3, 0.12 + 0.3 * c)
        love.graphics.ellipse("fill", x, y, 4 + c * 6, 2 + c * 3)
    end,
    draw = function(e)
        local st = e.st
        if st.mode == "stagger" then Combat.drawDazed(e) return end
        if st.mode ~= "windup" then return end
        local x1, y1 = Iso.toScreen(e.x, e.y)
        love.graphics.setColor(1, 0.8, 0.3, 0.5 + 0.4 * math.sin(st.t * 40))
        love.graphics.circle("line", x1, y1 - e.z, 6 + 4 * (1 - st.t / (e.params.windup or 0.5)))
    end,
}
