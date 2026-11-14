return {
    name = "Snail Shell",
    description = "+8 Armor, +10 Max HP, -10 Speed. When bitten, 15% chance to pull in: untouchable for 0.5 seconds.",
    effect = "When bitten, 15% chance to pull in: untouchable for 0.5 seconds.",
    rarity = "uncommon",
    size = { 2, 2 },
    stats = { armor = 8, maxHp = 10, moveSpeed = -10 },
    procs = {
        { trigger = "onHurt", chance = 0.15, effect = function(ctx) ctx.player.iframes = math.max(ctx.player.iframes, 0.5) end },
    },
    tags = { "defense" },
}
