-- Molting: dropping low splits the old skin and you step out fresh.
local ItemFx = require("src.game.itemfx")

return {
    name = "Cicada Shell",
    description = "+6 Armor. Once per wave (+1 per stack), falling below 30% HP makes you molt: untouchable for 1.5 seconds and healed for 25% of Max HP.",
    effect = "Once per wave (+1 per stack), falling below 30% HP makes you molt: untouchable for 1.5 seconds and healed for 25% of Max HP.",
    rarity = "rare",
    category = "guard",
    size = { 2, 2 },
    stats = { armor = 6 },
    procs = {
        {
            trigger = "onHurt",
            effect = function(ctx, stacks)
                local p, s = ctx.player, ItemFx.state(ctx.player, "cicada_shell")
                local maxHp = p.stats:get("maxHp")
                if p.hp <= 0 or p.hp > maxHp * 0.3 or (s.used or 0) >= stacks then return end
                s.used = (s.used or 0) + 1
                p.iframes = math.max(p.iframes, 1.5)
                p:heal(maxHp * 0.25)
                ctx.world:floatText(p.x, p.y, "MOLT", { 0.95, 0.8, 0.5 }, true)
                ctx.world.particles:burst(p.x, p.y, 12, { { 0.75, 0.55, 0.3 }, { 0.55, 0.4, 0.2 } }, 70, 60)
            end,
        },
        { trigger = "onWaveStart", effect = function(ctx) ItemFx.state(ctx.player, "cicada_shell").used = 0 end },
    },
    tags = { "defense", "healing", "bug" },
}
