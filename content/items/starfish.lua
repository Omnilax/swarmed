-- Lose an arm, grow one back. Shore item.
local ItemFx = require("src.game.itemfx")

return {
    name = "Starfish",
    description = "+12 Max HP. Every 5th kill heals 1 HP (+1 per stack). Once per wave, losing half your HP in one wave regrows 15% of Max HP. Crustaceans: +6 Max HP more.",
    effect = "Every 5th kill heals 1 HP (+1 per stack). Once per wave, losing half your HP in one wave regrows 15% of Max HP.",
    rarity = "rare",
    category = "mend",
    shape = { ".X.", "XXX", "X.X" },
    stats = { maxHp = 12 },
    kin = { tags = { "crustacean" }, stats = { maxHp = 6 } },
    procs = {
        {
            trigger = "onKill",
            effect = function(ctx, stacks)
                local s = ItemFx.state(ctx.player, "starfish")
                s.kills = (s.kills or 0) + 1
                if s.kills >= 5 then s.kills = 0; ctx.player:heal(stacks) end
            end,
        },
        {
            trigger = "onHurt",
            effect = function(ctx)
                local p, s = ctx.player, ItemFx.state(ctx.player, "starfish")
                local maxHp = p.stats:get("maxHp")
                s.lost = (s.lost or 0) + (ctx.damage or 0)
                if s.regrown or p.hp <= 0 or s.lost < maxHp * 0.5 then return end
                s.regrown = true
                p:heal(maxHp * 0.15)
                ctx.world:floatText(p.x, p.y, "REGROW", { 1, 0.6, 0.45 }, true)
            end,
        },
        { trigger = "onWaveStart", effect = function(ctx) local s = ItemFx.state(ctx.player, "starfish"); s.lost, s.regrown = 0, false end },
    },
    tags = { "healing", "shore" },
}
