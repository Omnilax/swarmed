-- Molted from Chitin Plate + Scarab Shell (content/molts/goliath_carapace.lua).
local Combat = require("src.game.combat")

return {
    name = "Goliath Carapace",
    description = "+18 Armor, +30 Max HP. When hurt, 50% chance to lash up to 5 ants around you for 30 damage (+30 per stack).",
    effect = "When hurt, 50% chance to lash up to 5 ants around you for 30 damage (+30 per stack).",
    rarity = "molted",
    category = "guard",
    size = { 2, 2 },
    stats = { armor = 18, maxHp = 30 },
    procs = {
        {
            trigger = "onHurt",
            chance = 0.5,
            effect = function(ctx, stacks)
                local p = ctx.player
                Combat.area(ctx.world, p.x, p.y, p.radius + 26, 30 * stacks, { noCrit = true, procDepth = ctx.procDepth + 1, knockback = 90 })
                ctx.world:addFx({ kind = "ring", x = p.x, y = p.y, r = p.radius + 26, life = 0.3, color = { 0.4, 1, 0.7 } })
            end,
        },
    },
    tags = { "defense", "proc" },
}
