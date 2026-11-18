return {
    name = "Dandelion Puff",
    description = "+6 Speed. Dashing scatters 4 seeds (+2 per stack) that drift out and cut through ants for 6 damage each.",
    effect = "Dashing scatters 4 seeds (+2 per stack) that drift out and cut through ants for 6 damage each.",
    rarity = "uncommon",
    category = "move",
    size = { 1, 2 },
    stats = { moveSpeed = 6 },
    procs = {
        {
            trigger = "onDash",
            effect = function(ctx, stacks)
                local p, n = ctx.player, 2 + 2 * stacks
                for i = 1, n do
                    local a = i / n * math.pi * 2 + love.math.random() * 0.4
                    local v = 70 + love.math.random() * 30
                    ctx.world.hazards:friendlyShot({ x = p.x, y = p.y, z = 8, vx = math.cos(a) * v, vy = math.sin(a) * v,
                        r = 3, damage = 6, pierce = 2, life = 1.3, knockback = 20, color = { 0.95, 0.95, 0.85 } })
                end
            end,
        },
    },
    tags = { "proc", "mobility", "plant" },
}
