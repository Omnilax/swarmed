-- A paper wasp nest: doesn't move, and every few seconds a new wasp crawls out of a cell
-- (until it has released `brood`). Break it to stop them.
-- params: brood (enemy id, "paper_wasp"), interval (4), max (5)
local Audio = require("src.core.audio")

return {
    name = "Wasp nest",
    init = function(e) e.st.t, e.st.out, e.st.age = 2.5, 0, 0 end,
    update = function(e, world, dt, params)
        local st = e.st
        e.mx, e.my, e.kvx, e.kvy = 0, 0, 0, 0
        st.age = st.age + dt
        e.scale = e.baseScale * math.min(1, 0.6 + st.age * 0.4)      -- grows as it's finished off
        st.t = st.t - dt
        if st.t <= 0 and st.out < (params.max or 5) then
            st.t = params.interval or 4
            st.out = st.out + 1
            local w = world:spawnEnemy(params.brood or "paper_wasp", e.x + (love.math.random() - 0.5) * 6, e.y + (love.math.random() - 0.5) * 6)
            if w then w.st.built, w.st.nest, w.st.nestUid, w.st.mode = true, e, e.uid, "guard" end
            e.squash = 0.15
            Audio.play("hit", { pitch = 1.7 })
        end
        e.biteCd = 1
    end,
}
