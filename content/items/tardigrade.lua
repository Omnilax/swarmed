-- Cryptobiosis: a hit that would kill you leaves you at 1 HP instead (RoR Dio's / Isaac lives).
-- onHurt runs before the death check in Player:hurt, so lifting hp above 0 here saves the run.
local ItemFx = require("src.game.itemfx")

return {
    name = "Tardigrade",
    description = "+10 Max HP. Once per wave (+1 per stack), a killing bite leaves you at 1 HP, curled up and untouchable for 2 seconds.",
    effect = "Once per wave (+1 per stack), a killing bite leaves you at 1 HP, curled up and untouchable for 2 seconds.",
    rarity = "legendary",
    size = { 1, 1 },
    stats = { maxHp = 10 },
    procs = {
        {
            trigger = "onHurt",
            effect = function(ctx, stacks)
                local p, s = ctx.player, ItemFx.state(ctx.player, "tardigrade")
                if p.hp > 0 or (s.used or 0) >= stacks then return end
                s.used = (s.used or 0) + 1
                p.hp, p.iframes = 1, 2
                ctx.world:floatText(p.x, p.y, "CRYPTOBIOSIS", { 0.75, 0.95, 1 }, true)
                ctx.world:addFx({ kind = "ring", x = p.x, y = p.y, r = 40, life = 0.5, color = { 0.7, 0.9, 1 } })
            end,
        },
        { trigger = "onWaveStart", effect = function(ctx) ItemFx.state(ctx.player, "tardigrade").used = 0 end },
    },
    tags = { "defense", "microbe" },
}
