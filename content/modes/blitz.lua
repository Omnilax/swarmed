-- Short and fast: eight huge waves with no rest.
return {
    name = "Blitz",
    tagline = "Eight huge waves, no rest. A quick run.",
    description = "A short run for when you have ten minutes: eight waves, each far bigger than the last, coming in from every side with no breather between them. Two new species a wave, frail ants, and level-ups come fast.",
    order = 11,
    finalWave = 8,
    spawn = { groups = 4, groupsPerWave = 1.2, group = { 14, 22 }, growth = 0.25, breakTime = 0, firstBreak = 1,
        introEvery = 1, entries = { 4, 8 }, trickle = 3, bossEvery = 4 },
    queensAnyWave = true,       -- queen waves (4, 8) can bring any queen
    introCount = 2,             -- species introduced per wave
    enemyHp = 0.7,
    enemyDamage = 0.9,
    hpPerWave = 0.18,
    levelUps = { xp = { base = 7, scale = 3.5, pow = 1.5 } },   -- levels come faster
}
