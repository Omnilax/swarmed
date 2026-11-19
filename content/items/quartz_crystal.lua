-- Piezoelectric: struck hard enough, it sparks.
local ItemFx = require("src.game.itemfx")

return {
    name = "Quartz Crystal",
    description = "+8% Crit Chance. Critical hits arc to 2 more ants (+1 per stack) for half the damage.",
    effect = "Critical hits arc to 2 more ants (+1 per stack) for half the damage.",
    rarity = "rare",
    category = "elemental",
    size = { 1, 2 },
    stats = { critChance = 8 },
    procs = {
        {
            trigger = "onHit",
            effect = function(ctx, stacks)
                if not ctx.crit then return end
                require("src.game.combat").chain(ctx.world, ctx.target, 1 + stacks, 70, ctx.damage * 0.5,
                    { coefficient = ItemFx.unscaled(ctx.player), noCrit = true, procDepth = ctx.procDepth + 1, color = { 0.85, 0.8, 1 } })
            end,
        },
    },
    tags = { "offense", "lightning", "proc" },
}
