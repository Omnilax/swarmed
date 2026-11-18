return {
    name = "Cactus Spine",
    description = "+4 Armor. When bitten, 30% chance to fire 3 spines (+1 per stack) outward for 10 damage each.",
    effect = "When bitten, 30% chance to fire 3 spines (+1 per stack) outward for 10 damage each.",
    rarity = "uncommon",
    category = "guard",
    shape = { "X", "X" },
    stats = { armor = 4 },
    procs = {
        {
            trigger = "onHurt",
            chance = 0.3,
            effect = function(ctx, stacks)
                local p, n = ctx.player, 2 + stacks
                local a0 = love.math.random() * math.pi * 2
                for i = 1, n do
                    local a = a0 + i / n * math.pi * 2
                    ctx.world.hazards:friendlyShot({ x = p.x, y = p.y, z = 6, vx = math.cos(a) * 220, vy = math.sin(a) * 220,
                        r = 2, damage = 10, pierce = 1, life = 0.5, knockback = 50, color = { 0.85, 0.9, 0.6 }, procDepth = 1 })
                end
            end,
        },
    },
    tags = { "defense", "proc", "plant" },
}
