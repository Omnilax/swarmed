return {
    name = "Nettle Leaf",
    description = "+5% Crit Chance. Hits have a 20% chance to sting the ant for 4 damage a second (+4 per stack) for 2 seconds.",
    effect = "Hits have a 20% chance to sting the ant for 4 damage a second (+4 per stack) for 2 seconds.",
    rarity = "uncommon",
    size = { 2, 1 },
    stats = { critChance = 5 },
    procs = {
        {
            trigger = "onHit",
            chance = 0.2,
            effect = function(ctx, stacks)
                local e = ctx.target
                if e.dead then return end
                e.poisonT, e.poisonDps = math.max(e.poisonT, 2), math.max(e.poisonDps, 4 * stacks)
            end,
        },
    },
    tags = { "offense", "poison", "plant" },
}
