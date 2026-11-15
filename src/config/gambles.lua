-- Map gambles (src/game/gambles.lua): the numbers for dewdrop shrines, challenge bells and
-- gamble flowers. A game mode can override any of these with `gambles = { ... }` (merged one
-- level deep), or turn them off with `gambles = false`.
return {
    from = 2,                   -- first wave that can have one
    chance = 0.5,               -- chance a wave gets one (Settings "Map Gambles": Normal)
    oftenChance = 0.85,         -- ... on "Often", which can also place a second one
    secondChance = 0.35,
    max = 2,                    -- at most this many on the map at once
    away = 150,                 -- placed at least this far from the player
    arriveAt = { 2, 7 },        -- seconds into the wave it pops up

    -- Dewdrop shrine: stand in the ring while the wave is on to gather the dew. It draws ants
    -- in while it fills; when full, three blessings float up and you walk into the one you want.
    shrine = {
        ring = 30,              -- radius of the ring you stand in
        fill = 6,               -- seconds of standing in it to fill
        drain = 0.08,           -- share lost per second while you are out of it
        callEvery = 1.4,        -- seconds between ant calls while filling
        callBase = 2, callPerWave = 0.34,   -- ants per call: base + wave * this
        callRadius = 120,
        offers = 3,
        grow = 0.05,            -- blessings are this much bigger per wave past the first
        -- the blessing pool: a permanent +add to one stat (weight = how often it is offered)
        pool = {
            { stat = "maxHp", add = 8, weight = 10 },
            { stat = "hpRegen", add = 0.35, weight = 6 },
            { stat = "armor", add = 2, weight = 8 },
            { stat = "dodge", add = 3, weight = 6 },
            { stat = "moveSpeed", add = 6, weight = 8 },
            { stat = "damage", add = 7, weight = 10 },
            { stat = "attackSpeed", add = 6, weight = 9 },
            { stat = "area", add = 7, weight = 7 },
            { stat = "knockback", add = 12, weight = 4 },
            { stat = "critChance", add = 4, weight = 8 },
            { stat = "critDamage", add = 15, weight = 5 },
            { stat = "luck", add = 8, weight = 6 },
            { stat = "lifesteal", add = 2, weight = 5 },
            { stat = "pickupRange", add = 15, weight = 3 },
        },
    },

    -- Challenge bell: hit it while the wave is on and a pack of tough ants answers. Kill every
    -- one of them in time for a prize: XP, frenzy and a rarer best card in the next item choice.
    bell = {
        pack = 8, packPerWave = 0.8,        -- ants in the pack
        elites = 2, elitesPerWave = 0.25,   -- how many of them are elite
        hpMul = 1.35,                       -- their health on top of the wave's
        radius = 125,                       -- they come in on a ring this far out
        time = 30, timePerAnt = 0.4,        -- seconds to finish them
        reward = { xp = 18, xpPerWave = 3, frenzy = 0.35, minRarity = "uncommon", rareFrom = 7, legendaryFrom = 13 },
    },

    -- Gamble flower: pay nectar to spin it. Each petal is an outcome; a few are bad.
    flower = {
        cost = 12, costPerWave = 2, costGrow = 0.5,     -- price, and +50% per spin already made
        spins = 3,                                      -- then it wilts
        outcomes = {
            { id = "item", weight = 18, color = "#ffd24a", label = "An item" },
            { id = "rare_item", weight = 6, color = "#4fa8ff", label = "A rare item" },
            { id = "blessing", weight = 16, color = "#9ff0ff", label = "A blessing" },
            { id = "jackpot", weight = 5, color = "#ff9f3a", label = "Nectar x3" },
            { id = "refund", weight = 14, color = "#e8d890", label = "Nectar back" },
            { id = "xp", weight = 14, color = "#8ce0ff", label = "XP" },
            { id = "heal", weight = 10, color = "#7ef08a", label = "Full heal" },
            { id = "wilt", weight = 10, color = "#8a7a6a", label = "Nothing" },
            { id = "swarm", weight = 9, color = "#ff6a4a", label = "Ants!" },
            { id = "curse", weight = 6, color = "#b06aff", label = "A curse" },
        },
        -- a curse: a permanent -add to one stat
        curses = {
            { stat = "moveSpeed", add = -5 },
            { stat = "damage", add = -5 },
            { stat = "armor", add = -2 },
            { stat = "attackSpeed", add = -5 },
            { stat = "maxHp", add = -6 },
        },
    },
}
