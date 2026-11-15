-- Molted from Honeycomb + Royal Jelly + Sugar Cube (content/molts/queens_comb.lua).
return {
    name = "Queen's Comb",
    description = "+45 Max HP, +4 HP Regen, +10% Damage. Every wave starts by healing you to full.",
    effect = "Every wave starts by healing you to full.",
    rarity = "molted",
    size = { 2, 2 },
    stats = { maxHp = 45, hpRegen = 4, damage = 10 },
    procs = {
        { trigger = "onWaveStart", effect = function(ctx) ctx.player:heal(ctx.player.stats:get("maxHp")) end },
    },
    tags = { "defense", "healing" },
}
