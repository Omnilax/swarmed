-- Parasites (src/game/parasites.lua): the numbers. A parasite is an item that lives IN your bug,
-- not in the bag: a big change to how you play with a real cost, and it can't be eaten,
-- scrapped, sold or cloned. Only a Green Mushroom (content/props/green_mushroom.lua) gets rid of
-- them, and it takes every parasite at once. A game mode can override any of these with
-- `parasites = { ... }`, or turn parasites off with `parasites = false` (there's no global
-- setting: game-changing options belong to modes like Custom Waves, not Settings).
return {
    max = 3,                    -- you carry at most this many different parasites (no copies)
    weightMul = 1,              -- item choice weight multiplier (a mode can raise or lower it)

    -- the Green Mushroom: a rare sprout that purges every parasite when you walk into it
    mushroom = {
        chance = 0.10,          -- chance a wave start sprouts one while you carry a parasite...
        pity = 0.05,            -- ...plus this for every wave you've carried them without one
        maxChance = 0.45,
        graceWaves = 1,         -- never in the first wave(s) after you pick up your first parasite
        away = 140,             -- sprouts at least this far from you
        arriveAt = { 3, 9 },    -- seconds into the wave
        heal = 0.25,            -- share of Max HP it heals when it purges
    },
}
