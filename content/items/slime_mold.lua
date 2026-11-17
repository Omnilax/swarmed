-- Physarum: reaches out on its own every couple of seconds for the closest ant.
local Combat = require("src.game.combat")
local ItemFx = require("src.game.itemfx")

return {
    name = "Slime Mold",
    description = "Every 2 seconds a slime tendril lashes the nearest ant within reach for 10 damage (+10 per stack) and gums it up for 2 seconds.",
    rarity = "rare",
    category = "elemental",
    shape = { "X.", "XX", ".X" },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                if not ItemFx.every(ctx, "slime_mold", 2) then return end
                local p, w = ctx.player, ctx.world
                local e = w:nearestEnemy(p.x, p.y, 100)
                if not e then return end
                w:addFx({ kind = "bolt", x = p.x, y = p.y, x2 = e.x, y2 = e.y, life = 0.3, color = { 1, 0.85, 0.2 } })
                Combat.damage(w, e, 10 * stacks, { procDepth = 1, slow = { 0.35, 2 } })
            end,
        },
    },
    tags = { "proc", "microbe" },
}
