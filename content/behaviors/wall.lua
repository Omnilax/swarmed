-- Leafcutter wall: these ants close in and then hold a ring around the player, shoulder to
-- shoulder (they are `solid`, so you have to cut through or dash past). The ring drifts with you.
-- A wall of fewer than `minWall` ants is no wall: they close in and bite instead (so a lone
-- straggler can't hover just out of reach of short-range bugs forever).
-- params: ring (radius around the player, 34), engage (start forming the wall within, 120), minWall (3)
local AI = require("src.game.ai")

return {
    name = "Shield wall",
    init = function(e) e.st.slot = (e.uid * 2.39996) % (math.pi * 2) end,
    update = function(e, world, dt, params)
        local p = world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if d > (params.engage or 120) then
            e.mx, e.my = dx / d * e.speed, dy / d * e.speed
            return
        end
        local st = e.st
        st.countT = (st.countT or 0) - dt
        if st.countT <= 0 then
            st.countT = 0.5
            local near, m = world:queryEnemies(p.x, p.y, (params.ring or 34) + p.radius + 30)
            local c = 0
            for i = 1, m do if near[i].def == e.def and not near[i].dead then c = c + 1 end end
            st.mates = c
        end
        local ring = (params.ring or 34) + p.radius
        if (st.mates or 0) < (params.minWall or 3) then ring = p.radius + e.radius end
        local a = e.st.slot
        -- keep slots evenly spread: nudge away from neighbours in the ring
        local list, n = world:queryEnemies(e.x, e.y, 14)
        for i = 1, n do
            local o = list[i]
            if o ~= e and o.def == e.def and o.st.slot then
                local diff = (a - o.st.slot + math.pi) % (math.pi * 2) - math.pi
                a = a + (diff >= 0 and 1 or -1) * dt * 0.8
            end
        end
        e.st.slot = a
        AI.goTo(e, p.x + math.cos(a) * ring, p.y + math.sin(a) * ring, e.speed * 1.3)
    end,
}
