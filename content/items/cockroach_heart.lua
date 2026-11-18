return {
    name = "Cockroach Heart",
    description = "+1 HP Regen, +8 Max HP. Below 30% HP you heal 3 more HP a second (+3 per stack).",
    effect = "Below 30% HP you heal 3 more HP a second (+3 per stack).",
    rarity = "rare",
    category = "mend",
    size = { 1, 1 },
    stats = { hpRegen = 1, maxHp = 8 },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                local p = ctx.player
                if p.hp < p.stats:get("maxHp") * 0.3 then p:heal(3 * stacks * ctx.dt) end
            end,
        },
    },
    tags = { "healing", "bug" },
}
