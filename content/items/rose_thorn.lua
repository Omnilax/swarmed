local Combat = require("src.game.combat")

return {
    name = "Rose Thorn",
    description = "+1 Armor. When bitten, 50% chance to prick every ant touching you for 5 damage (+5 per stack).",
    effect = "When bitten, 50% chance to prick every ant touching you for 5 damage (+5 per stack).",
    rarity = "common",
    size = { 1, 1 },
    stats = { armor = 1 },
    procs = {
        {
            trigger = "onHurt",
            chance = 0.5,
            effect = function(ctx, stacks)
                local p = ctx.player
                Combat.area(ctx.world, p.x, p.y, p.radius + 6, 5 * stacks, { noCrit = true, procDepth = ctx.procDepth + 1, knockback = 40 })
            end,
        },
    },
    tags = { "defense", "proc", "plant" },
}
