-- Ophiocordyceps takes over an ant and bursts out of its head. It isn't picky about whose.
local ItemFx = require("src.game.itemfx")

return {
    name = "Zombie Fungus",
    description = "+30% Damage. Kills have a 15% chance to burst into spores that poison ants for 8 a second. Cursed: the spores hurt you too.",
    curse = "Standing in the spores hurts you for 4 a second.",
    rarity = "cursed",
    category = "cursed",
    size = { 1, 2 },
    stats = { damage = 30 },
    procs = {
        {
            trigger = "onKill",
            chance = 0.15,
            effect = function(ctx, stacks)
                ItemFx.patch(ctx.world, { x = ctx.x, y = ctx.y, r = 24, life = 3, dps = 4 + 4 * stacks, hurtPlayer = 4,
                    color = { 0.75, 0.55, 0.85 } })
            end,
        },
    },
    tags = { "cursed", "poison", "fungus" },
}
