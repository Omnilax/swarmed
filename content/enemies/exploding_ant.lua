-- Exploding ant (Colobopsis): rushes in and bursts. Killing it first only causes a small pop.
return {
    name = "Exploding Ant",
    description = "Runs up to you, swells, and bursts for massive damage. Hurts other ants too.",
    lore = "Malaysian exploding ants rupture their own bodies to spray toxic glue over intruders.",
    tip = "Kill it at range, or lure it into a crowd and dash away before it pops.",
    sprite = "exploding_ant",
    hp = 4,
    speed = 58,
    damage = 1,
    radius = 3.5,
    mass = 1,
    behavior = "kamikaze",
    behaviorParams = { trigger = 14, fuse = 0.7, radius = 46, blastDamage = 16, antDamage = 30 },
    swarmShade = 0.12,
    light = { radius = 6, color = "#ffd060", intensity = 0.2 },
    spawn = { weight = 14, minWave = 6, groupSize = 0.4 },
    gibs = { "#3a1a0e", "#d8ae3a", "#fff8c0" },
    splat = "#d8b040",
    tags = { "ant", "explosive" },
    -- Killed before it detonates: a small pop that only hurts nearby ants.
    onDeath = function(world, x, y, def, info)
        if info.selfDestruct then return end
        local Combat = require("src.game.combat")
        Combat.explode(world, x, y, 20, 8, { procDepth = Combat.MAX_PROC_DEPTH, noCrit = true, color = { 1, 0.85, 0.4 } })
    end,
}
