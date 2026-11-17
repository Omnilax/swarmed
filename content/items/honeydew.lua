local Combat = require("src.game.combat")

return {
    name = "Honeydew",
    description = "+4 Max HP. Kills have an 8% chance to heal 2 HP (+2 per stack).",
    effect = "Kills have an 8% chance to heal 2 HP (+2 per stack).",
    rarity = "common",
    category = "mend",
    size = { 1, 1 },
    stats = { maxHp = 4 },
    procs = {
        { trigger = "onKill", chance = 0.08, effect = function(ctx, stacks) ctx.player:heal(2 * stacks) end },
    },
    tags = { "healing" },
}
