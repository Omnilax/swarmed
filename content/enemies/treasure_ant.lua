-- Not part of the colony's waves: src/game/rewards.lua sends one in now and then (numbers in
-- src/config/rewards.lua treasure). Always gilded. Catch it for a pile of XP and frenzy.
return {
    name = "Treasure Ant",
    description = "A gilded worker stuffed with sugar. It runs from you and burrows away if you are too slow.",
    lore = "Repletes swollen with honeydew are the colony's living larder. This one took a wrong turn.",
    tip = "Cut it off against a wall, or dash through it.",
    sprite = "worker_ant",
    hp = 14, speed = 78, damage = 0, radius = 4, mass = 1.2, scale = 1.25,
    behavior = "treasure_flee",
    behaviorParams = { escape = 14, panic = 1.35, near = 90, jink = 0.6 },
    noElites = true,
    spawn = { weight = 0, minWave = 3 },
    gibs = { "#ffd23a", "#fff0a0", "#c89020" },
    splat = "#ffe070",
    tags = { "ant", "treasure" },
    onDeath = function(world, x, y)
        if world.rewards then world.rewards:treasureCaught(x, y) end
    end,
}
