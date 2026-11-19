-- Neotenic termite (a brood maker): a stand-in reproductive that waddles around behind the
-- fighting, swollen with eggs, and lays clutches on the floor. Each clutch hatches into fresh
-- termites a few seconds later unless you stamp it out. It shies away when you get close.
-- params: keep (distance from the player, 150), interval (seconds between clutches, 5),
--         maxClutches (alive at once per layer, 3), egg (enemy id, "termite_eggs")
local AI = require("src.game.ai")
local Content = require("src.content")
local util = require("src.core.util")

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 0.95, 0.92, 0.82 }
local PFX_LIST_1 = { PFX_1 }

return {
    name = "Egg layer",
    init = function(e) e.st.cd, e.st.clutches = 2 + love.math.random() * 2, {} end,
    update = function(e, world, dt, params)
        local st = e.st
        local dx, dy, d = AI.toPlayer(e, world)
        local keep = params.keep or 150
        local want = util.clamp((d - keep) / 30, -1.6, 1)
        local side = math.sin(world.time * 0.6 + e.uid) * 0.5
        local mx, my = dx / d * want - dy / d * side, dy / d * want + dx / d * side
        local l = math.sqrt(mx * mx + my * my) + 0.0001
        local s = e.speed * math.min(1.4, l)
        e.mx, e.my = mx / l * s, my / l * s
        st.cd = st.cd - dt
        if st.cd <= 0 then
            st.cd = params.interval or 5
            -- count this layer's clutches still on the floor
            local alive = 0
            for i = #st.clutches, 1, -1 do
                local c = st.clutches[i]
                if c.e.uid ~= c.uid or c.e.dead then table.remove(st.clutches, i) else alive = alive + 1 end
            end
            local egg = Content.enemies:get(params.egg or "termite_eggs")
            if egg and alive < (params.maxClutches or 3) then
                -- dropped just behind it
                local o = world:spawnEnemy(egg, e.x - dx / d * 6, e.y - dy / d * 6)
                if o then
                    st.clutches[#st.clutches + 1] = { e = o, uid = o.uid }
                    e.squash = 0.25
                    world.particles:burst(o.x, o.y, 5, PFX_LIST_1, 30, 20)
                end
            end
        end
    end,
}
