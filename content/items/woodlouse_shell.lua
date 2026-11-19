return {
    name = "Woodlouse Shell",
    description = "+5 Armor. After a dash you stay rolled up and untouchable for 0.3 seconds more (+0.3 per stack).",
    effect = "After a dash you stay rolled up and untouchable for 0.3 seconds more (+0.3 per stack).",
    rarity = "uncommon",
    category = "guard",
    shape = { "XXX" },
    stats = { armor = 5 },
    procs = {
        {
            trigger = "onDash",
            effect = function(ctx, stacks)
                local p = ctx.player
                p.iframes = math.max(p.iframes, math.max(0, p.dashT) + 0.3 * stacks)
            end,
        },
    },
    tags = { "defense", "bug" },
}
