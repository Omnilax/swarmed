-- Reach a big combo this wave.
return {
    name = "Combo Hunter",
    description = "Reach a big kill combo during the wave.",
    weight = 10, minWave = 2,
    reward = { xp = 20, frenzy = 0.25 },
    start = function(goal) goal.target, goal.best = 30 + goal.wave * 5, 0 end,
    text = function(goal) return ("Reach a %d-hit combo  (best %d)"):format(goal.target, goal.best) end,
    update = function(goal, world)
        goal.best = math.max(goal.best, world.combo)
        if goal.best >= goal.target then return "done" end
    end,
}
