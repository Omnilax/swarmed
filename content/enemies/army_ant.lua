-- Army ant: big, relentless, marches straight at the player and bites hard.
return {
    name = "Army Ant",
    description = "Big and relentless. Marches straight at you and bites hard.",
    lore = "Army ants never build nests. The whole colony is always on the move, eating everything in its path.",
    tip = "They turn slowly: step aside and let the column march past. Its bites crack your armor.",
    sprite = "army_ant",
    hp = 14,
    speed = 36,
    damage = 6,
    shred = { armor = 2, time = 4, max = 10 },   -- bites crack your armor (src/config/defense.lua)
    radius = 5,
    mass = 2.5,
    behavior = "march",
    behaviorParams = { turn = 0.8 },
    personalSpace = 0.85,
    swarmShade = 0.22,
    spawn = { weight = 20, minWave = 5, groupSize = 0.8 },
    gibs = { "#24100a", "#702c16", "#e0c098" },
    splat = "#7c6a32",
    tags = { "ant", "heavy" },
}
