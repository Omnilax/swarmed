-- The nectar economy (src/game/economy.lua): the shop (the SHOP tab of the inventory), savings
-- interest, the scrapper in the bag. A game mode can change any of these with
-- `shop = { offers = 4, ... }` in its file under content/modes (`shop = false` turns the shop,
-- interest and scrap pay off; the scrap bin still throws items away for nothing).
-- Nectar comes from beads (about 1 per kill, more for big ants and gilded elites). The balance
-- bot earns roughly 135 in wave 1, 530 in wave 5, 770 in wave 10 and 1650 in wave 15, so a
-- shop buys about 1 thing early and 2 to 4 later.
return {
    enabled = true,
    items = 3,             -- item offers in each stock
    boosts = 1,            -- stat boost offers in each stock
    restock = 60,          -- seconds of play between restocks (items with shopSpeed make it faster)
    restockMin = 15,       -- ...never faster than this
    -- Item prices by rarity, before the wave scaling. Bigger items cost a bit more per extra cell.
    price = { common = 60, uncommon = 100, rare = 170, legendary = 300, cursed = 90, molted = 400 },
    perCell = 0.12,        -- +12% per cell past the first
    perWave = 0.25,        -- every price is x(1 + perWave * (wave - 1)): x2 at wave 5, x4.5 at wave 15
    sale = 0.25,           -- chance one item offer is on sale
    saleOff = 0.4,         -- ...for 40% off
    boostPrice = 45,       -- a stat boost, before the wave scaling
    -- Shop reroll: base + step for every reroll already bought in this shop (+ waveStep per wave).
    reroll = { base = 15, step = 15, waveStep = 5 },
    -- Savings interest, paid the moment a wave is cleared: rate of the banked nectar,
    -- at most cap (+ capPerWave per wave), rounded down.
    interest = { rate = 0.10, cap = 20, capPerWave = 15 },
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
