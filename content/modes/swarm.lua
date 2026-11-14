-- Hard mode: more and tougher columns, shorter breaks, twice the elites.
return {
    name = "Swarm",
    tagline = "For veterans. Bigger waves, less rest.",
    description = "More columns from more sides, tougher ants that hit harder, short breathers and elites twice as often.",
    order = 3,
    finalWave = 15,
    spawn = { groups = 4, groupsPerWave = 1.4, growth = 0.2, breakTime = 3, firstBreak = 2, entries = { 3, 8 }, trickle = 4 },
    enemyHp = 1.2,
    enemyDamage = 1.2,
    hpPerWave = 0.14,
    elites = { mul = 2 },
}
