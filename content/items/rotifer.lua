return {
    name = "Rotifer",
    description = "+0.4 HP Regen. Standing still heals 1 more HP a second (+1 per stack).",
    effect = "Standing still heals 1 more HP a second (+1 per stack).",
    rarity = "common",
    category = "mend",
    size = { 1, 1 },
    stats = { hpRegen = 0.4 },
    procs = {
        { trigger = "onTick", effect = function(ctx, stacks) if not ctx.player.moving then ctx.player:heal(stacks * ctx.dt) end end },
    },
    tags = { "healing", "microbe" },
}
