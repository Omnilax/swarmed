-- On-kill explosion. Explosion kills can trigger more explosions (up to the proc depth limit).
local Combat = require("src.game.combat")

return {
    name = "Ember Gland",
    description = "15% chance for killed enemies to explode for 12 damage (+12 per stack).",
    rarity = "rare",
    size = { 1, 1 },
    procs = {
        {
            trigger = "onKill",
            chance = 0.15,
            effect = function(ctx, stacks)
                Combat.explode(ctx.world, ctx.x, ctx.y, 30 + 6 * stacks, 12 * stacks, { procDepth = ctx.procDepth + 1 })
            end,
        },
    },
    tags = { "proc", "fire", "explosive" },
}
