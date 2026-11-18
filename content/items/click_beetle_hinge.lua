-- Click beetles snap their hinge to flip: the first hit after a dash lands with that snap.
local ItemFx = require("src.game.itemfx")

return {
    name = "Click Beetle Hinge",
    description = "The first hit within 1 second of a dash snaps for an extra 150% damage (+100% per stack).",
    rarity = "uncommon",
    category = "attack",
    size = { 1, 1 },
    procs = {
        { trigger = "onDash", effect = function(ctx) ItemFx.state(ctx.player, "click_beetle_hinge").armed = ctx.world.time + 1 end },
        {
            trigger = "onHit",
            effect = function(ctx, stacks)
                local s = ItemFx.state(ctx.player, "click_beetle_hinge")
                if not s.armed or ctx.world.time > s.armed or ctx.target.dead then return end
                s.armed = nil
                local Combat = require("src.game.combat")
                Combat.damage(ctx.world, ctx.target, ctx.damage * (0.5 + stacks), { coefficient = ItemFx.unscaled(ctx.player),
                    noCrit = true, procDepth = ctx.procDepth + 1 })
                ctx.world:floatText(ctx.x, ctx.y, "CLICK!", { 1, 0.9, 0.5 }, false)
            end,
        },
    },
    tags = { "offense", "proc", "bug" },
}
