return {
    name = "Firefly Lantern",
    description = "+10% Area. Kills have a 10% chance (more per stack) to flash, slowing every ant nearby for 1.5 seconds.",
    effect = "Kills have a 10% chance (more per stack) to flash, slowing every ant nearby for 1.5 seconds.",
    rarity = "uncommon",
    category = "control",
    size = { 1, 2 },
    stats = { area = 10 },
    procs = {
        {
            trigger = "onKill",
            chance = 0.1,
            chanceStack = 0.5,   -- the flash barely grows, so copies make it fire more often
            effect = function(ctx, stacks)
                local Combat = require("src.game.combat")
                for _, e in ipairs(Combat.collect(ctx.world, ctx.x, ctx.y, 40 + 10 * stacks)) do
                    e.slowT, e.slowMul = math.max(e.slowT, 1.5), math.min(e.slowMul, 0.35)
                end
                ctx.world:addFx({ kind = "ring", x = ctx.x, y = ctx.y, r = 40 + 10 * stacks, life = 0.25, color = { 0.95, 1, 0.5 } })
            end,
        },
    },
    tags = { "utility", "proc" },
}
