-- Molted from Rose Thorn + Cactus Spine (content/molts/bramble_hide.lua).
local Combat = require("src.game.combat")

return {
    name = "Bramble Hide",
    description = "+9 Armor. When bitten, prick every ant touching you for 12 damage (+12 per stack), and 50% chance to fire 6 spines (+2 per stack) for 16 damage each.",
    effect = "When bitten, prick every ant touching you for 12 damage (+12 per stack), and 50% chance to fire 6 spines (+2 per stack) for 16 damage each.",
    rarity = "molted",
    category = "guard",
    shape = { "X", "X" },
    stats = { armor = 9 },
    procs = {
        {
            trigger = "onHurt",
            effect = function(ctx, stacks)
                local p = ctx.player
                Combat.area(ctx.world, p.x, p.y, p.radius + 8, 12 * stacks, { noCrit = true, procDepth = ctx.procDepth + 1, knockback = 50 })
            end,
        },
        {
            trigger = "onHurt",
            chance = 0.5,
            effect = function(ctx, stacks)
                local p, n = ctx.player, 4 + 2 * stacks
                local a0 = love.math.random() * math.pi * 2
                for i = 1, n do
                    local a = a0 + i / n * math.pi * 2
                    ctx.world.hazards:friendlyShot({ x = p.x, y = p.y, z = 6, vx = math.cos(a) * 240, vy = math.sin(a) * 240,
                        r = 2, damage = 16, pierce = 2, life = 0.55, knockback = 60, color = { 0.6, 0.95, 0.5 }, procDepth = 1 })
                end
            end,
        },
    },
    tags = { "defense", "proc", "plant" },
}
