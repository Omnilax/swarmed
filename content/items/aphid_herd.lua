-- Ants farm aphids for honeydew. Now you do too.
local ItemFx = require("src.game.itemfx")

return {
    name = "Aphid Herd",
    description = "3 aphids follow you around. Every 10 seconds one is milked for 3 HP (+2 per stack).",
    effect = "3 aphids follow you around. Every 10 seconds one is milked for 3 HP (+2 per stack).",
    rarity = "uncommon",
    category = "mend",
    size = { 2, 1 },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                local w, p = ctx.world, ctx.player
                local pts = ItemFx.orbit(w, p, 3, 16, 0.9)
                for _, g in ipairs(pts) do
                    w.particles:spawn(g[1], g[2], 3, 0, 0, 0, 0.06, { 0.55, 0.85, 0.35 }, 2, { grav = 0 })
                end
                if ItemFx.every(ctx, "aphid_herd", 10) and p.hp < p.stats:get("maxHp") then
                    local hp = 1 + 2 * stacks
                    p:heal(hp)
                    local g = pts[love.math.random(#pts)]
                    w.particles:spawn(g[1], g[2], 6, 0, 0, 30, 0.6, { 0.95, 0.9, 0.5 }, 2, { glow = true, grav = -20 })
                    w:floatText(p.x, p.y - 10, "+" .. hp, { 0.5, 1, 0.5 })
                end
            end,
        },
    },
    tags = { "healing", "bug" },
}
