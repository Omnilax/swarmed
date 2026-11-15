-- A courier ant dashes across the arena with a crumb for the queen. Catch it before it gets
-- out the other side.
return {
    name = "Stop the Courier",
    description = "A fast courier ant runs across the arena. Kill it before it escapes.",
    weight = 12, minWave = 2,
    reward = { xp = 25, frenzy = 0.3 },
    text = function(goal) return goal.courier and "Kill the courier before it escapes" or "A courier is coming..." end,
    start = function(goal) goal.at = 3 end,
    update = function(goal, world, dt)
        local sp = world.spawner
        if not goal.courier then
            if sp.waveTime < goal.at then return end
            local S = world.size
            local p = world.player
            -- from one edge to the one across, not too close to the player
            local a = love.math.random() * math.pi * 2
            for _ = 1, 6 do
                local x = S / 2 + math.cos(a) * S * 0.48
                local y = S / 2 + math.sin(a) * S * 0.48
                if (x - p.x) ^ 2 + (y - p.y) ^ 2 > 180 * 180 then break end
                a = a + 1
            end
            local x, y = S / 2 + math.cos(a) * S * 0.48, S / 2 + math.sin(a) * S * 0.48
            local e = world:spawnEnemy("courier_ant", x, y)
            if not e then return "failed" end
            e.st.tx, e.st.ty = S / 2 - math.cos(a) * S * 0.49, S / 2 - math.sin(a) * S * 0.49
            goal.courier, goal.uid = e, e.uid
            world:floatText(x, y, "COURIER!", { 1, 0.85, 0.4 }, true)
            return
        end
        local e = goal.courier
        if e.uid ~= goal.uid or e.dead then return e.escaped and "failed" or "done" end
    end,
    on = {
        enemy_died = function(goal, world, e) if e == goal.courier and e.uid == goal.uid then return "done" end end,
    },
    finish = function(goal) return goal.courier and not goal.courier.escaped and "done" or "failed" end,
}
