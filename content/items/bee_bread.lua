-- Bee bread: pollen packed with honey and left to ferment. Proper food.
return {
    name = "Bee Bread",
    description = "+5 Max HP. Items you eat heal 30% more (+30% per stack).",
    effect = "Items you eat heal 30% more (+30% per stack).",
    rarity = "common",
    category = "mend",
    size = { 1, 1 },
    stats = { maxHp = 5 },
    procs = {
        {
            trigger = "onEat",
            effect = function(ctx, stacks)
                ctx.hp = (ctx.hp or 0) * (1 + 0.3 * stacks)
            end,
        },
    },
    tags = { "healing", "bug" },
}
