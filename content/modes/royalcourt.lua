-- Boss rush: a queen every wave, from the first.
return {
    icon = "queen_fire",          -- the enemy sprite shown for the mode in mode select
    name = "Royal Court",
    tagline = "A queen every wave. Ten of them.",
    description = "Every wave is a boss wave: a different queen (or a giant hornet) arrives each time with a small escort and her royal guard. A new species still joins every wave. Ten waves to win, and a full heal after each one.",
    order = 10,
    finalWave = 10,
    queensAnyWave = true,
    queensAnyBrood = true,      -- queens come whether or not her brood species has been met
    introOnBoss = true,         -- boss waves still bring a new species
    bossPool = { "giant_hornet", "tarantula_hawk" },
    spawn = { bossEvery = 1, groups = 3, groupsPerWave = 0.5, group = { 8, 14 }, breakTime = 5, firstBreak = 3 },
    enemyHp = 0.85,
    hpPerWave = 0.1,
}
