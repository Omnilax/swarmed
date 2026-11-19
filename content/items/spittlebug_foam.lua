-- Cuckoo spit: the froth a spittlebug nymph hides in. Bite it and you get a mouthful.
local Combat = require("src.game.combat")

return {
    name = "Spittlebug Foam",
    description = "When hurt, 35% chance to burst into foam: every ant nearby is slowed by 50% for 2 seconds (+0.5 per stack).",
    effect = "When hurt, 35% chance to burst into foam: every ant nearby is slowed by 50% for 2 seconds (+0.5 per stack).",
    rarity = "uncommon",
    category = "control",
    shape = { "X.", "XX" },
    procs = {
        {
            trigger = "onHurt",
            chance = 0.35,
            chanceStack = 0.5,
            effect = function(ctx, stacks)
                local p, w = ctx.player, ctx.world
                local r = 60 * (1 + p.stats:get("area") / 100)
                local t = 1.5 + 0.5 * stacks
                for _, e in ipairs(Combat.collect(w, p.x, p.y, r)) do
                    e.slowT, e.slowMul = math.max(e.slowT, t), math.min(e.slowT > 0 and e.slowMul or 1, 0.5)
                end
                w:addFx({ kind = "ring", x = p.x, y = p.y, r = r, life = 0.4, color = { 0.95, 0.95, 0.9 } })
                for _ = 1, 14 do
                    local a, d = love.math.random() * math.pi * 2, love.math.random() * r
                    w.particles:spawn(p.x + math.cos(a) * d, p.y + math.sin(a) * d, 4, 0, 0, 10, 0.8, { 0.95, 0.95, 0.88 }, 2, { grav = -4 })
                end
            end,
        },
    },
    tags = { "utility", "defense", "bug" },
}
