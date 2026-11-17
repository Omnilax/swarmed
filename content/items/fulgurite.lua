-- Glass made where lightning hit sand; it still calls it down.
local Combat = require("src.game.combat")
local ItemFx = require("src.game.itemfx")

return {
    name = "Fulgurite",
    description = "Every 3 seconds lightning strikes an ant near you for 20 damage (+20 per stack) and arcs to 2 more.",
    rarity = "rare",
    category = "elemental",
    shape = { "X.", "XX", "X." },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                if not ItemFx.every(ctx, "fulgurite", 3) then return end
                local w, p = ctx.world, ctx.player
                local e = ItemFx.randomEnemy(w, p.x, p.y, 130)
                if not e then return end
                w:addFx({ kind = "bolt", x = e.x - 18, y = e.y - 30, x2 = e.x, y2 = e.y, life = 0.25, color = { 0.75, 0.85, 1 } })
                w:addFx({ kind = "ring", x = e.x, y = e.y, r = 16, life = 0.2, color = { 0.75, 0.85, 1 } })
                Combat.damage(w, e, 20 * stacks, { procDepth = 1, noCrit = true })
                Combat.chain(w, e, 2, 70, 10 * stacks, { procDepth = 1, noCrit = true })
            end,
        },
    },
    tags = { "proc", "lightning" },
}
