-- Keepsakes (src/game/keepsakes.lua): one small thing your bug carries into a run, picked in mode
-- select. Each is a trade, never a straight gain: it changes how a run feels, not how strong you
-- are. Bought once with amber in the Burrow.
--   mods: { stat, add, mult } (mult is additive: -0.1 = 10% less), nectar: start with this much,
--   nectarMul / xpMul: what you earn of each.
return {
    { id = "snail_shell", name = "Snail Shell", cost = 30, color = "#d8b07a",
        description = "A tough little shell to hide in: 25% more health, 10% slower.",
        mods = { { "maxHp", 0, 0.25 }, { "moveSpeed", 0, -0.10 } } },
    { id = "wasp_sting", name = "Wasp Sting", cost = 30, color = "#ffd24a",
        description = "A borrowed sting: 20% more damage, 20% less health.",
        mods = { { "damage", 20, 0 }, { "maxHp", 0, -0.20 } } },
    { id = "dragonfly_wing", name = "Dragonfly Wing", cost = 35, color = "#9fe0ff",
        description = "Light and quick: 15% faster, 10% less damage.",
        mods = { { "moveSpeed", 0, 0.15 }, { "damage", -10, 0 } } },
    { id = "honey_jar", name = "Honey Jar", cost = 35, color = "#ffb347",
        description = "Start with 30 nectar for an early shop, but earn 15% less nectar all run.",
        nectar = 30, nectarMul = 0.85 },
    { id = "old_map", name = "Old Map", cost = 40, color = "#c9a26b",
        description = "You know the way: 20% more XP, 20% less nectar.",
        xpMul = 1.2, nectarMul = 0.8 },
    { id = "pill_bug_plate", name = "Pill Bug Plate", cost = 45, color = "#8fa0b0",
        description = "Curl up and take it: bites do a fifth less damage, but you attack 15% slower.",
        mods = { { "armor", 4, 0 }, { "attackSpeed", -15, 0 } } },
}
