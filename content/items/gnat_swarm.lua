-- Isaac-style orbitals: gnats circle you and nibble whatever they touch.
local Combat = require("src.game.combat")
local ItemFx = require("src.game.itemfx")

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 0.25, 0.22, 0.18 }
local PFX_2 = { grav = 0 }
local PFX_3 = { 0.8, 0.85, 0.95 }
local PFX_4 = { glow = true, grav = 0 }

return {
    name = "Gnat Swarm",
    description = "2 gnats (+1 per stack) circle you, biting ants they touch for 6 damage (+3 per stack).",
    rarity = "rare",
    category = "elemental",
    size = { 1, 1 },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                local w, p = ctx.world, ctx.player
                local pts = ItemFx.orbit(w, p, 1 + stacks, 24, 3.2)
                local bite = ItemFx.every(ctx, "gnat_swarm", 0.25)
                for _, g in ipairs(pts) do
                    w.particles:spawn(g[1], g[2], 7, 0, 0, 0, 0.06, PFX_1, 2, PFX_2)
                    w.particles:spawn(g[1], g[2], 8, 0, 0, 0, 0.05, PFX_3, 1, PFX_4)
                    if bite then
                        local e = Combat.collect(w, g[1], g[2], 4)[1]
                        if e then Combat.damage(w, e, 3 + 3 * stacks, { procDepth = 1, noCrit = true }) end
                    end
                end
            end,
        },
    },
    tags = { "proc", "orbital" },
}
