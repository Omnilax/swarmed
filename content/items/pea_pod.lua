-- A dried pea pod that splits with a snap and fires its peas.
local ItemFx = require("src.game.itemfx")

return {
    name = "Pea Pod",
    description = "Every 8 seconds the pod snaps, firing 4 peas (+2 per stack) that knock ants far back for 8 damage.",
    effect = "Every 8 seconds the pod snaps, firing 4 peas (+2 per stack) that knock ants far back for 8 damage.",
    rarity = "common",
    category = "control",
    size = { 2, 1 },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                if not ItemFx.every(ctx, "pea_pod", 8) then return end
                local p, w = ctx.player, ctx.world
                local n = 2 + 2 * stacks
                local a0 = love.math.random() * math.pi * 2
                for i = 1, n do
                    local a = a0 + i / n * math.pi * 2
                    w.hazards:friendlyShot({ x = p.x, y = p.y, z = 6, vx = math.cos(a) * 200, vy = math.sin(a) * 200, r = 3,
                        damage = 8, pierce = 2, life = 0.6, knockback = 220, color = { 0.55, 0.8, 0.35 }, procDepth = 1 })
                end
            end,
        },
    },
    tags = { "utility", "plant" },
}
