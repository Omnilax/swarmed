-- Lots of kills in a short window.
return {
    name = "Blitz",
    description = "Get a lot of KOs within a few seconds.",
    weight = 10, minWave = 2,
    reward = { xp = 20, frenzy = 0.25 },
    params = { window = 8 },
    start = function(goal)
        goal.target, goal.times, goal.best = 20 + goal.wave * 3, {}, 0
    end,
    text = function(goal) return ("%d KOs within %d s  (best %d)"):format(goal.target, goal.def.params.window, goal.best) end,
    update = function(goal, world)
        local t, w = goal.times, goal.def.params.window
        while #t > 0 and t[1] < world.time - w do table.remove(t, 1) end
        goal.best = math.max(goal.best, #t)
        if #t >= goal.target then return "done" end
    end,
    on = {
        enemy_died = function(goal, world)
            local t = goal.times
            if #t < 400 then t[#t + 1] = world.time end
        end,
    },
}
