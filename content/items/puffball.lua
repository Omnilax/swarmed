local Combat = require("src.game.combat")

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 0.75, 0.7, 0.55 }
local PFX_2 = { 0.6, 0.55, 0.45 }
local PFX_3 = { grav = -15, drag = 2 }
local PFX_LIST_1 = { PFX_1, PFX_2 }

return {
    name = "Puffball",
    description = "When bitten, 25% chance to burst a spore cloud: ants around you are slowed and poisoned for 4 damage a second (+4 per stack).",
    rarity = "uncommon",
    category = "elemental",
    size = { 1, 1 },
    procs = {
        {
            trigger = "onHurt",
            chance = 0.25,
            effect = function(ctx, stacks)
                local p, w = ctx.player, ctx.world
                for _, e in ipairs(Combat.collect(w, p.x, p.y, 50)) do
                    e.poisonT, e.poisonDps = math.max(e.poisonT, 3), math.max(e.poisonDps, 4 * stacks)
                    e.slowT, e.slowMul = math.max(e.slowT, 2), math.min(e.slowT > 0 and e.slowMul or 1, 0.4)
                end
                w.particles:burst(p.x, p.y, 16, PFX_LIST_1, 70, 30, PFX_3)
                w:addFx({ kind = "ring", x = p.x, y = p.y, r = 50, life = 0.4, color = { 0.8, 0.75, 0.6 } })
            end,
        },
    },
    tags = { "poison", "defense", "proc", "fungus" },
}
