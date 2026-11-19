-- Fungus that grows through poisoned bodies: kills on poisoned ants burst into spores.
local Combat = require("src.game.combat")

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 1, 0.65, 0.25 }
local PFX_2 = { 0.85, 0.75, 0.5 }
local PFX_3 = { glow = true, grav = -20 }
local PFX_LIST_1 = { PFX_1, PFX_2 }

return {
    name = "Cordyceps",
    description = "Killing a poisoned ant bursts it into spores, poisoning every ant within reach for 6 damage a second (+6 per stack) for 3 seconds.",
    rarity = "rare",
    category = "elemental",
    shape = { "X", "X", "X" },
    procs = {
        {
            trigger = "onKill",
            effect = function(ctx, stacks)
                local e = ctx.target
                if (e.poisonT or 0) <= 0 then return end
                local w = ctx.world
                for _, o in ipairs(Combat.collect(w, ctx.x, ctx.y, 40)) do
                    o.poisonT, o.poisonDps = math.max(o.poisonT, 3), math.max(o.poisonDps, 6 * stacks)
                end
                w:addFx({ kind = "ring", x = ctx.x, y = ctx.y, r = 40, life = 0.35, color = { 0.95, 0.6, 0.2 } })
                w.particles:burst(ctx.x, ctx.y, 10, PFX_LIST_1, 50, 40, PFX_3)
            end,
        },
    },
    tags = { "poison", "proc", "fungus" },
}
