-- A pinch of sand from an antlion's pit: ants that fall in can't climb out.
local ItemFx = require("src.game.itemfx")

return {
    name = "Antlion Sand",
    description = "Kills have a 10% chance to leave a sand pit that slows ants inside by 50% for 4 seconds.",
    effect = "Kills have a 10% chance to leave a sand pit that slows ants inside by 50% for 4 seconds.",
    rarity = "uncommon",
    category = "control",
    size = { 1, 1 },
    procs = {
        {
            trigger = "onKill",
            chance = 0.1,
            effect = function(ctx, stacks)
                local r = (20 + 4 * stacks) * (1 + ctx.player.stats:get("area") / 100)
                ItemFx.patch(ctx.world, { x = ctx.x, y = ctx.y, r = r, life = 4, slow = 0.5, color = { 0.85, 0.72, 0.45 } })
            end,
        },
    },
    tags = { "utility", "bug" },
}
