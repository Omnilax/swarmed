-- A pill bug's back plates: when things go wrong, it rolls into a ball.
local ItemFx = require("src.game.itemfx")

return {
    name = "Pill Bug Plates",
    description = "+5 Armor. Once per wave (+1 per stack), dropping under 30% HP curls you up: you take 70% less damage for 3 seconds.",
    effect = "Once per wave (+1 per stack), dropping under 30% HP curls you up: you take 70% less damage for 3 seconds.",
    rarity = "rare",
    category = "guard",
    size = { 2, 2 },
    stats = { armor = 5 },
    procs = {
        {
            trigger = "onHurt",
            effect = function(ctx, stacks)
                local p = ctx.player
                local s = ItemFx.state(p, "pill_bug_plates")
                if p.hp <= 0 or (s.used or 0) >= stacks then return end
                if p.hp > p.stats:get("maxHp") * 0.3 then return end
                s.used = (s.used or 0) + 1
                ItemFx.guard(p, 0.3, 3)
                ctx.world:floatText(p.x, p.y - 12, "CURLED UP", { 0.7, 0.8, 0.95 })
                ctx.world:addFx({ kind = "ring", x = p.x, y = p.y, r = 22, life = 0.4, color = { 0.65, 0.75, 0.9 } })
            end,
        },
        { trigger = "onWaveStart", effect = function(ctx) ItemFx.state(ctx.player, "pill_bug_plates").used = 0 end },
    },
    tags = { "defense", "bug" },
}
