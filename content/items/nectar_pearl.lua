-- Molted from Dew Drop + Honeydew (content/molts/nectar_pearl.lua).
return {
    name = "Nectar Pearl",
    description = "+18 Max HP, +1.5 HP Regen. Kills have a 15% chance to heal 4 HP (+4 per stack).",
    effect = "Kills have a 15% chance to heal 4 HP (+4 per stack).",
    rarity = "molted",
    size = { 1, 1 },
    stats = { maxHp = 18, hpRegen = 1.5 },
    procs = {
        { trigger = "onKill", chance = 0.15, effect = function(ctx, stacks) ctx.player:heal(4 * stacks) end },
    },
    tags = { "healing", "defense" },
}
