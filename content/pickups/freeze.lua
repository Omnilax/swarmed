-- Elite drop: the whole swarm freezes stiff for a moment. Kept rare: it is a big swing, so it
-- only drops from wave 4, is the least likely elite pickup, and never drops again for
-- COOLDOWN seconds of game time after a freeze (or while one is already lying around).
local COOLDOWN = 60      -- seconds of game time after a freeze before Frost Dew can drop again

return {
    name = "Frost Dew",
    description = "A rare elite drop. Every enemy in the arena freezes solid for 2 seconds: no moving, no biting. Free hits!",
    color = "#8fdcff",
    icon = "freeze",
    source = "elite",
    weight = 3, minWave = 4,
    time = 2,
    allowed = function(world)
        if world.frostAt and world.time - world.frostAt < COOLDOWN then return false end
        for _, pk in ipairs(world.beads and world.beads.pickups or {}) do
            if pk.def and pk.def.icon == "freeze" then return false end
        end
        return true
    end,
    collect = function(world, player, pickup)
        world:freezeEnemies(pickup.def.time)
        world:floatText(player.x, player.y - 12, "FROZEN!", { 0.6, 0.9, 1 }, true)
    end,
}
