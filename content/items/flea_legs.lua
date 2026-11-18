-- A flea's spring-loaded hind legs: dashes fly farther and land with a thump.
local Combat = require("src.game.combat")

return {
    name = "Flea Legs",
    description = "+12 Speed. Dashes go 30% farther (+10% per stack) and the landing shoves ants back for 6 damage.",
    effect = "Dashes go 30% farther (+10% per stack) and the landing shoves ants back for 6 damage.",
    rarity = "uncommon",
    category = "move",
    size = { 1, 2 },
    stats = { moveSpeed = 12 },
    procs = {
        {
            trigger = "onDash",
            effect = function(ctx, stacks)
                local p = ctx.player
                if (p.dashT or 0) <= 0 then return end
                p.dashT = p.dashT * (1.2 + 0.1 * stacks)
                p:after(p.dashT, function()
                    local w = p.world
                    local r = 26 * (1 + p.stats:get("area") / 100)
                    Combat.area(w, p.x, p.y, r, 6, { knockback = 140, procDepth = 1 })
                    w:addFx({ kind = "ring", x = p.x, y = p.y, r = r, life = 0.25, color = { 0.85, 0.7, 0.5 } })
                end)
            end,
        },
    },
    tags = { "mobility", "bug" },
}
