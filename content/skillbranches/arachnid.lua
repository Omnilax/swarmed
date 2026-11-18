-- Other arachnids (scorpions, whip scorpions, vinegaroons, camel spiders): desert-hard bodies,
-- patient hunters that strike hardest when cornered.
local fx = require("src.game.skills").fx

local DUSK = { 0.85, 0.7, 1 }

return {
    name = "Arachnid Kin",
    blurb = "Desert-hard and deadliest when cornered",
    color = DUSK,
    tags = { "arachnid" },
    priority = 20,
    nodes = {
        { id = "kin_arach_cuticle", tier = 1, ranks = 2, name = "Waxy Cuticle", desc = "+8 max HP and +0.3 HP regen per rank.",
          stats = { maxHp = 8, hpRegen = 0.3 } },
        { id = "kin_arach_pectines", tier = 2, col = -1, name = "Ground Sense", desc = "+8% speed and +5% dodge.",
          stats = { dodge = 5 }, statsMult = { moveSpeed = 0.08 } },
        { id = "kin_arach_venom", tier = 2, col = 1, name = "Venom Gland", desc = "Hits have a 15% chance to poison the ant (6/s for 3 s).",
          procs = { { trigger = "onHit", chance = 0.15, effect = function(ctx)
              if ctx.target then fx.poison(ctx.target, 6, 3) end
          end } } },
        { id = "kin_arach_patient", tier = 3, name = "Patient Hunter", desc = "+6% crit chance and +20% crit damage.",
          stats = { critChance = 6, critDamage = 20 } },
        { id = "kin_arach_cornered", tier = 4, col = -1, name = "Cornered", desc = "Below 40% HP, getting hit gives +35% damage for 4 s.",
          procs = { { trigger = "onHurt", cooldown = 4,
              condition = function(ctx) local p = ctx.player return p.hp < p.stats:get("maxHp") * 0.4 end,
              effect = function(ctx)
                  fx.buff(ctx, "kin_arach_cornered", "damage", 35, 0, 4)
                  fx.say(ctx, "CORNERED!", { 1, 0.5, 0.4 })
              end } } },
        { id = "kin_arach_glow", tier = 4, col = 1, name = "Moonlight Glow", desc = "Kills have a 10% chance to flash, dazing the ants nearby.",
          procs = { { trigger = "onKill", chance = 0.1, effect = function(ctx)
              fx.nova(ctx, ctx.x, ctx.y, 34, 3, { 0.5, 0.95, 1 }, { slow = { 0.2, 1 }, knockback = 30 })
          end } } },
    },
}
