return {
    name = "Mixed Colony", order = 7, cost = 60, color = "#9fd06f",
    description = "Species arrive in any order: a bullet ant on wave 2 is fair game.",
    apply = function(world)
        local sp = world.spawner
        local order = sp and sp.introOrder
        if not order then return end
        local rng = sp.rng or love.math
        for i = #order, 2, -1 do
            local j = rng:random(i)
            order[i], order[j] = order[j], order[i]
        end
    end,
}
