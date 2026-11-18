-- Beginner mode: smaller, slower waves with long breathers and no elites.
return {
    icon = "ichneumon_larva",          -- the enemy sprite shown for the mode in mode select
    name = "Larvae",
    tagline = "Learn the ropes. Gentler waves, long breaks.",
    description = "Smaller columns, weaker ants and plenty of time between waves. New species arrive every other wave and elites never show up.",
    order = 1,
    group = "classic",
    finalWave = 15,
    spawn = { groups = 2, groupsPerWave = 0.6, group = { 10, 16 }, growth = 0.08, breakTime = 8, firstBreak = 4,
        introEvery = 2, entries = { 1, 4 }, trickle = 10 },
    enemyHp = 0.75,
    enemyDamage = 0.65,
    hpPerWave = 0.08,
    elites = { chance = 0 },
}
