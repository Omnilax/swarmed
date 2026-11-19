-- Everything at once: every wave has modifiers, events never stop.
return {
    icon = "exploding_ant",          -- the enemy sprite shown for the mode in mode select
    name = "Mayhem",
    tagline = "Every wave twisted. Events never stop.",
    description = "Every wave rolls one or two wave modifiers from the very first (ambushes, shield walls, armoured swarms), mid-wave events land three or four at a time, and stage hazards (antlion pit, sparrow, anteater) turn up far more often.",
    order = 12,
    group = "challenge",
    finalWave = 15,
    spawn = { modifiers = { from = 1, chance = 1, doubleFrom = 2, double = 0.6, anyWave = true } },
    director = { eventsFrom = 1, eventBonus = 2, hazardFrom = 3, hazardMul = 1.6, hazardGap = 1 },
    elites = { mul = 1.5 },
}
