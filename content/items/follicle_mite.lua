-- Parasite (src/game/parasites.lua). Microscopic mites living in your bristles: you move and
-- strike like something tiny, and you have the health of something tiny too.
return {
    name = "Follicle Mite",
    description = "Tiny and quick: +55 Speed, +20 Dodge, +25% Attack Speed.",
    curse = "-55% Max HP.",
    rarity = "parasite", category = "cursed", parasite = true,
    size = { 1, 1 },
    stats = { moveSpeed = 55, dodge = 20, attackSpeed = 25 },
    statsMult = { maxHp = -0.55 },
    tags = { "mobility" },
}
