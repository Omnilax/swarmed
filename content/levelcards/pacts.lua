-- Pact cards: a big boost with a cost. `stats` / `statsMult` grow with the rarity roll like any
-- stat card; the `cost` stays the same whatever the roll, so a rare pact is a better deal.
return {
    { id = "glass_carapace", name = "Glass Carapace", family = "pact", weight = 4, minLevel = 3,
        stats = { damage = 18, critChance = 4 }, cost = { statsMult = { maxHp = -0.12 } } },
    { id = "berserker_gut", name = "Berserker Gut", family = "pact", weight = 4, minLevel = 3,
        stats = { attackSpeed = 18, lifesteal = 2 }, cost = { stats = { armor = -2 } } },
    { id = "heavy_plating", name = "Heavy Plating", family = "pact", weight = 4, minLevel = 3,
        stats = { armor = 3 }, statsMult = { maxHp = 0.12 }, cost = { statsMult = { moveSpeed = -0.08 } } },
    { id = "featherweight", name = "Featherweight", family = "pact", weight = 4, minLevel = 3,
        statsMult = { moveSpeed = 0.14 }, stats = { dodge = 5 }, cost = { statsMult = { maxHp = -0.1 } } },
    { id = "reckless_rush", name = "Reckless Rush", family = "pact", weight = 3, minLevel = 5,
        statsMult = { dashCooldown = -0.15 }, stats = { knockback = 20 }, cost = { stats = { dodge = -3, armor = -1 } } },
    { id = "gamblers_spots", name = "Gambler's Spots", family = "pact", weight = 3, minLevel = 5,
        stats = { luck = 25, critDamage = 15 }, cost = { stats = { damage = -8 } } },
}
