return {
    name = "Glass Carapace", order = 1, cost = 60, color = "#9fe0ff",
    description = "You hit twice as hard, but your shell is paper thin: 40% of your usual health.",
    apply = function(world)
        local s = world.player.stats
        s:addModifier("artifact:glass", "damage", 100)
        s:addModifier("artifact:glass", "maxHp", 0, -0.6)
        world.player.hp = s:get("maxHp")
    end,
}
