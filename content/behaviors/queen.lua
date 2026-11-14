-- Queen: the boss of a species. Keeps her distance, slowly circling, and keeps laying broods of
-- her own species that pour out of her as marching columns. Get too close and she spawns a
-- guard burst and backs away.
-- params: brood (enemy id), interval (seconds between broods, 4), count (ants per brood, 10),
--         keep (distance from the player, 170), tire (seconds before she tires, 40: she stops
--         backing away and lays more slowly, so slow bugs can always corner her)
local AI = require("src.game.ai")
local Content = require("src.content")
local Audio = require("src.core.audio")

return {
    name = "Queen",
    init = function(e) e.st.cd, e.st.guardCd = 2, 0 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        st.age = (st.age or 0) + dt
        local tired = st.age > (params.tire or 40)
        if tired and not st.tired then
            st.tired = true
            world:floatText(e.x, e.y - 10, "Tired!", { 1, 0.8, 0.5 }, true)
        end
        local keep = tired and 0 or (params.keep or 170)
        local want = math.max(-1, math.min(1, (d - keep) / 40))
        local side = 0.6
        e.mx = (dx / d * want - dy / d * side) * e.speed
        e.my = (dy / d * want + dx / d * side) * e.speed
        st.cd = st.cd - dt
        st.guardCd = st.guardCd - dt
        local brood = Content.enemies:get(params.brood or "worker_ant")
        if not brood then return end
        local count = params.count or 10
        if d < 60 and st.guardCd <= 0 then
            st.guardCd, count = 5, math.ceil(count * 0.6)
            st.cd = 0
        end
        if st.cd <= 0 then
            st.cd = (params.interval or 4) * (tired and 1.6 or 1)
            local n = math.max(1, math.floor(count * (brood.spawn.groupSize or 1) ^ 0.5))
            world.spawner:spawnGroup(brood, n, e.x, e.y, { noElites = true })
            e.squash = 0.2
            Audio.play("dash", { pitch = 0.5 })
            world.particles:burst(e.x, e.y, 8, { { 0.9, 0.85, 0.7 } }, 60, 40)
        end
    end,
}
