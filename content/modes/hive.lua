-- Bees, wasps and hornets only. They have no queens yet, so boss waves bring the biggest hunters.
return {
    name = "Hive",
    tagline = "Bees, wasps and hornets. Watch the sky.",
    description = "Only stinging flyers: swarming bees, hunting wasps and armoured hornets. Boss waves bring the giant hornets and tarantula hawks.",
    order = 5,
    group = "classic",
    finalWave = 15,
    families = { "bee", "wasp", "hornet" },
    queensAnyWave = true,
    bossPool = { "giant_hornet", "tarantula_hawk", "european_hornet" },
    spawn = { introEvery = 1 },
}
