return {
    name = "Teeming", order = 2, cost = 50, color = "#e07040",
    description = "Almost twice as many ants come, each a little weaker.",
    apply = function(world) local d = world.danger d.groupMul, d.hpMul = d.groupMul * 1.8, d.hpMul * 0.6 end,
}
