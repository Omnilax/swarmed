-- Sharp little volcanoes glued to whatever they settled on. Shore item.
local Combat = require("src.game.combat")

return {
    name = "Barnacle Cluster",
    description = "+4 Armor. When bitten, 30% chance (more per stack) the barnacles cut every ant touching you for 8 damage (+8 per stack). Crustaceans: +2 Armor more.",
    effect = "When bitten, 30% chance (more per stack) the barnacles cut every ant touching you for 8 damage (+8 per stack).",
    rarity = "common",
    category = "guard",
    shape = { "X.", "XX" },
    stats = { armor = 4 },
    kin = { tags = { "crustacean" }, stats = { armor = 2 } },
    procs = {
        {
            trigger = "onHurt",
            chance = 0.3,
            chanceStack = 0.5,
            effect = function(ctx, stacks)
                local p = ctx.player
                Combat.area(ctx.world, p.x, p.y, p.radius + 7, 8 * stacks, { noCrit = true, procDepth = ctx.procDepth + 1, knockback = 30 })
            end,
        },
    },
    tags = { "defense", "proc", "shore" },
}
