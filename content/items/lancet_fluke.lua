-- Parasite (src/game/parasites.lua). The fluke that makes ants climb grass stems and wait to
-- be eaten. You carry it now: every ant that bites you catches it and wanders off in a daze.
-- You're a herder now, not a fighter.
local Parasites = require("src.game.parasites")

return {
    name = "Lancet Fluke",
    description = "Ants that bite you catch it: they freeze in a daze for 3 s and take +40% damage meanwhile. Devours Snail Shells in your bag (+2 Armor each).",
    effect = "Biters freeze and take +40% damage.",
    curse = "-35% Damage.",
    rarity = "parasite", category = "cursed", parasite = true,
    size = { 1, 1 },
    stats = { damage = -35 },
    feeds = { ids = { "snail_shell" }, stats = { armor = 2 } },
    procs = {
        {
            trigger = "onHurt",
            effect = function(ctx)
                local e = ctx.source
                if type(e) ~= "table" or not e.def or e.dead or not e.hp or e.isProp then return end
                if e.def.boss or e.def.noStun then return end
                e.stunT = math.max(e.stunT or 0, 3)
                e.corrodeT, e.corrodeMul = math.max(e.corrodeT or 0, 3), math.max(e.corrodeMul or 1, 1.4)
                ctx.world.particles:burst(e.x, e.y, 4, { { 0.6, 0.9, 1 } }, 30, 40)
            end,
        },
    },
    tags = { "control" },
}
