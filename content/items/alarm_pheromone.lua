-- Ants panic at the smell of their own alarm signal: they freeze and scatter.
local Combat = require("src.game.combat")
local util = require("src.core.util")

return {
    name = "Alarm Pheromone",
    description = "Kills have a 10% chance to release alarm scent: ants nearby panic, freezing for 1 second (+0.4 per stack) and scattering away.",
    rarity = "rare",
    category = "control",
    size = { 1, 1 },
    procs = {
        {
            trigger = "onKill",
            chance = 0.1,
            effect = function(ctx, stacks)
                local w = ctx.world
                for _, e in ipairs(Combat.collect(w, ctx.x, ctx.y, 55)) do
                    if not e.def.boss then
                        local nx, ny = util.normalize(e.x - ctx.x, e.y - ctx.y)
                        e.kvx, e.kvy = e.kvx + nx * 120 / e.mass, e.kvy + ny * 120 / e.mass
                        e.slowT, e.slowMul = math.max(e.slowT, 0.6 + 0.4 * stacks), 0.05
                    end
                end
                w:addFx({ kind = "ring", x = ctx.x, y = ctx.y, r = 55, life = 0.4, color = { 1, 0.4, 0.3 } })
            end,
        },
    },
    tags = { "utility", "proc", "bug" },
}
