-- Molted from Ember Gland + Bombardier Gland (content/molts/magma_gland.lua).
local Combat = require("src.game.combat")

return {
    name = "Magma Gland",
    description = "Kills have a 30% chance to erupt for 30 damage (+30 per stack). Dashing leaves a 40 damage blast behind you (+40 per stack).",
    rarity = "molted",
    size = { 2, 1 },
    procs = {
        {
            trigger = "onKill",
            chance = 0.3,
            effect = function(ctx, stacks)
                Combat.explode(ctx.world, ctx.x, ctx.y, 40 + 6 * stacks, 30 * stacks, { procDepth = ctx.procDepth + 1, color = { 1, 0.55, 0.15 } })
            end,
        },
        {
            trigger = "onDash",
            effect = function(ctx, stacks)
                local p = ctx.player
                Combat.explode(ctx.world, p.x, p.y, 46, 40 * stacks, { procDepth = ctx.procDepth + 1, color = { 1, 0.8, 0.4 } })
            end,
        },
    },
    tags = { "proc", "fire", "explosive" },
}
