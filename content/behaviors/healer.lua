-- Honeypot: hangs back behind the swarm and lobs honey onto the floor near hurt allies (or in
-- front of the player). Ants standing in honey heal; the player wades through it slowly.
-- params: keep (distance from player, 150), cooldown (4), radius (puddle, 26), life (9),
--         heal (hp/s, 3), slow (player speed multiplier, 0.5)
local AI = require("src.game.ai")
local util = require("src.core.util")

return {
    name = "Honey healer",
    init = function(e) e.st.cd = 1.5 + love.math.random() * 2 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        local keep = params.keep or 150
        -- hold a distance from the player, drifting sideways
        local want = (d - keep) / 30
        local side = math.sin(world.time * 0.7 + e.uid) * 0.6
        local mx, my = dx / d * util.clamp(want, -1, 1) - dy / d * side, dy / d * util.clamp(want, -1, 1) + dx / d * side
        local l = math.sqrt(mx * mx + my * my) + 0.0001
        e.mx, e.my = mx / l * e.speed * math.min(1, l), my / l * e.speed * math.min(1, l)
        st.cd = st.cd - dt
        if st.cd <= 0 then
            st.cd = params.cooldown or 4
            -- most hurt ant nearby, else the patch between us and the player
            local tx, ty = e.x + dx * 0.55, e.y + dy * 0.55
            local list, n = world:queryEnemies(e.x, e.y, 140)
            local worst = 0.85
            for i = 1, n do
                local o = list[i]
                local k = o.hp / o.maxHp
                if o ~= e and not o.dead and k < worst then worst, tx, ty = k, o.x, o.y end
            end
            world.hazards:addZone({ kind = "honey", x = tx, y = ty, r = params.radius or 26, life = params.life or 9,
                heal = params.heal or 3, slow = params.slow or 0.5, color = { 0.95, 0.66, 0.16 } })
            world.particles:burst(tx, ty, 8, { { 1, 0.75, 0.25 }, { 0.9, 0.55, 0.1 } }, 50, 40)
            e.squash = 0.15
        end
    end,
}
