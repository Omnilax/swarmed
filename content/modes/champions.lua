-- Elites only: small groups, but every single enemy carries an elite affix.
return {
    name = "Champions",
    tagline = "Every enemy is an elite.",
    description = "Fewer enemies, but every one of them is an elite: armoured, venomous, volatile, aggressive or gilded. Gilded ones give bonus XP.",
    order = 7,
    group = "challenge",
    finalWave = 15,
    spawn = { groups = 3, groupsPerWave = 0.7, group = { 4, 7 }, growth = 0.1, trickle = 9 },
    enemyHp = 0.7,
    elites = { chance = 1, anyWave = true },
}
