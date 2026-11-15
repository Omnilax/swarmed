-- Numbers for molting, tag set bonuses, brood cell chests and the aphid matriarch (duplicator).
-- See src/game/molting.lua, content/molts, content/props/brood_cell.lua, src/states/broodcell.lua.
return {
    -- Tag sets: this many items sharing a tag, all touching (one connected group), give the tag's
    -- `set` bonus from src/config/tags.lua; `tier2` or more give it twice.
    set = { tier1 = 3, tier2 = 5 },

    -- Brood cell chests: dropped by a slain queen and a caught treasure ant. Opening one rolls
    -- how many level-up cards it holds. `odds` are weights for 1 / 3 / 5 cards; Luck moves
    -- weight from 1 toward 3 and 5 (luckShift per 100% Luck).
    chest = {
        queen = { odds = { 50, 38, 12 }, minRarity = "uncommon" },
        treasure = { odds = { 74, 22, 4 } },
        counts = { 1, 3, 5 },
        luckShift = 0.5,
        fallbackXP = 25,      -- XP per card when the level-up card system isn't there
        life = nil,           -- a chest never goes away; it opens by itself when the wave ends
    },

    -- The aphid matriarch (content/events/aphid_matriarch.lua): a rare map event. Feed her one
    -- item and she gives birth to a copy of another item of the same rarity.
    duplicator = { uses = 1 },
}
