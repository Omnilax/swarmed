-- Honeydew rain: aphids in the leaves overhead drip sweet honeydew. Every drop leaves a sticky
-- puddle: ants that wander in stop to feed (almost standing still) and you heal standing in one.
local Env = require("src.game.envfx")

return {
    name = "Honeydew Rain",
    description = "Sweet puddles: ants stop to feed in them, and they heal you.",
    color = { 1, 0.8, 0.35 },
    kind = "event",
    weight = 10, minWave = 2,
    duration = 16,
    start = function(world, ev)
        ev.st.drops, ev.st.pools, ev.st.cd = {}, {}, 0
    end,
    update = function(world, ev, dt)
        local st, p = ev.st, world.player
        st.cd = st.cd - dt
        -- drops fall for the first 11 s, near the player and anywhere
        if st.cd <= 0 and ev.t < 11 then
            st.cd = 0.55 + love.math.random() * 0.4
            local x, y
            if love.math.random() < 0.5 then x, y = Env.pointNear(world, p.x, p.y, 110) else x, y = Env.pointAway(world, 0, 40) end
            st.drops[#st.drops + 1] = { x = x, y = y, t = 0, fall = 0.8 }
        end
        for i = #st.drops, 1, -1 do
            local d = st.drops[i]
            d.t = d.t + dt
            if d.t >= d.fall then
                table.remove(st.drops, i)
                st.pools[#st.pools + 1] = { x = d.x, y = d.y, r = 16 + love.math.random() * 10, t = 0, life = 13 }
                world.particles:burst(d.x, d.y, 6, { { 1, 0.8, 0.35 }, { 1, 0.9, 0.55 } }, 50, 40, { grav = 300 })
            end
        end
        st.tick = (st.tick or 0) + dt
        local tick = st.tick >= 0.2
        if tick then st.tick = 0 end
        for i = #st.pools, 1, -1 do
            local pl = st.pools[i]
            pl.t = pl.t + dt
            if pl.t >= pl.life then table.remove(st.pools, i)
            else
                if tick then
                    -- feeding ants: nearly still while they lap it up
                    local list, n = world:queryEnemies(pl.x, pl.y, pl.r)
                    for j = 1, n do
                        local e = list[j]
                        if not e.dead and not e.def.boss and not e.def.encounter and (e.z or 0) < 4
                            and (e.x - pl.x) ^ 2 + (e.y - pl.y) ^ 2 < pl.r * pl.r then
                            e.slowT, e.slowMul = math.max(e.slowT, 0.3), math.min(e.slowT > 0 and e.slowMul or 1, 0.2)
                        end
                    end
                end
                if Env.playerIn(world, pl.x, pl.y, pl.r - 4) and not p.dead then
                    p:heal(4 * dt)
                    st.healed = (st.healed or 0) + 4 * dt
                end
            end
        end
    end,
    -- keep the puddles going a little after the rain (the event ends with the wave anyway)
    drawGround = function(world, ev)
        local lg = love.graphics
        for _, pl in ipairs(ev.st.pools) do
            local k = math.min(1, pl.t / 0.3, (pl.life - pl.t) / 1.5)
            lg.setColor(0.85, 0.6, 0.15, 0.55 * k)
            Env.ellipse("fill", pl.x, pl.y, pl.r)
            lg.setColor(1, 0.85, 0.4, 0.5 * k)
            Env.ellipse("fill", pl.x - pl.r * 0.2, pl.y - pl.r * 0.2, pl.r * 0.45)
            lg.setColor(1, 0.95, 0.7, 0.7 * k)
            Env.ellipse("line", pl.x, pl.y, pl.r)
        end
        for _, d in ipairs(ev.st.drops) do
            Env.shadow(d.x, d.y, 3 + 4 * d.t / d.fall, 0.4 + 0.5 * d.t / d.fall)
        end
    end,
    drawAir = function(world, ev)
        local lg = love.graphics
        local Iso = require("src.core.iso")
        for _, d in ipairs(ev.st.drops) do
            local h = (1 - d.t / d.fall) * 140
            local sx, sy = Iso.toScreen(d.x, d.y, h)
            lg.setColor(1, 0.82, 0.35, 0.95)
            lg.ellipse("fill", sx, sy, 2, 3)
            lg.setColor(1, 0.95, 0.75, 1)
            lg.rectangle("fill", math.floor(sx) - 1, math.floor(sy) - 2, 1, 1)
        end
    end,
}
