local Combat = require("src.game.combat")

return {
    name = "Bombardier Gland",
    description = "Dashing leaves a boiling blast behind you: 14 damage (+14 per stack).",
    rarity = "rare",
    size = { 2, 1 },
    procs = {
        {
            trigger = "onDash",
            effect = function(ctx, stacks)
                local p = ctx.player
                Combat.explode(ctx.world, p.x, p.y, 34, 14 * stacks, { procDepth = ctx.procDepth + 1, color = { 1, 0.9, 0.6 } })
            end,
        },
    },
    tags = { "proc", "fire", "explosive" },
}
