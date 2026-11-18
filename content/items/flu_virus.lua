-- Parasite (src/game/parasites.lua). A fever: you hit twice as hard and fall twice as fast,
-- and every few seconds a sneeze blasts the ants back and stops you in your tracks.
local Combat = require("src.game.combat")
local Parasites = require("src.game.parasites")
local ItemFx = require("src.game.itemfx")

local COL = { 0.75, 0.95, 0.8 }

return {
    name = "Flu",
    description = "Fever: double damage (+100%). Every 7 s you sneeze: a blast that flings nearby ants away.",
    curse = "Half Max HP. Sneezes stop you.",
    rarity = "parasite", category = "cursed", parasite = true,
    size = { 1, 1 },
    stats = { damage = 100 },
    statsMult = { maxHp = -0.5 },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx)
                local p, w = ctx.player, ctx.world
                if not Parasites.live(w) then return end
                if ItemFx.every(ctx, "flu_virus", 7) then
                    local r = 70 * (1 + p.stats:get("area") / 100)
                    Combat.area(w, p.x, p.y, r, 4, { knockback = 320, procDepth = 1 })
                    w:addFx({ kind = "ring", x = p.x, y = p.y, r = r, life = 0.3, color = COL })
                    w.particles:burst(p.x + p.aimX * 8, p.y + p.aimY * 8, 14, { COL, { 1, 1, 1 } }, 120, 40, { grav = 40 })
                    w:floatText(p.x, p.y - 16, "ACHOO!", COL, false)
                    p:stun(0.3)
                end
            end,
        },
    },
    tags = { "offense" },
}
