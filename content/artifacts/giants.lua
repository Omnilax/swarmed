return {
    name = "Giants", order = 3, cost = 50, color = "#b08060",
    description = "Half as many ants, each more than twice as tough.",
    apply = function(world) local d = world.danger d.groupMul, d.hpMul = d.groupMul * 0.5, d.hpMul * 2.2 end,
}
