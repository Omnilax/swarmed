-- A smear of snail slime: you glide along it, ants skid in it.
local ItemFx = require("src.game.itemfx")

return {
    name = "Snail Slime",
    description = "You leave a slime trail. On it you move 20% faster (+10% per stack); ants on it slip, slowed by 30%.",
    effect = "You leave a slime trail. On it you move 20% faster (+10% per stack); ants on it slip, slowed by 30%.",
    rarity = "uncommon",
    category = "move",
    size = { 2, 1 },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx, stacks)
                local w, p = ctx.world, ctx.player
                if ItemFx.every(ctx, "snail_slime", 0.15) then
                    local s = ItemFx.state(p, "snail_slime")
                    local dx, dy = p.x - (s.x or 0), p.y - (s.y or 0)
                    if dx * dx + dy * dy > 36 then
                        s.x, s.y = p.x, p.y
                        ItemFx.trail(w, "snail_slime", p.x, p.y, { r = 9, life = 3.5, slow = 0.7, color = { 0.62, 0.78, 0.86 }, max = 28 })
                    end
                end
                if ItemFx.onTrail(w, "snail_slime", p.x, p.y) then
                    ItemFx.buff(p, "snail_slime", "moveSpeed", 0, 0.1 + 0.1 * stacks, 0.3)
                end
            end,
        },
    },
    tags = { "mobility", "utility" },
}
