-- A dragonfly nymph breathes through its rear end, and jets water out of it to dart away.
local Combat = require("src.game.combat")

return {
    name = "Dragonfly Nymph Gill",
    description = "-0.2 s Dash Cooldown. Every dash fires a water jet backwards for 15 damage (+8 per stack).",
    effect = "Every dash fires a water jet backwards for 15 damage (+8 per stack).",
    rarity = "rare",
    category = "move",
    size = { 1, 2 },
    stats = { dashCooldown = -0.2 },
    procs = {
        {
            trigger = "onDash",
            effect = function(ctx, stacks)
                local p, w = ctx.player, ctx.world
                local dx, dy = p.dashX, p.dashY
                local l = math.sqrt(dx * dx + dy * dy)
                if l < 0.01 then dx, dy, l = p.aimX, p.aimY, 1 end
                dx, dy = -dx / l, -dy / l
                for k = -1, 1 do
                    local a = math.atan2(dy, dx) + k * 0.12
                    w.hazards:friendlyShot({ x = p.x, y = p.y, z = 4, vx = math.cos(a) * 260, vy = math.sin(a) * 260, r = 2,
                        damage = 7 + 8 * stacks, pierce = 2, life = 0.35, knockback = 60, color = { 0.6, 0.85, 1 }, procDepth = 1 })
                end
            end,
        },
    },
    tags = { "mobility", "proc", "bug" },
}
