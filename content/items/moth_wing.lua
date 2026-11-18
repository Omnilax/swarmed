local Combat = require("src.game.combat")

return {
    name = "Moth Wing",
    description = "+7% Dodge, +4 Speed. Dodging shakes off a cloud of scales that slows every ant around you for 1.5 seconds (+0.5 per stack).",
    effect = "Dodging shakes off a cloud of scales that slows every ant around you for 1.5 seconds (+0.5 per stack).",
    rarity = "uncommon",
    category = "guard",
    shape = { "XX", "X." },
    stats = { dodge = 7, moveSpeed = 4 },
    procs = {
        {
            trigger = "onDodge",
            effect = function(ctx, stacks)
                local p, w = ctx.player, ctx.world
                local t = 1 + 0.5 * stacks
                for _, e in ipairs(Combat.collect(w, p.x, p.y, 45)) do
                    e.slowT, e.slowMul = math.max(e.slowT, t), math.min(e.slowT > 0 and e.slowMul or 1, 0.3)
                end
                w.particles:burst(p.x, p.y, 12, { { 0.8, 0.75, 0.65 }, { 0.6, 0.55, 0.5 } }, 60, 25, { grav = 20, drag = 3 })
            end,
        },
    },
    tags = { "defense", "utility", "bug" },
}
