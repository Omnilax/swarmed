-- Brotato-style ramp: the longer a wave goes, the harder you hit.
local ItemFx = require("src.game.itemfx")

return {
    name = "Mycelium Thread",
    description = "Every kill gives +1% Damage until the wave ends, up to 25% (+25% per stack).",
    rarity = "rare",
    category = "attack",
    size = { 1, 4 },
    procs = {
        {
            trigger = "onKill",
            effect = function(ctx, stacks)
                local s = ItemFx.state(ctx.player, "mycelium")
                local n = math.min(25 * stacks, (s.n or 0) + 1)
                if n == s.n then return end
                s.n = n
                ctx.player.stats:removeSource("fx:mycelium")
                ctx.player.stats:addModifier("fx:mycelium", "damage", n, 0)
            end,
        },
        {
            trigger = "onWaveStart",
            effect = function(ctx)
                ItemFx.state(ctx.player, "mycelium").n = 0
                ctx.player.stats:removeSource("fx:mycelium")
            end,
        },
    },
    tags = { "offense", "fungus" },
}
