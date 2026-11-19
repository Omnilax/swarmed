-- Parasite (src/game/parasites.lua). A maggot growing under your shell: it gets bigger every
-- wave, and so does your strength. Every wave it chews a little more of you.
local Parasites = require("src.game.parasites")

local function apply(p)
    local it = Parasites.find(p.inventory, "botfly_larva")
    if not it then return end
    local n = it.level or 1
    Parasites.setStats(p, "botfly_larva", { damage = 12 * n, area = 8 * n })
end

return {
    name = "Botfly Larva",
    description = "It grows: +12% Damage and +8% Area for every wave you carry it (no cap).",
    effect = "+12% Dmg, +8% Area per wave carried.",
    curse = "Chews 12% Max HP every wave.",
    rarity = "parasite", category = "cursed", parasite = true,
    size = { 1, 1 },
    onAdd = function(p) apply(p) end,
    procs = {
        {
            trigger = "onWaveStart",
            effect = function(ctx)
                local p = ctx.player
                local it = Parasites.find(p.inventory, "botfly_larva")
                if not it then return end
                it.level = (it.level or 1) + 1
                apply(p)
                Parasites.drain(p, p.stats:get("maxHp") * 0.12)
                ctx.world:floatText(p.x, p.y - 16, "the larva grows: " .. it.level, { 1, 0.6, 0.55 }, false)
            end,
        },
    },
    tags = { "offense" },
}
