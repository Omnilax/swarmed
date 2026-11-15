-- The nectar economy (src/game/economy.lua): the shop beside the free item pick, savings
-- interest, the scrapper in the bag. A game mode can change any of these with
-- `shop = { offers = 4, ... }` in its file under content/modes (`shop = false` turns the shop,
-- interest and scrap pay off; the scrap bin still throws items away for nothing).
-- Nectar comes from beads (about 1 per kill, more for big ants and gilded elites).
return {
    enabled = true,
    items = 2,             -- item offers in each shop
    boosts = 1,            -- stat boost offers in each shop
    -- Item prices by rarity, before the wave scaling. Bigger items cost a bit more per extra cell.
    price = { common = 14, uncommon = 24, rare = 42, legendary = 75, cursed = 20 },
    perCell = 0.12,        -- +12% per cell past the first
    perWave = 0.10,        -- every price is x(1 + perWave * (wave - 1))
    sale = 0.25,           -- chance one item offer is on sale
    saleOff = 0.4,         -- ...for 40% off
    boostPrice = 10,       -- a stat boost, before the wave scaling
    -- Shop reroll: base + step for every reroll already bought in this shop (+ waveStep per wave).
    reroll = { base = 3, step = 3, waveStep = 0.5 },
    -- Savings interest, paid when the wave-clear screen opens: rate of the banked nectar,
    -- at most cap (+ capPerWave per wave), rounded down.
    interest = { rate = 0.10, cap = 6, capPerWave = 1.5 },
    -- Scrapper: an item scraps for this share of its shop price. Cursed items scrap for nothing.
    -- Rare or better items also give back a free-pick reroll.
    scrap = { share = 0.4, rerollFrom = "rare" },
    -- Stat boosts the shop can offer. add / mult like an item's stats / statsMult.
    boostList = {
        { stat = "maxHp", add = 8, name = "Thick Hemolymph" },
        { stat = "damage", add = 6, name = "Sharpened Jaws" },
        { stat = "attackSpeed", add = 6, name = "Twitch Muscle" },
        { stat = "moveSpeed", add = 6, name = "Spring Legs" },
        { stat = "armor", add = 2, name = "Extra Wax" },
        { stat = "critChance", add = 3, name = "Keen Eyes" },
        { stat = "critDamage", add = 12, name = "Barbed Tips" },
        { stat = "luck", add = 10, name = "Lucky Spot" },
        { stat = "hpRegen", add = 0.3, name = "Royal Nectar" },
        { stat = "area", add = 6, name = "Long Reach" },
        { stat = "lifesteal", add = 2, name = "Blood Meal" },
        { stat = "pickupRange", add = 15, name = "Sweet Tooth" },
    },
}
