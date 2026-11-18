-- Parasite (src/game/parasites.lua). The one that makes mice love cats: you stop fearing the
-- swarm. The more ants around you, the harder you hit and the tougher you get; but the ants
-- get faster and you can barely walk away from them.
local Parasites = require("src.game.parasites")
local ItemFx = require("src.game.itemfx")
local util = require("src.core.util")

return {
    name = "Toxoplasma",
    description = "Fearless: +5% Damage and +1 Armor for every ant within reach (up to +100% / +20).",
    effect = "+5% Dmg, +1 Armor per ant near you.",
    curse = "Ants 20% faster. Fleeing them is slow.",
    rarity = "parasite", category = "cursed", parasite = true,
    size = { 1, 1 },
    enemySpeed = 0.2,
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx)
                local p = ctx.player
                if not ItemFx.every(ctx, "toxoplasma", 0.25) then return end
                local cx, cy, n = Parasites.crowd(ctx.world, p.x, p.y, 90)
                local s = ItemFx.state(p, "toxoplasma")
                s.cx, s.cy = cx, cy
                n = math.min(20, n)
                if n ~= s.n then
                    s.n = n
                    Parasites.setStats(p, "toxoplasma", { damage = 5 * n, armor = n })
                end
            end,
        },
    },
    steer = function(p, wx, wy, mag, dt)
        local s = ItemFx.state(p, "toxoplasma")
        if s.cx and mag > 0.05 then
            local dx, dy = util.normalize(s.cx - p.x, s.cy - p.y)
            if wx * dx + wy * dy < -0.2 then mag = mag * 0.6 end
        end
        return wx, wy, mag
    end,
    tags = { "offense", "defense" },
}
