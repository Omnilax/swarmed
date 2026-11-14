-- Parasite: infested ants rot from the inside, and when one dies the worms spill into its neighbours.
local Combat = require("src.game.combat")

return {
    name = "Nematode",
    description = "Hits have a 15% chance to infest the ant (4 damage a second, +4 per stack). Infested ants that die spread worms to 2 (+1 per stack) more.",
    rarity = "uncommon",
    size = { 1, 2 },
    procs = {
        {
            trigger = "onHit",
            chance = 0.15,
            effect = function(ctx, stacks)
                local e = ctx.target
                if e.dead then return end
                e.poisonT, e.poisonDps = math.max(e.poisonT, 4), math.max(e.poisonDps, 4 * stacks)
                e.nemaUid = e.uid
            end,
        },
        {
            trigger = "onKill",
            effect = function(ctx, stacks)
                local e = ctx.target
                if e.nemaUid ~= e.uid then return end
                e.nemaUid = nil
                Combat.chain(ctx.world, e, 1 + stacks, 60, 2 * stacks, { procDepth = ctx.procDepth + 1, noCrit = true,
                    poison = { 4 * stacks, 4 }, color = { 0.95, 0.85, 0.75 } })
            end,
        },
    },
    tags = { "poison", "proc", "microbe" },
}
