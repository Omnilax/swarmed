-- Elite drop: fills the frenzy meter to the top.
return {
    name = "Royal Jelly",
    description = "Dropped by elites. Fills your frenzy meter all the way, ready to unleash.",
    color = "#ffb040",
    icon = "frenzy",
    source = "elite",
    weight = 10, minWave = 1,
    -- no point dropping it when the meter is already full
    allowed = function(world)
        local f = world.rewards and world.rewards.frenzy
        return f ~= nil and f.charge < f.max
    end,
    collect = function(world, player, pickup)
        local f = world.rewards and world.rewards.frenzy
        if f then f:add(f.max, true) end
        world:floatText(player.x, player.y - 12, "FRENZY READY!", { 1, 0.75, 0.3 }, true)
    end,
}
