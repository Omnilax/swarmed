-- It grows a layer for every wave you keep it. Shore item.
local ItemFx = require("src.game.itemfx")

return {
    name = "Pearl",
    description = "+5 Luck. Grows with every wave you hold it: +2% Damage and +1 Armor per wave, up to 10 waves (doubled per stack). Crustaceans: +10% Damage from the start.",
    effect = "Grows with every wave you hold it: +2% Damage and +1 Armor per wave, up to 10 waves (doubled per stack).",
    rarity = "legendary",
    category = "attack",
    size = { 1, 1 },
    stats = { luck = 5 },
    kin = { tags = { "crustacean" }, stats = { damage = 10 } },
    procs = {
        {
            trigger = "onWaveStart",
            effect = function(ctx, stacks)
                local p, s = ctx.player, ItemFx.state(ctx.player, "pearl")
                s.waves = math.min(10, (s.waves or -1) + 1)     -- the wave it was picked up in counts from the next one
                p.stats:removeSource("fx:pearl")
                if s.waves > 0 then
                    p.stats:addModifier("fx:pearl", "damage", 2 * s.waves * stacks, 0)
                    p.stats:addModifier("fx:pearl", "armor", s.waves * stacks, 0)
                end
            end,
        },
    },
    tags = { "offense", "defense", "shore" },
}
