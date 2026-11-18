return {
    name = "Honeypot Ant",
    description = "+10 Pickup Range. The shop restocks 40% faster (stacks).",
    effect = "The shop restocks 40% faster (stacks).",
    rarity = "uncommon",
    category = "fortune",
    size = { 1, 1 },
    stats = { pickupRange = 10 },
    shopSpeed = 0.4,        -- src/game/economy.lua: restock every 60 / (1 + total) seconds
    tags = { "utility", "bug" },
}
