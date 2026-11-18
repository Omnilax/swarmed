-- Execute (RoR Old Guillotine): weak ants are simply swallowed.
return {
    name = "Amoeba",
    description = "Hitting an ant below 10% health (+4% per stack) engulfs it outright. Not bosses.",
    rarity = "uncommon",
    category = "elemental",
    size = { 1, 1 },
    procs = {
        {
            trigger = "onHit",
            effect = function(ctx, stacks)
                local e = ctx.target
                if e.dead or e.def.boss or e.hp > e.maxHp * (0.06 + 0.04 * stacks) then return end
                e.hp = 0
                require("src.game.combat").damage(ctx.world, e, 1, { noCrit = true, procDepth = ctx.procDepth + 1 })
                ctx.world.particles:burst(e.x, e.y, 6, { { 0.7, 0.85, 0.9 }, { 0.5, 0.65, 0.75 } }, 40, 30)
            end,
        },
    },
    tags = { "offense", "proc", "microbe" },
}
