return {
    name = "Silk Bundle",
    description = "+15% Area, +5 Armor. Hits have a 12% chance to wrap the ant in silk, slowing it to a crawl for 2 seconds.",
    effect = "Hits have a 12% chance to wrap the ant in silk, slowing it to a crawl for 2 seconds.",
    rarity = "rare",
    shape = { ".X.", "XXX", ".X." },
    stats = { area = 15, armor = 5 },
    procs = {
        {
            trigger = "onHit",
            chance = 0.12,
            effect = function(ctx, stacks)
                local e = ctx.target
                if e and not e.dead then e.slowT, e.slowMul = math.max(e.slowT, 2 + stacks * 0.5), math.min(e.slowMul, 0.2) end
            end,
        },
    },
    tags = { "utility", "proc" },
}
