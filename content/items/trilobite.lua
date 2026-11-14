-- Brotato-style conversion: armour turns into damage. Kept up as an "fx:" modifier.
local ItemFx = require("src.game.itemfx")

return {
    name = "Trilobite Fossil",
    description = "+8 Armor. Gain +1% Damage for every point of Armor you have (+1% per stack).",
    effect = "Gain +1% Damage for every point of Armor you have (+1% per stack).",
    rarity = "legendary",
    size = { 2, 2 },
    stats = { armor = 8 },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                local p, s = ctx.player, ItemFx.state(ctx.player, "trilobite")
                local want = math.max(0, math.floor(p.stats:get("armor"))) * stacks
                if want == s.bonus then return end
                s.bonus = want
                p.stats:removeSource("fx:trilobite")
                p.stats:addModifier("fx:trilobite", "damage", want, 0)
            end,
        },
    },
    tags = { "offense", "defense" },
}
