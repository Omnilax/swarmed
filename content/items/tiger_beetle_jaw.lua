-- The tiger beetle runs so fast it goes blind, then bites whatever it hits.
local ItemFx = require("src.game.itemfx")

return {
    name = "Tiger Beetle Jaw",
    description = "+6% Damage. For 2 seconds after a dash, +25% Damage (+15% per stack).",
    effect = "For 2 seconds after a dash, +25% Damage (+15% per stack).",
    rarity = "uncommon",
    category = "attack",
    size = { 1, 2 },
    stats = { damage = 6 },
    procs = {
        {
            trigger = "onDash",
            effect = function(ctx, stacks)
                ItemFx.buff(ctx.player, "tiger_beetle_jaw", "damage", 10 + 15 * stacks, 0, 2)
            end,
        },
    },
    tags = { "offense", "mobility", "bug" },
}
