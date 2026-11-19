-- Zombified: never rolls on its own (minWave 999). A jewel wasp's sting turns an ant into one
-- (content/behaviors/wasp_zombify.lua): a hulking, slow, mindless brute.
return {
    name = "Zombified",
    description = "Stung in the brain by a jewel wasp. Much tougher, bigger and slower, and it doesn't care about anything any more.",
    color = "#7dff6a",
    safeColor = "#009e73",
    hp = 2.5, damage = 1.3, speed = 0.8, mass = 2.5, scale = 1.25,
    armor = 0.15,
    weight = 0, minWave = 999,
    glow = 0.25,
}
