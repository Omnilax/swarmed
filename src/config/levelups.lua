-- Level-up cards (src/game/levelups.lua). A game mode can change any of these with
-- `levelUps = { cards = 4, ... }` in its file under content/modes.
return {
    -- XP to go from level L-1 to L: floor(base + scale * (L - 1) ^ pow). The first level takes
    -- ~10 kills; a 15-wave run reaches roughly level 30-40 (about 5 levels in wave 1).
    xp = { base = 10, scale = 5, pow = 1.5 },
    cards = 3,              -- cards per level-up
    armTime = 0.5,          -- seconds before the cards accept input (anti-misclick, like items)
    skillShare = 0.5,       -- chance each card is a skill-tree node (when the tree has one to offer)
    -- rarity rolls for stat cards: weight, and how much the card's numbers are multiplied by.
    -- Luck tilts the odds: tier k (0 = common) has its weight times (1 + luck / 100) ^ k.
    rarities = {
        { id = "common", weight = 100, mult = 1 },
        { id = "uncommon", weight = 40, mult = 1.33 },
        { id = "rare", weight = 14, mult = 1.66 },
        { id = "legendary", weight = 4, mult = 2 },
    },
    -- the moment you level up: a chime, half a second of slow motion and a ring of light
    fanfare = { slow = 0.35, slowTime = 0.5, ring = 70, color = { 1, 0.9, 0.45 } },
    instantDelay = 0.45,    -- "Right Away" timing: the cards open this long after the level
}
