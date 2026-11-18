-- Count the spots for luck.
return {
    name = "Ladybug Shell",
    description = "+10 Luck. Item choice cards roll one rarity higher 10% of the time (+10% per stack).",
    effect = "Item choice cards roll one rarity higher 10% of the time (+10% per stack).",
    rarity = "rare",
    category = "fortune",
    size = { 1, 1 },
    stats = { luck = 10 },
    rarityBump = 0.1,    -- src/game/choices.lua Choices.roll
    tags = { "utility", "bug" },
}
