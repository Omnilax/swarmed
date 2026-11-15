-- Item rarity tiers: colour for UI, base weight in item choices, the wave they start appearing,
-- and eat (HP healed by eating one from the bag; bigger items heal more, see Inventory.eatValue).
return {
    common = { label = "Common", color = "#d8d2c4", weight = 100, minWave = 1, order = 1, eat = 8 },
    uncommon = { label = "Uncommon", color = "#6fd36a", weight = 45, minWave = 1, order = 2, eat = 14 },
    rare = { label = "Rare", color = "#4fa8ff", weight = 15, minWave = 3, order = 3, eat = 22 },
    legendary = { label = "Legendary", color = "#ff9f3a", weight = 4, minWave = 6, order = 4, eat = 35 },
    -- Cursed: a big upside with a real cost (the item's `curse` says what). Order 0, so it never
    -- counts as "rare or better". Cursed items can't be eaten: only the scrapper takes them.
    cursed = { label = "Cursed", color = "#c071ff", weight = 9, minWave = 3, order = 0, eat = 0, cursed = true },
}
