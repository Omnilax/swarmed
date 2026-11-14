return {
    name = "Spider Fang",
    description = "+8% Damage. Every hit poisons the ant for 2 damage a second (+2 per stack) for 2 seconds.",
    effect = "Every hit poisons the ant for 2 damage a second (+2 per stack) for 2 seconds.",
    rarity = "uncommon",
    size = { 1, 2 },
    stats = { damage = 8 },
    procs = {
        {
            trigger = "onHit",
            effect = function(ctx, stacks)
                local e = ctx.target
                if e.dead then return end
                e.poisonT, e.poisonDps = math.max(e.poisonT, 2), math.max(e.poisonDps, 2 * stacks)
            end,
        },
    },
    tags = { "offense", "poison", "bug" },
}
