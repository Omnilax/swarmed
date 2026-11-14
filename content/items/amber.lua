-- Time held still, like the gnat stuck inside it.
local Combat = require("src.game.combat")
local ItemFx = require("src.game.itemfx")

return {
    name = "Amber",
    description = "Every 10 seconds, every ant near you is sealed in resin, frozen for 1.5 seconds (+0.5 per stack).",
    rarity = "legendary",
    size = { 2, 1 },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                if not ItemFx.every(ctx, "amber", 10) then return end
                local w, p = ctx.world, ctx.player
                local t = 1 + 0.5 * stacks
                for _, e in ipairs(Combat.collect(w, p.x, p.y, 90)) do
                    e.slowT, e.slowMul = math.max(e.slowT, t), 0
                    e.kvx, e.kvy = 0, 0
                    e.flash = 0.1
                end
                w:addFx({ kind = "ring", x = p.x, y = p.y, r = 90, life = 0.6, color = { 1, 0.7, 0.2 } })
                w.camera:shake(0.1)
            end,
        },
    },
    tags = { "utility" },
}
