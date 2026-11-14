-- A clutch of termite eggs on the floor. Sits still, starts to twitch, and hatches into a few
-- termites (above ground, ready to bite) unless it is destroyed first.
-- params: hatch ({min, max} seconds, {5, 7}), into (list of enemy ids, one picked per hatchling,
--         { "termite_worker" }), count (hatchlings, 3)
local Content = require("src.content")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

return {
    name = "Egg clutch",
    init = function(e, world, params)
        local h = params.hatch or { 5, 7 }
        e.st.t = h[1] + love.math.random() * (h[2] - h[1])
        e.anim = 0
    end,
    update = function(e, world, dt, params)
        local st = e.st
        e.mx, e.my, e.kvx, e.kvy = 0, 0, e.kvx * 0.5, e.kvy * 0.5
        st.t = st.t - dt
        -- twitching harder as hatching nears
        e.anim = st.t < 1.8 and (math.floor(world.time * (10 - st.t * 3)) % 2) or 0
        if st.t <= 0 then
            local into = params.into or { "termite_worker" }
            for i = 1, params.count or 3 do
                local def = Content.enemies:get(into[love.math.random(#into)])
                local a = i / (params.count or 3) * math.pi * 2 + love.math.random()
                local o = def and world:spawnEnemy(def, e.x + math.cos(a) * 4, e.y + math.sin(a) * 4)
                if o and o.behavior.surface then o.behavior.surface(o, world, o.params) end
            end
            world.particles:burst(e.x, e.y, 8, { { 0.95, 0.92, 0.82 }, { 0.8, 0.76, 0.6 } }, 50, 40, { stain = true, grav = 300 })
            Audio.play("dash", { pitch = 1.6 })
            -- the shells are left behind, not a kill
            e.dead = true
        end
    end,
    draw = function(e)
        if e.st.t > 1.8 then return end
        local x, y = Iso.toScreen(e.x, e.y)
        love.graphics.setColor(1, 0.95, 0.8, 0.25 + 0.25 * math.sin(e.st.t * 30))
        love.graphics.ellipse("line", x, y, 7, 3.5)
    end,
}
