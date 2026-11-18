-- A truffle: rare, buried, and worth its weight in nectar.
return {
    name = "Truffle",
    description = "Elites and queens drop 6 extra nectar when they die (+6 per stack).",
    effect = "Elites and queens drop 6 extra nectar when they die (+6 per stack).",
    rarity = "uncommon",
    category = "fortune",
    size = { 1, 1 },
    procs = {
        {
            trigger = "onKill",
            effect = function(ctx, stacks)
                local e = ctx.target
                if not e or not (e.elite or e.def.boss or e.def.queen) then return end
                ctx.world:dropNectar(e.x, e.y, 6 * stacks)
            end,
        },
    },
    tags = { "utility", "fungus" },
}
