return {
    name = "Twin Queens", order = 5, cost = 70, color = "#d070ff",
    description = "Every queen wave brings a second queen, and the final wave one more crowned queen.",
    apply = function(world)
        world.danger.extraQueens = world.danger.extraQueens + 1
        world.danger.twinQueens = (world.danger.twinQueens or 0) + 1
    end,
}
