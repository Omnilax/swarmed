return {
    name = "Hornet Stinger",
    description = "+8% Crit Chance. Critical hits poison the ant for 5 damage a second (+5 per stack) for 3 seconds.",
    effect = "Critical hits poison the ant for 5 damage a second (+5 per stack) for 3 seconds.",
    rarity = "uncommon",
    category = "elemental",
    shape = { "X.", "XX" },
    stats = { critChance = 8 },
    procs = {
        {
            trigger = "onHit",
            effect = function(ctx, stacks)
                local e = ctx.target
                if ctx.crit and e and not e.dead then
                    e.poisonT = math.max(e.poisonT, 3)
                    e.poisonDps = math.max(e.poisonDps, 5 * stacks)
                end
            end,
        },
    },
    tags = { "offense", "poison", "proc" },
}
