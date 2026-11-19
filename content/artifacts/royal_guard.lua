return {
    name = "Royal Guard", order = 4, cost = 70, color = "#ffd23a",
    description = "Elite ants turn up four times as often.",
    apply = function(world) world.danger.eliteMul = world.danger.eliteMul * 4 end,
}
