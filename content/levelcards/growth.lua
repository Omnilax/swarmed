-- Growth cards: small now, big later. `growth` stats (times the rarity roll) are added again at
-- the start of every wave for the rest of the run, so they pay off best when taken early.
return {
    { id = "late_bloomer", name = "Late Bloomer", family = "growth", weight = 4, growth = { stats = { damage = 2.5 } } },
    { id = "thickening_shell", name = "Thickening Shell", family = "growth", weight = 4, growth = { stats = { armor = 0.4 } } },
    { id = "growing_appetite", name = "Growing Appetite", family = "growth", weight = 4, growth = { statsMult = { maxHp = 0.03 } } },
    { id = "four_leaf", name = "Four-Leaf Clover", family = "growth", weight = 3, growth = { stats = { luck = 4 } } },
    { id = "honed_instinct", name = "Honed Instinct", family = "growth", weight = 3, growth = { stats = { critChance = 1 } } },
}
