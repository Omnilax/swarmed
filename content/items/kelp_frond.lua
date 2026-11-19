-- A ribbon of kelp, still wet and salty. Shore item.
return {
    name = "Kelp Frond",
    description = "+0.6 HP Regen, +6 Max HP. Each wave starts by healing 8% of Max HP (+8% per stack). Crustaceans: +0.4 HP Regen more.",
    effect = "Each wave starts by healing 8% of Max HP (+8% per stack).",
    rarity = "uncommon",
    category = "mend",
    size = { 1, 2 },
    stats = { hpRegen = 0.6, maxHp = 6 },
    kin = { tags = { "crustacean" }, stats = { hpRegen = 0.4 } },
    procs = {
        { trigger = "onWaveStart", effect = function(ctx, stacks) ctx.player:heal(ctx.player.stats:get("maxHp") * 0.08 * stacks) end },
    },
    tags = { "healing", "plant", "shore" },
}
