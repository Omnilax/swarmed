-- The great horn of a Hercules beetle: it fights hardest when it's losing.
local ItemFx = require("src.game.itemfx")

return {
    name = "Hercules Horn",
    description = "+1% Damage for every 1% of HP you are missing, up to +40% (+20% per stack).",
    effect = "+1% Damage for every 1% of HP you are missing, up to +40% (+20% per stack).",
    rarity = "legendary",
    category = "attack",
    size = { 1, 3 },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                local p = ctx.player
                if not ItemFx.every(ctx, "hercules_horn", 0.2) then return end
                local full = p.stats:get("maxHp")
                local missing = full > 0 and (1 - p.hp / full) * 100 or 0
                local add = math.floor(math.min(20 + 20 * stacks, math.max(0, missing)))
                ItemFx.buff(p, "hercules_horn", "damage", add, 0, 0.5)
            end,
        },
    },
    tags = { "offense", "bug" },
}
