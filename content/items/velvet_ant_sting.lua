-- The velvet ant is a wasp in a fur coat, with one of the most painful stings there is.
return {
    name = "Velvet Ant Sting",
    description = "Crits poison the ant for 6 damage a second (+4 per stack) for 3 seconds. Poisoned ants take 15% more damage from everything (+15% per stack).",
    effect = "Crits poison the ant for 6 damage a second (+4 per stack) for 3 seconds. Poisoned ants take 15% more damage from everything (+15% per stack).",
    rarity = "rare",
    category = "elemental",
    size = { 1, 2 },
    stats = { critChance = 4 },
    poisonAmp = 0.15,    -- src/game/combat.lua Combat.damage
    procs = {
        {
            trigger = "onHit",
            effect = function(ctx, stacks)
                local e = ctx.target
                if not ctx.crit or e.dead then return end
                e.poisonT = math.max(e.poisonT, 3)
                e.poisonDps = math.max(e.poisonDps, 2 + 4 * stacks)
            end,
        },
    },
    tags = { "poison", "proc", "bug" },
}
