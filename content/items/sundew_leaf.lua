-- A sundew's sticky-tipped leaf: whatever touches it stays there.
local Combat = require("src.game.combat")
local ItemFx = require("src.game.itemfx")

return {
    name = "Sundew Leaf",
    description = "Every 6 seconds, ants touching you are glued in place for 1 second (+0.5 per stack).",
    effect = "Every 6 seconds, ants touching you are glued in place for 1 second (+0.5 per stack).",
    rarity = "rare",
    category = "control",
    size = { 2, 1 },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                if not ItemFx.every(ctx, "sundew_leaf", 6) then return end
                local p, w = ctx.player, ctx.world
                local t = 0.5 + 0.5 * stacks
                local r = p.radius + 14
                for _, e in ipairs(Combat.collect(w, p.x, p.y, r)) do
                    e.slowT, e.slowMul = math.max(e.slowT, t), 0
                    e.kvx, e.kvy = 0, 0
                    w.particles:spawn(e.x, e.y, 4, 0, 0, 6, 0.5, { 0.95, 0.4, 0.5 }, 3, { glow = true, grav = 0 })
                end
                w:addFx({ kind = "ring", x = p.x, y = p.y, r = r, life = 0.3, color = { 0.95, 0.45, 0.55 } })
            end,
        },
    },
    tags = { "utility", "plant" },
}
