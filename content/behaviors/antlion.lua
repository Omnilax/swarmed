-- Antlion (boss encounter): sits at the bottom of a sand pit `pit` wide. The slope drags the
-- player (up to `pull` units/s, strongest near the middle) and ants (`antPull`) down; ants that
-- reach the jaws are eaten, the player gets bitten for `bite`. Every `flick` s it throws
-- `shots` lumps of sand at the player (they can be batted back).
-- params: pit (95), pull (34), antPull (55), bite (12), flick (3.2), shots (3), shotDamage (6)
local Env = require("src.game.envfx")
local Audio = require("src.core.audio")

return {
    name = "Antlion pit",
    init = function(e)
        e.st.flick, e.st.biteCd, e.st.age = 2, 0, 0
    end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        e.mx, e.my = 0, 0
        e.kvx, e.kvy = 0, 0
        st.age = st.age + dt
        if st.snap then st.snap = st.snap - dt if st.snap <= 0 then st.snap = nil end end
        local R = (params.pit or 95) * math.min(1, st.age / 1.5)
        -- the player slides toward the middle (not while dashing or in the air)
        local dx, dy = e.x - p.x, e.y - p.y
        local d = math.sqrt(dx * dx + dy * dy) + 0.0001
        if not p.dead and d < R and p.dashT <= 0 and (p.z or 0) < 4 then
            local s = ((params.pull or 34) * (1 - d / R) + 8) * dt
            p.x, p.y = p.x + dx / d * math.min(s, d), p.y + dy / d * math.min(s, d)
            if d < e.radius + p.radius + 4 then
                st.biteCd = st.biteCd - dt
                if st.biteCd <= 0 then
                    st.biteCd, st.snap = 1.1, 0.25
                    Env.hurtPlayer(world, params.bite or 12, e.x, e.y, { force = 60, name = "antlion" })
                    Audio.play("hit", { pitch = 0.5 })
                end
            end
        end
        -- ants slide in and get eaten at the bottom
        local list, n = world:queryEnemies(e.x, e.y, R)
        for i = 1, n do
            local o = list[i]
            if o ~= e and not o.dead and not o.hidden and (o.z or 0) < 4 and not o.def.encounter and not o.def.boss and not o.dropH then
                local ox, oy = e.x - o.x, e.y - o.y
                local od = math.sqrt(ox * ox + oy * oy) + 0.0001
                if od < R then
                    local s = ((params.antPull or 55) * (1 - od / R) + 10) * dt
                    o.x, o.y = o.x + ox / od * math.min(s, od), o.y + oy / od * math.min(s, od)
                    if od < e.radius + 2 then
                        st.snap = 0.25
                        Env.hurtAnt(world, o, 999)
                    end
                end
            end
        end
        -- flick sand at the player
        st.flick = st.flick - dt
        if st.flick <= 0 and not p.dead then
            st.flick = params.flick or 3.2
            local T = 0.9
            for k = 1, params.shots or 3 do
                local tx = p.x + (p.vx or 0) * T * 0.6 + (love.math.random() - 0.5) * 50
                local ty = p.y + (p.vy or 0) * T * 0.6 + (love.math.random() - 0.5) * 50
                world.hazards:shoot({ x = e.x, y = e.y, z = 4, vx = (tx - e.x) / T, vy = (ty - e.y) / T,
                    vz = (1 - 4 + 300 * T * T / 2) / T, grav = 300, r = 3, damage = params.shotDamage or 6,
                    life = T + 0.3, color = { 0.78, 0.66, 0.42 }, pebble = true,
                    lob = { x = tx, y = ty, r = 12, slow = 0.6, slowTime = 0.8, flight = T } })
            end
            Audio.play("dash", { pitch = 1.4 })
        end
        st.R = R
    end,
    -- the pit itself, under everything
    drawUnder = function(e, world)
        local lg = love.graphics
        local R = e.st.R or 0
        if R < 2 then return end
        local rings = { { 1, 0.82, 0.7, 0.48 }, { 0.8, 0.74, 0.62, 0.42 }, { 0.6, 0.64, 0.53, 0.36 }, { 0.4, 0.52, 0.42, 0.28 }, { 0.2, 0.35, 0.27, 0.18 } }
        for _, r in ipairs(rings) do
            lg.setColor(r[2], r[3], r[4], 0.9)
            Env.ellipse("fill", e.x, e.y, R * r[1])
        end
        -- sand trickling down in a slow swirl
        lg.setColor(0.9, 0.82, 0.6, 0.6)
        local Iso = require("src.core.iso")
        for i = 1, 14 do
            local a = i / 14 * math.pi * 2 + world.time * 0.6
            local rr = R * (0.25 + ((i * 0.37 + world.time * 0.3) % 0.75))
            local sx, sy = Iso.toScreen(e.x + math.cos(a) * rr, e.y + math.sin(a) * rr)
            lg.rectangle("fill", math.floor(sx), math.floor(sy), 1, 1)
        end
        lg.setColor(0.95, 0.88, 0.68, 0.5)
        Env.ellipse("line", e.x, e.y, R)
    end,
}
