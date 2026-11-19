-- Thorns: getting bitten can make the shell's spines lash out at everything around you.
local Combat = require("src.game.combat")

return {
    name = "Scarab Shell",
    description = "+8 Armor, +15 Max HP. When hurt, 30% chance to lash up to 5 ants around you for 10 damage (+10 per stack).",
    effect = "When hurt, 30% chance to lash up to 5 ants around you for 10 damage (+10 per stack).",
    rarity = "rare",
    category = "guard",
    shape = { "XXX", ".X." },
    stats = { armor = 8, maxHp = 15 },
    procs = {
        {
            trigger = "onHurt",
            chance = 0.3,
            effect = function(ctx, stacks)
                local p = ctx.player
                Combat.area(ctx.world, p.x, p.y, 34, 10 * stacks, { knockback = 140, procDepth = ctx.procDepth + 1 })
                ctx.world:addFx({ kind = "ring", x = p.x, y = p.y, r = 34, life = 0.18, color = { 0.4, 1, 0.6 } })
            end,
        },
    },
    tags = { "defense", "proc" },
}
