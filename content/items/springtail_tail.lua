-- A springtail's furcula: a tiny catapult under the belly that flings it out of danger.
local Combat = require("src.game.combat")

return {
    name = "Springtail Tail",
    description = "+5% Dodge. A dodge flicks you a body-length away from the nearest ant.",
    effect = "A dodge flicks you a body-length away from the nearest ant.",
    rarity = "rare",
    category = "move",
    size = { 1, 1 },
    stats = { dodge = 5 },
    procs = {
        {
            trigger = "onDodge",
            effect = function(ctx, stacks)
                local p = ctx.player
                local near = Combat.collect(ctx.world, p.x, p.y, 40)
                local dx, dy = -p.aimX, -p.aimY
                if near[1] then
                    dx, dy = p.x - near[1].x, p.y - near[1].y
                    local l = math.sqrt(dx * dx + dy * dy)
                    if l > 0.01 then dx, dy = dx / l, dy / l end
                end
                p:lunge(dx, dy, 22 + 6 * stacks, 0.9)
                ctx.world.particles:spawn(p.x, p.y, 6, 0, 0, 40, 0.25, { 0.75, 0.9, 1 }, 1, { glow = true, grav = 0 })
            end,
        },
    },
    tags = { "mobility", "defense", "bug" },
}
