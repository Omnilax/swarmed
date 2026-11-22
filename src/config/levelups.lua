-- Level-up cards (src/game/levelups.lua). A game mode can change any of these with
-- `levelUps = { cards = 4, ... }` in its file under content/modes.
return {
    -- XP to go from level L-1 to L: floor(base + scale * (L - 1) ^ pow). Quick to slow, but calm
    -- at the start: the first level takes ~45 kills, wave 1 gives ~2 levels, waves 1-3 ~7, then
    -- about 2 a wave; a 15-wave run reaches roughly level 25-30. (Was base 10, scale 5, pow 1.5:
    -- 4-5 levels in wave 1, 12 by wave 3, ~35 a run, which kept interrupting the opening waves.)
    xp = { base = 45, scale = 20, pow = 1.25 },
    cards = 3,              -- cards per level-up
    armTime = 0.5,          -- seconds before the cards accept input (anti-misclick, like items)
    -- cards are stat boosts only; skipping a pick banks 1 skill point for the SKILLS tab (a whole
    -- tree costs ~45 points, a run levels ~27 times, so no run gets everything)
    botSkip = 0.4,          -- how often the balance bot / autoPickAll skips for a point
    -- rarity rolls for stat cards: weight, and how much the card's numbers are multiplied by.
    -- Luck tilts the odds: tier k (0 = common) has its weight times (1 + luck / 100) ^ k.
    rarities = {
        { id = "common", weight = 100, mult = 1 },
        { id = "uncommon", weight = 40, mult = 1.33 },
        { id = "rare", weight = 14, mult = 1.66 },
        { id = "legendary", weight = 4, mult = 2 },
    },
    -- the moment you level up: a chime, half a second of slow motion and a ring of light
    fanfare = { slow = 0.6, slowTime = 0.25, ring = 70, color = { 1, 0.9, 0.45 } },
    instantDelay = 0.45,    -- "Right Away" timing: the cards open this long after the level
}
