-- Blow it and the whole beach hears. Shore item.
local Combat = require("src.game.combat")
local ItemFx = require("src.game.itemfx")

local RING = { 0.98, 0.86, 0.74 }

return {
    name = "Conch Shell",
    description = "+8% Area. Every 7 seconds the conch sounds: a ring of sound knocks back ants within 70 and deals 10 damage (+10 per stack). Crustaceans: +8% Area more.",
    effect = "Every 7 seconds the conch sounds: a ring of sound knocks back ants within 70 and deals 10 damage (+10 per stack).",
    rarity = "rare",
    category = "control",
    size = { 2, 2 },
    stats = { area = 8 },
    kin = { tags = { "crustacean" }, stats = { area = 8 } },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                if not ItemFx.every(ctx, "conch_shell", 7) then return end
                local p, w = ctx.player, ctx.world
                local r = 70 * (1 + p.stats:get("area") / 100)
                Combat.area(w, p.x, p.y, r, 10 * stacks, { noCrit = true, procDepth = 1, knockback = 160, slow = { 0.6, 1.5 } })
                w:addFx({ kind = "ring", x = p.x, y = p.y, r = r, life = 0.35, color = RING })
                require("src.core.audio").play("bell", { pitch = 0.55, volume = 0.5 })
            end,
        },
    },
    tags = { "utility", "explosive", "shore" },
}
