-- Elite drop: the whole swarm freezes stiff for a few seconds.
return {
    name = "Frost Dew",
    description = "Dropped by elites. Every enemy in the arena freezes solid for 3 seconds: no moving, no biting. Free hits!",
    color = "#8fdcff",
    icon = "freeze",
    source = "elite",
    weight = 10, minWave = 1,
    time = 3,
    collect = function(world, player, pickup)
        world:freezeEnemies(pickup.def.time)
        world:floatText(player.x, player.y - 12, "FROZEN!", { 0.6, 0.9, 1 }, true)
    end,
}
