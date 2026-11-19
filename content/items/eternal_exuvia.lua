-- Molted from Cicada Shell + Tardigrade (content/molts/eternal_exuvia.lua).
local ItemFx = require("src.game.itemfx")

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 0.75, 0.6, 0.35 }
local PFX_2 = { 0.6, 1, 0.85 }
local PFX_LIST_1 = { PFX_1, PFX_2 }

return {
    name = "Eternal Exuvia",
    description = "+12 Armor, +20 Max HP. Twice per wave (+1 per stack), a killing bite leaves you on 40% HP, untouchable for 2.5 seconds.",
    effect = "Twice per wave (+1 per stack), a killing bite leaves you on 40% HP, untouchable for 2.5 seconds.",
    rarity = "molted",
    category = "mend",
    size = { 2, 2 },
    stats = { armor = 12, maxHp = 20 },
    procs = {
        {
            trigger = "onHurt",
            effect = function(ctx, stacks)
                local p, s = ctx.player, ItemFx.state(ctx.player, "eternal_exuvia")
                if p.hp > 0 or (s.used or 0) >= 1 + stacks then return end
                s.used = (s.used or 0) + 1
                p.hp = math.max(1, p.stats:get("maxHp") * 0.4)
                p.iframes = math.max(p.iframes, 2.5)
                ctx.world:floatText(p.x, p.y, "SHED!", { 0.5, 1, 0.85 }, true)
                ctx.world:addFx({ kind = "ring", x = p.x, y = p.y, r = 44, life = 0.5, color = { 0.5, 1, 0.85 } })
                ctx.world.particles:burst(p.x, p.y, 16, PFX_LIST_1, 80, 60)
            end,
        },
        { trigger = "onWaveStart", effect = function(ctx) ItemFx.state(ctx.player, "eternal_exuvia").used = 0 end },
    },
    tags = { "defense", "healing", "bug" },
}
