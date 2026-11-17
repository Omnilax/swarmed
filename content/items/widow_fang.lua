-- Molted from Spider Fang + Hornet Stinger (content/molts/widow_fang.lua).
return {
    name = "Widow's Fang",
    description = "+15% Damage, +10% Crit Chance. Every hit poisons the ant for 6 damage a second (+6 per stack) for 3 seconds; critical hits for twice that.",
    effect = "Every hit poisons the ant for 6 damage a second (+6 per stack) for 3 seconds; critical hits for twice that.",
    rarity = "molted",
    category = "elemental",
    shape = { "X.", "XX" },
    stats = { damage = 15, critChance = 10 },
    procs = {
        {
            trigger = "onHit",
            effect = function(ctx, stacks)
                local e = ctx.target
                if not e or e.dead then return end
                local dps = 6 * stacks * (ctx.crit and 2 or 1)
                e.poisonT, e.poisonDps = math.max(e.poisonT, 3), math.max(e.poisonDps, dps)
            end,
        },
    },
    tags = { "offense", "poison", "bug" },
}
