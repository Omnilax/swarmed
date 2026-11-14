return {
    name = "Aloe Leaf",
    description = "+0.3 HP Regen. Each wave starts by healing 15% of your Max HP (+15% per stack).",
    effect = "Each wave starts by healing 15% of your Max HP (+15% per stack).",
    rarity = "uncommon",
    size = { 1, 3 },
    stats = { hpRegen = 0.3 },
    procs = {
        { trigger = "onWaveStart", effect = function(ctx, stacks) ctx.player:heal(ctx.player.stats:get("maxHp") * 0.15 * stacks) end },
    },
    tags = { "healing", "plant" },
}
