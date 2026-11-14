-- Orchid bee: glittering green males that collect perfumes from orchids. This one hangs back
-- over the swarm and leaves clouds of scent behind; every ant that passes through one is driven
-- into a frenzy and runs faster. Kill it first and the swarm calms down.
-- params: keep (distance from you, 120), cooldown (2.6), radius (cloud, 22), life (5),
--         haste (speed x for ants in a cloud, 1.5)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local util = require("src.core.util")

local function cloudUpdate(world, z, dt)
    local list, n = world:queryEnemies(z.x, z.y, z.r)
    for i = 1, n do
        local o = list[i]
        if not o.dead and (o.x - z.x) ^ 2 + (o.y - z.y) ^ 2 < z.r * z.r and (o.slowT <= 0.05 or o.slowMul >= 1) then
            o.slowT, o.slowMul = 0.25, z.haste
        end
    end
end

local function cloudDraw(z, sx, sy, fade)
    local lg = love.graphics
    for i = 0, 4 do
        local a = z.t * 0.8 + i * 1.26
        local ox, oy = math.cos(a) * z.r * 0.45, math.sin(a) * z.r * 0.22
        lg.setColor(i % 2 == 0 and 0.75 or 0.4, i % 2 == 0 and 0.45 or 0.95, 0.9, 0.12 * fade)
        lg.ellipse("fill", sx + ox, sy + oy, z.r * 0.7, z.r * 0.35)
    end
    lg.setColor(1, 0.9, 1, 0.5 * fade)
    for i = 0, 5 do
        local a = z.t * 2 + i
        lg.rectangle("fill", math.floor(sx + math.cos(a) * z.r * 0.8), math.floor(sy + math.sin(a * 1.3) * z.r * 0.35 - 2), 1, 1)
    end
end

return {
    name = "Perfume trail",
    init = function(e) e.st.cd, e.st.ang = 1 + love.math.random() * 2, love.math.random() * 6.28 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        AI.hover(e, world, dt, 10)
        -- drift over the thickest part of the crowd, staying out of your reach
        local keep = params.keep or 120
        local o = AI.nearestOther(world, e, e.x, e.y, 90)
        local want = util.clamp((d - keep) / 30, -1, 1)
        st.ang = st.ang + dt * 0.5
        local mx, my = dx / d * want + math.cos(st.ang) * 0.4, dy / d * want + math.sin(st.ang) * 0.4
        if o and d > keep * 0.7 then mx, my = mx + (o.x - e.x) * 0.02, my + (o.y - e.y) * 0.02 end
        local l = math.sqrt(mx * mx + my * my) + 0.0001
        e.mx, e.my = mx / l * e.speed, my / l * e.speed
        st.cd = st.cd - dt
        if st.cd <= 0 then
            st.cd = params.cooldown or 2.6
            world.hazards:addZone({ kind = "perfume", x = e.x, y = e.y, r = params.radius or 22, life = params.life or 5,
                haste = params.haste or 1.5, color = { 0.7, 0.5, 0.9 }, update = cloudUpdate, draw = cloudDraw })
        end
    end,
}
