return {
    name = "Mosquito Proboscis",
    description = "+3% Life Steal. Critical hits drink 1 HP (+1 per stack).",
    effect = "Critical hits drink 1 HP (+1 per stack).",
    rarity = "uncommon",
    size = { 1, 2 },
    stats = { lifesteal = 3 },
    procs = {
        { trigger = "onHit", effect = function(ctx, stacks) if ctx.crit then ctx.player:heal(stacks) end end },
    },
    tags = { "healing", "bug" },
}
