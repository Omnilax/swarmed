-- Molted from Mycelium Thread + Cordyceps (content/molts/hivemind_spore.lua).
local Combat = require("src.game.combat")
local ItemFx = require("src.game.itemfx")

return {
    name = "Hivemind Spore",
    description = "Every kill gives +1.5% Damage until the wave ends, up to 40% (+40% per stack), and bursts into spores that poison ants nearby for 8 damage a second (+8 per stack).",
    rarity = "molted",
    category = "elemental",
    size = { 1, 3 },
    procs = {
        {
            trigger = "onKill",
            effect = function(ctx, stacks)
                local s = ItemFx.state(ctx.player, "hivemind_spore")
                local n = math.min(40 * stacks, (s.n or 0) + 1.5)
                if n ~= s.n then
                    s.n = n
                    ctx.player.stats:removeSource("fx:hivemind_spore")
                    ctx.player.stats:addModifier("fx:hivemind_spore", "damage", n, 0)
                end
                local w = ctx.world
                local r = (ctx.target and (ctx.target.poisonT or 0) > 0) and 55 or 32
                for _, o in ipairs(Combat.collect(w, ctx.x, ctx.y, r)) do
                    o.poisonT, o.poisonDps = math.max(o.poisonT, 3), math.max(o.poisonDps, 8 * stacks)
                end
                w.particles:burst(ctx.x, ctx.y, 4, { { 1, 0.65, 0.25 }, { 0.9, 0.85, 0.6 } }, 40, 30, { glow = true, grav = -20 })
            end,
        },
        {
            trigger = "onWaveStart",
            effect = function(ctx)
                ItemFx.state(ctx.player, "hivemind_spore").n = 0
                ctx.player.stats:removeSource("fx:hivemind_spore")
            end,
        },
    },
    tags = { "offense", "poison", "fungus" },
}
