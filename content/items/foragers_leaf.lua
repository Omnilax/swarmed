return {
    name = "Forager's Leaf",
    description = "+4 Move Speed. The shop restocks 25% faster (stacks).",
    effect = "The shop restocks 25% faster (stacks).",
    rarity = "common",
    category = "fortune",
    size = { 2, 1 },
    stats = { moveSpeed = 4 },
    shopSpeed = 0.25,       -- src/game/economy.lua: restock every 60 / (1 + total) seconds
    tags = { "utility", "plant" },
}
