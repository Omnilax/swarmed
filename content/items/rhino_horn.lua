-- Dash gore: every ant touched during a dash is hit once, hard, and tossed aside.
local Combat = require("src.game.combat")
local ItemFx = require("src.game.itemfx")
local util = require("src.core.util")

return {
    name = "Rhino Horn",
    description = "+15% Knockback. While dashing you gore every ant you touch for 15 damage (+15 per stack) and fling it away.",
    effect = "While dashing you gore every ant you touch for 15 damage (+15 per stack) and fling it away.",
    rarity = "rare",
    shape = { "X.", "XX" },
    stats = { knockback = 15 },
    procs = {
        { trigger = "onDash", effect = function(ctx) ItemFx.state(ctx.player, "rhino_horn").hit = {} end },
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                local p = ctx.player
                if p.dashT <= 0 then return end
                local s = ItemFx.state(p, "rhino_horn")
                s.hit = s.hit or {}
                for _, e in ipairs(Combat.collect(ctx.world, p.x, p.y, p.radius + 4)) do
                    if not s.hit[e.uid] then
                        s.hit[e.uid] = true
                        local nx, ny = util.normalize(e.x - p.x, e.y - p.y)
                        Combat.damage(ctx.world, e, 15 * stacks, { knockback = 220, kbx = nx, kby = ny, procDepth = 1 })
                    end
                end
            end,
        },
    },
    tags = { "offense", "mobility", "bug" },
}
