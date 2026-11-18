-- Cursed: a gilded scarab that brings luck and takes choice. Each copy is one card fewer
-- in every free item pick (2 at least).
return {
    name = "Fool's Gold Scarab",
    description = "+60% Luck, +10% Crit Chance. Cursed: one card fewer in every free item pick.",
    curse = "One card fewer in every free item pick (2 at least).",
    rarity = "cursed",
    category = "cursed",
    size = { 1, 1 },
    stats = { luck = 60, critChance = 10 },
    cardsDelta = -1,
    tags = { "cursed", "proc", "bug" },
}
