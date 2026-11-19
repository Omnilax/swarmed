-- Risk of Rain style proc: chance on hit to chain lightning. More stacks = more jumps and damage.
local Combat = require("src.game.combat")

return {
    name = "Static Antenna",
    description = "10% chance on hit to zap 3 (+1 per stack) nearby enemies.",
    rarity = "uncommon",
    category = "elemental",
    size = { 1, 2 },
    procs = {
        {
            trigger = "onHit",
            chance = 0.10,
            effect = function(ctx, stacks)
                Combat.chain(ctx.world, ctx.target, 2 + stacks, 80, 5 * stacks, { procDepth = ctx.procDepth + 1, noCrit = true })
            end,
        },
    },
    tags = { "proc", "lightning" },
}
