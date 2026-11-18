-- A monarch butterfly's wing: it rides the wind for thousands of miles.
local ItemFx = require("src.game.itemfx")

return {
    name = "Monarch Wing",
    description = "+15 Speed. Every 12 seconds a tailwind lifts you: +40% Speed and +20% Dodge for 3 seconds (+1 per stack).",
    effect = "Every 12 seconds a tailwind lifts you: +40% Speed and +20% Dodge for 3 seconds (+1 per stack).",
    rarity = "legendary",
    category = "move",
    size = { 2, 2 },
    stats = { moveSpeed = 15 },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                if not ItemFx.every(ctx, "monarch_wing", 12) then return end
                local p, w = ctx.player, ctx.world
                local t = 2 + stacks
                ItemFx.buff(p, "monarch_speed", "moveSpeed", 0, 0.4, t)
                ItemFx.buff(p, "monarch_dodge", "dodge", 20, 0, t)
                w:floatText(p.x, p.y - 12, "TAILWIND", { 1, 0.7, 0.3 })
                for _ = 1, 10 do
                    local a = love.math.random() * math.pi * 2
                    w.particles:spawn(p.x, p.y, 4, math.cos(a) * 60, math.sin(a) * 60, 20, 0.5, { 1, 0.6, 0.2 }, 1, { glow = true, grav = 0 })
                end
            end,
        },
    },
    tags = { "mobility", "bug" },
}
