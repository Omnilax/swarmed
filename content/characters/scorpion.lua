return {
    name = "Scorpion",
    description = "Venomous. Two quick pincer snaps, then a long poisoned tail sting that skewers a whole line of ants for heavy damage. Shift springs backwards, lashing the tail through the spot you left.",
    lore = "Scorpions glow blue-green under ultraviolet light. Nobody is quite sure why.",
    sprite = "scorpion",
    model = { legs = "scorpion_legs", body = "scorpion_body", height = 3, lift = 2, kneeUp = 1 },
    order = 6,
    playstyle = "brawler",          -- src/config/playstyles.lua
    tip = "After two pincer snaps comes a long tail sting that skewers a whole line. {dash} springs you backwards, stinging the spot you left.",
    radius = 8,
    scale = 1.05,
    stats = { maxHp = 62, armor = 4, moveSpeed = 100, critDamage = 180 },
    attack = { type = "pinchsting", damage = 8, cooldown = 0.4, radius = 34, stingRange = 85, stingMult = 2.5, knockback = 60, poison = { 3, 3 }, stingPoison = { 8, 4 }, color = { 1, 0.85, 0.5 } },
    secondary = { type = "venomsting", damage = 14, cooldown = 2, range = 75, width = 6, poison = { 10, 4 }, color = { 0.8, 1, 0.4 } },
    dash = { type = "tailflick", distance = 70, hop = 6, sting = 14, reach = 70, poison = { 6, 3 } },
    startingItems = {},
    tags = { "arachnid" },
}
