-- A bolas spider fishes with one sticky blob on a line, and never misses.
local Combat = require("src.game.combat")
local ItemFx = require("src.game.itemfx")

return {
    name = "Bolas Thread",
    description = "Every 5 seconds, a sticky bola roots the toughest ant nearby (queens and elites first) for 1.5 seconds (+0.5 per stack) and hits it for 20.",
    effect = "Every 5 seconds, a sticky bola roots the toughest ant nearby (queens and elites first) for 1.5 seconds (+0.5 per stack) and hits it for 20.",
    rarity = "rare",
    category = "control",
    size = { 1, 3 },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                if not ItemFx.every(ctx, "bolas_thread", 5) then return end
                local p, w = ctx.player, ctx.world
                local best, score
                for _, e in ipairs(Combat.collect(w, p.x, p.y, 170)) do
                    local s = e.maxHp or e.hp or 1
                    if e.def.boss or e.def.queen then s = s * 100 elseif e.elite then s = s * 10 end
                    if not score or s > score then best, score = e, s end
                end
                if not best then return end
                best.slowT, best.slowMul = math.max(best.slowT, 1 + 0.5 * stacks), 0
                best.kvx, best.kvy = 0, 0
                Combat.damage(w, best, 20, { procDepth = 1 })
                w:addFx({ kind = "bolt", x = p.x, y = p.y, x2 = best.x, y2 = best.y, life = 0.25, color = { 0.95, 0.92, 0.75 } })
            end,
        },
    },
    tags = { "utility", "proc", "bug" },
}
