local Combat = require("src.game.combat")
local ItemFx = require("src.game.itemfx")

return {
    name = "Venus Flytrap",
    description = "Every 3 seconds the trap snaps shut on the nearest ant for 30 damage (+30 per stack) and digests it for 2 HP.",
    rarity = "rare",
    category = "mend",
    shape = { "X.X", "XXX" },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                if not ItemFx.every(ctx, "venus_flytrap", 3) then return end
                local w, p = ctx.world, ctx.player
                local e = w:nearestEnemy(p.x, p.y, 60)
                if not e then return end
                w:addFx({ kind = "ring", x = e.x, y = e.y, r = 12, life = 0.25, color = { 0.6, 1, 0.35 } })
                w.particles:sparks(e.x, e.y, 6, { 0.9, 0.3, 0.2 }, e.x - p.x, e.y - p.y, 1.5, 90)
                Combat.damage(w, e, 30 * stacks, { procDepth = 1 })
                p:heal(2)
            end,
        },
    },
    tags = { "offense", "healing", "plant" },
}
