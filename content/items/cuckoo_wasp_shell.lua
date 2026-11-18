-- A cuckoo wasp's jewel-bright shell: it sneaks into other nests and takes what it likes.
return {
    name = "Cuckoo Wasp Shell",
    description = "The first shop reroll after every restock is free (+1 per stack).",
    rarity = "rare",
    category = "fortune",
    size = { 1, 1 },
    freeShopRerolls = 1, -- src/game/economy.lua Economy.rerollPrice
    tags = { "utility", "bug" },
}
