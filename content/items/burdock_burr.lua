return {
    name = "Burdock Burr",
    description = "Every hit sticks a burr on the ant, slowing it by 30% for 1 second (+0.5 per stack).",
    rarity = "uncommon",
    size = { 1, 1 },
    procs = {
        {
            trigger = "onHit",
            effect = function(ctx, stacks)
                local e = ctx.target
                if e.dead then return end
                e.slowT, e.slowMul = math.max(e.slowT, 0.5 + 0.5 * stacks), math.min(e.slowT > 0 and e.slowMul or 1, 0.7)
            end,
        },
    },
    tags = { "utility", "plant" },
}
