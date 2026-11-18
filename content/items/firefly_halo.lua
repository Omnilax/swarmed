-- Molted from Gnat Swarm + Firefly Lantern (content/molts/firefly_halo.lua).
local Combat = require("src.game.combat")
local ItemFx = require("src.game.itemfx")

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 1, 0.95, 0.45 }
local PFX_2 = { glow = true, grav = 0 }

return {
    name = "Firefly Halo",
    description = "+10% Area. 4 fireflies (+2 per stack) circle you, burning ants they touch for 12 damage (+6 per stack) and dazzling them (slowed).",
    effect = "4 fireflies (+2 per stack) circle you, burning ants they touch for 12 damage (+6 per stack) and dazzling them (slowed).",
    rarity = "molted",
    category = "elemental",
    size = { 1, 1 },
    stats = { area = 10 },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                local w, p = ctx.world, ctx.player
                local pts = ItemFx.orbit(w, p, 2 + 2 * stacks, 30, 2.6)
                local bite = ItemFx.every(ctx, "firefly_halo", 0.25)
                for _, g in ipairs(pts) do
                    w.particles:spawn(g[1], g[2], 8, 0, 0, 0, 0.06, PFX_1, 2, PFX_2)
                    if bite then
                        local e = Combat.collect(w, g[1], g[2], 5)[1]
                        if e then Combat.damage(w, e, 6 + 6 * stacks, { procDepth = 1, noCrit = true, slow = { 0.4, 1 } }) end
                    end
                end
            end,
        },
    },
    tags = { "proc", "orbital", "utility" },
}
