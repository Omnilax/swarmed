-- Cursed: the worst sting there is, injected on purpose. You fight in a rage, but every wave
-- starts with you at half health at most.
return {
    name = "Bullet Ant Venom",
    description = "+40% Attack Speed, +20% Damage. Cursed: every wave starts with you at half HP at most.",
    curse = "Every wave starts with you at half HP at most.",
    rarity = "cursed",
    size = { 1, 2 },
    stats = { attackSpeed = 40, damage = 20 },
    procs = {
        {
            trigger = "onWaveStart",
            effect = function(ctx)
                local p = ctx.player
                local half = p.stats:get("maxHp") * 0.5
                if p.hp > half then
                    p.hp = half
                    ctx.world:floatText(p.x, p.y - 10, "VENOM", { 0.75, 0.45, 1 }, true)
                end
            end,
        },
    },
    tags = { "cursed", "offense" },
}
