-- Molted from Static Antenna + Quartz Crystal (content/molts/storm_antenna.lua).
local Combat = require("src.game.combat")
local ItemFx = require("src.game.itemfx")

return {
    name = "Storm Antenna",
    description = "+12% Crit Chance. Hits have a 20% chance to zap 6 ants (+2 per stack) for 12 damage (+12 per stack). Critical hits arc to 4 more ants for the full damage.",
    effect = "Hits have a 20% chance to zap 6 ants (+2 per stack) for 12 damage (+12 per stack). Critical hits arc to 4 more ants for the full damage.",
    rarity = "molted",
    category = "elemental",
    size = { 1, 2 },
    stats = { critChance = 12 },
    procs = {
        {
            trigger = "onHit",
            chance = 0.2,
            effect = function(ctx, stacks)
                Combat.chain(ctx.world, ctx.target, 4 + 2 * stacks, 90, 12 * stacks, { procDepth = ctx.procDepth + 1, noCrit = true })
            end,
        },
        {
            trigger = "onHit",
            effect = function(ctx, stacks)
                if not ctx.crit then return end
                Combat.chain(ctx.world, ctx.target, 3 + stacks, 80, ctx.damage,
                    { coefficient = ItemFx.unscaled(ctx.player), noCrit = true, procDepth = ctx.procDepth + 1, color = { 0.8, 0.9, 1 } })
            end,
        },
    },
    tags = { "offense", "proc", "lightning" },
}
