return {
    name = "Heatwave", order = 6, cost = 50, color = "#ff9a3a",
    description = "Everything moves faster in the heat: ants by 30%, you by 25%, and you attack 20% faster.",
    apply = function(world)
        world.danger.speedMul = world.danger.speedMul * 1.3
        local s = world.player.stats
        s:addModifier("artifact:heatwave", "moveSpeed", 0, 0.25)
        s:addModifier("artifact:heatwave", "attackSpeed", 20)
    end,
}
