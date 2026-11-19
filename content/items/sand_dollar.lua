-- A sea urchin's flat cousin, bleached white. Shore item (src/game/shore.lua).
return {
    name = "Sand Dollar",
    description = "+5 Luck. Kills drop 10% more nectar (+10% per stack) and each wave clear pays 2 nectar. Crustaceans: +5 Luck more.",
    effect = "Kills drop 10% more nectar (+10% per stack) and each wave clear pays 2 nectar.",
    rarity = "common",
    category = "fortune",
    size = { 1, 1 },
    stats = { luck = 5 },
    beadValue = 0.1,
    waveNectar = 2,
    kin = { tags = { "crustacean" }, stats = { luck = 5 } },
    tags = { "utility", "shore" },
}
