-- Parasite (src/game/parasites.lua). A tick latched on: it shares every drop it drinks from
-- the ants, and it never stops drinking from you.
local Parasites = require("src.game.parasites")

return {
    name = "Deer Tick",
    description = "Bloodsucker: every hit heals you 6% of the damage it does. +20% Damage. Devours Leeches and Mosquito Proboscises in your bag (+10% Damage each).",
    effect = "Hits heal 6% of the damage dealt.",
    curse = "Drains 1.5 HP/s in waves. No regen.",
    rarity = "parasite", category = "cursed", parasite = true,
    size = { 1, 1 },
    stats = { damage = 20 },
    statsMult = { hpRegen = -1 },
    feeds = { ids = { "leech", "mosquito_proboscis" }, stats = { damage = 10 } },
    procs = {
        { trigger = "onHit", effect = function(ctx) ctx.player:heal((ctx.damage or 0) * 0.06) end },
        {
            trigger = "onTick",
            effect = function(ctx)
                if Parasites.live(ctx.world) then Parasites.drain(ctx.player, 1.5 * ctx.dt) end
            end,
        },
    },
    tags = { "healing" },
}
