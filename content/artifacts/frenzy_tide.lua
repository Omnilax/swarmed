return {
    name = "Frenzy Tide", order = 8, cost = 40, color = "#ff7a5c",
    description = "The frenzy meter fills twice as fast, but ants bite 25% harder.",
    apply = function(world)
        local f = world.rewards and world.rewards.frenzy
        if f then f.max = f.max * 0.5 end
        world.danger.damageMul = world.danger.damageMul * 1.25
    end,
}
