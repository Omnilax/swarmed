local ItemFx = require("src.game.itemfx")

return {
    name = "Bacterial Bloom",
    description = "Kills have a 20% chance to leave a bacterial mat for 4 seconds that poisons ants on it for 5 damage a second (+5 per stack).",
    rarity = "rare",
    shape = { "XX", "X." },
    procs = {
        {
            trigger = "onKill",
            chance = 0.2,
            effect = function(ctx, stacks)
                ItemFx.patch(ctx.world, { x = ctx.x, y = ctx.y, r = 22 + 3 * stacks, life = 4, dps = 5 * stacks, color = { 0.55, 0.85, 0.35 } })
            end,
        },
    },
    tags = { "poison", "proc", "microbe" },
}
