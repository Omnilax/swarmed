-- Molted from Venus Flytrap + Slime Mold (content/molts/devouring_bloom.lua).
local Combat = require("src.game.combat")
local ItemFx = require("src.game.itemfx")

return {
    name = "Devouring Bloom",
    description = "Every 2 seconds the bloom snaps at the 2 nearest ants (+1 per stack) within reach for 40 damage (+40 per stack), healing 3 HP for each.",
    rarity = "molted",
    shape = { "X.X", "XXX" },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                if not ItemFx.every(ctx, "devouring_bloom", 2) then return end
                local w, p = ctx.world, ctx.player
                local list = Combat.collect(w, p.x, p.y, 110)
                table.sort(list, function(a, b) return (a.x - p.x) ^ 2 + (a.y - p.y) ^ 2 < (b.x - p.x) ^ 2 + (b.y - p.y) ^ 2 end)
                for i = 1, math.min(#list, 1 + stacks) do
                    local e = list[i]
                    w:addFx({ kind = "bolt", x = p.x, y = p.y, x2 = e.x, y2 = e.y, life = 0.3, color = { 0.6, 1, 0.35 } })
                    w:addFx({ kind = "ring", x = e.x, y = e.y, r = 12, life = 0.25, color = { 0.6, 1, 0.35 } })
                    Combat.damage(w, e, 40 * stacks, { procDepth = 1, slow = { 0.35, 2 } })
                    p:heal(3)
                end
            end,
        },
    },
    tags = { "offense", "healing", "plant" },
}
