local ItemFx = require("src.game.itemfx")

return {
    name = "Gut Flora",
    description = "+5 Max HP. Eating an item heals 50% more (+50% per stack) and gives +15% Damage for 15 seconds.",
    effect = "Eating an item heals 50% more (+50% per stack) and gives +15% Damage for 15 seconds.",
    rarity = "uncommon",
    size = { 2, 1 },
    stats = { maxHp = 5 },
    procs = {
        {
            trigger = "onEat",
            effect = function(ctx, stacks)
                ctx.hp = ctx.hp * (1 + 0.5 * stacks)
                ItemFx.buff(ctx.player, "gut_flora", "damage", 15, 0, 15)
            end,
        },
    },
    tags = { "healing", "microbe" },
}
