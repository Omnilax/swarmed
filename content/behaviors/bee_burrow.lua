-- Mining bee: nests in burrows in bare ground. Lands, digs in and tunnels toward you under the
-- surface (a moving mound, untouchable), then picks a spot under your feet. A ring of cracking
-- earth warns you half a second before it bursts out and stings. Then it flies off and digs again.
-- params: approach (distance it lands at, 80), tunnel ({min, max} seconds, {1.4, 2.2}),
--         dig (underground speed x, 1.3), warn (0.55), blast (eruption radius, 14), mult (1.6)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

local DIRT = { 0.36, 0.27, 0.18 }

return {
    name = "Burrower",
    init = function(e) e.st.mode, e.st.t = "fly", 1 + love.math.random() end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        st.t = st.t - dt
        if st.mode == "fly" then
            e.hidden = nil
            AI.hover(e, world, dt, 8)
            local want = d > (params.approach or 80) and 1 or 0.2
            e.mx, e.my = (dx / d * want - dy / d * 0.4) * e.speed, (dy / d * want + dx / d * 0.4) * e.speed
            if st.t <= 0 and d < (params.approach or 80) * 1.3 then st.mode, st.t = "land", 0.35 end
        elseif st.mode == "land" then
            e.mx, e.my = 0, 0
            e.z = math.max(0, e.z - dt * 30)
            if st.t <= 0 then
                st.mode = "tunnel"
                local tn = params.tunnel or { 1.4, 2.2 }
                st.t = tn[1] + love.math.random() * (tn[2] - tn[1])
                e.hidden, e.z = true, 0
                world.particles:burst(e.x, e.y, 6, { DIRT }, 50, 40, { grav = 250 })
                Audio.play("hit", { pitch = 0.4 })
            end
        elseif st.mode == "tunnel" then
            local s = e.speed * (params.dig or 1.3)
            e.mx, e.my = dx / d * s, dy / d * s
            if love.math.random() < dt * 14 then
                world.particles:spawn(e.x, e.y, 1, (love.math.random() - 0.5) * 30, (love.math.random() - 0.5) * 30, 25, 0.5, DIRT, 1, { grav = 200 })
            end
            if st.t <= 0 or d < 6 then
                -- lock the spot under you and warn
                st.mode, st.t, st.tx, st.ty = "warn", params.warn or 0.55, p.x, p.y
            end
        elseif st.mode == "warn" then
            AI.goTo(e, st.tx, st.ty, e.speed * 2)
            if st.t <= 0 then
                e.hidden = nil
                e.x, e.y, e.z = st.tx, st.ty, 4
                local r = params.blast or 14
                local pd = math.sqrt((p.x - st.tx) ^ 2 + (p.y - st.ty) ^ 2)
                if pd < r + p.radius and not p.dead then
                    AI.sting(e, world, params.mult or 1.6)
                    p:knock(p.x - st.tx + 0.01, p.y - st.ty, 160)
                end
                world:addFx({ kind = "ring", x = st.tx, y = st.ty, r = r, life = 0.2, color = { 0.8, 0.6, 0.4 } })
                world.particles:burst(st.tx, st.ty, 12, { DIRT, { 0.5, 0.4, 0.3 } }, 90, 90, { grav = 300, stain = true })
                Audio.play("boom", { pitch = 1.6 })
                st.mode, st.t = "fly", 1.5 + love.math.random()
            end
        end
        e.biteCd = 1
    end,
    -- the mound of soil moving under the ground, and the cracking ring before it bursts out
    drawUnder = function(e, world)
        local st = e.st
        if st.mode == "tunnel" or st.mode == "warn" then
            local x, y = Iso.toScreen(e.x, e.y)
            love.graphics.setColor(DIRT[1], DIRT[2], DIRT[3], 0.9)
            love.graphics.ellipse("fill", x, y, 4, 2)
            love.graphics.setColor(0.55, 0.43, 0.3, 0.9)
            love.graphics.rectangle("fill", math.floor(x) - 1, math.floor(y) - 2, 2, 1)
        end
        if st.mode == "warn" then
            local x, y = Iso.toScreen(st.tx, st.ty)
            local r = (e.params.blast or 14) * (0.6 + 0.4 * st.t / (e.params.warn or 0.55))
            love.graphics.setColor(1, 0.65, 0.3, 0.55 + 0.35 * math.sin(st.t * 40))
            love.graphics.ellipse("line", x, y, r * 1.4, r * 0.7)
        end
    end,
}
