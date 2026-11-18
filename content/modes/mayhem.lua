-- Everything at once: every wave has modifiers, events never stop.
return {
    icon = "exploding_ant",          -- the enemy sprite shown for the mode in mode select
    name = "Mayhem",
    tagline = "Every wave twisted. Events never stop.",
    description = "Every wave rolls one or two wave modifiers from the very first (ambushes, shield walls, armoured swarms), mid-wave events land three or four at a time, and a boss encounter or stage hazard can show up every third wave.",
    order = 12,
    finalWave = 15,
    spawn = { modifiers = { from = 1, chance = 1, doubleFrom = 2, double = 0.6, anyWave = true } },
    director = { eventsFrom = 1, eventBonus = 2, encounterEvery = 3 },
    elites = { mul = 1.5 },
}
