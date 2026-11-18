-- A strip of bark still glowing from a grass fire.
local ItemFx = require("src.game.itemfx")

return {
    name = "Smoldering Bark",
    description = "Kills have a 12% chance to set the ground alight: ants in the embers burn for 6 damage a second (+4 per stack) for 3 seconds.",
    effect = "Kills have a 12% chance to set the ground alight: ants in the embers burn for 6 damage a second (+4 per stack) for 3 seconds.",
    rarity = "uncommon",
    category = "elemental",
    size = { 2, 1 },
    procs = {
        {
            trigger = "onKill",
            chance = 0.12,
            effect = function(ctx, stacks)
                local r = 22 * (1 + ctx.player.stats:get("area") / 100)
                ItemFx.patch(ctx.world, { x = ctx.x, y = ctx.y, r = r, life = 3, dps = 2 + 4 * stacks, color = { 1, 0.5, 0.15 } })
            end,
        },
    },
    tags = { "fire", "proc", "plant" },
}
