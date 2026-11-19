-- Sun and shade: patches of sunlight and leaf shade drift slowly over the ground. In the sun
-- everything moves faster (cold-blooded bugs warm up); in the shade the ants slow right down
-- while you don't. Fight from the shade.
-- params: sun (patches), shade (patches), size = { min, max } radius, drift (units/s),
-- sunSpeed (1.25), shadeSpeed (0.65)
local Env = require("src.game.envfx")

return {
    name = "Sun and Shade",
    description = "Sunny patches speed everyone up; in the shade the ants crawl.",
    start = function(world, m)
        local P = m.params
        m.st.patches = {}
        local size = P.size or { 45, 80 }
        for kind, n in pairs({ sun = P.sun or 3, shade = P.shade or 3 }) do
            for _ = 1, n do
                local x, y = Env.pointAway(world, 0, 60)
                local a = love.math.random() * math.pi * 2
                local v = (P.drift or 6) * (0.6 + love.math.random() * 0.8)
                m.st.patches[#m.st.patches + 1] = { kind = kind, x = x, y = y, r = size[1] + love.math.random() * (size[2] - size[1]),
                    vx = math.cos(a) * v, vy = math.sin(a) * v, seed = love.math.random() * 10 }
            end
        end
        table.sort(m.st.patches, function(a, b) return a.kind < b.kind end)
    end,
    update = function(world, m, dt)
        local S = world.size
        for _, p in ipairs(m.st.patches) do
            p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
            if p.x < p.r * 0.5 or p.x > S - p.r * 0.5 then p.vx = -p.vx end
            if p.y < p.r * 0.5 or p.y > S - p.r * 0.5 then p.vy = -p.vy end
        end
    end,
    field = function(world, m, x, y, who)
        local P = m.params
        for _, p in ipairs(m.st.patches) do
            if (x - p.x) ^ 2 + (y - p.y) ^ 2 < p.r * p.r then
                if p.kind == "sun" then return who == "player" and (P.sunPlayer or 1.15) or (P.sunSpeed or 1.25) end
                if who ~= "player" then return P.shadeSpeed or 0.65 end
                return 1
            end
        end
        return 1
    end,
    drawGround = function(world, m)
        local lg = love.graphics
        for _, p in ipairs(m.st.patches) do
            local wob = 1 + 0.03 * math.sin(world.time * 1.3 + p.seed)
            if p.kind == "sun" then
                lg.setColor(1, 0.9, 0.5, 0.16)
                Env.ellipse("fill", p.x, p.y, p.r * wob)
                lg.setColor(1, 0.95, 0.65, 0.18)
                Env.ellipse("fill", p.x, p.y, p.r * 0.65 * wob)
                lg.setColor(1, 0.9, 0.55, 0.35)
                Env.ellipse("line", p.x, p.y, p.r * wob)
            else
                lg.setColor(0.03, 0.06, 0.12, 0.32)
                Env.ellipse("fill", p.x, p.y, p.r * wob)
                lg.setColor(0.03, 0.06, 0.12, 0.2)
                Env.ellipse("fill", p.x + p.r * 0.2, p.y - p.r * 0.1, p.r * 0.5 * wob)
            end
        end
    end,
}
