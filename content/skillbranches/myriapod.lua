-- Centipedes and millipedes: more legs, more rings, and something nasty oozing from each one.
local fx = require("src.game.skills").fx

local TOXIC = { 0.7, 1, 0.4 }

return {
    name = "Myriapod Kin",
    blurb = "Ring after ring, leg after leg",
    color = TOXIC,
    tags = { "myriapod" },
    priority = 30,
    nodes = {
        { id = "kin_myria_rings", tier = 1, ranks = 2, name = "More Rings", desc = "+10 max HP and +4% speed per rank.",
          stats = { maxHp = 10 }, statsMult = { moveSpeed = 0.04 } },
        { id = "kin_myria_antennae", tier = 2, col = -1, name = "Long Antennae", desc = "+20 pickup range and +4% dodge.",
          stats = { pickupRange = 20, dodge = 4 } },
        { id = "kin_myria_ooze", tier = 2, col = 1, name = "Defensive Ooze", desc = "Getting hit oozes a poison puddle under you (every 1.5 s).",
          procs = { { trigger = "onHurt", cooldown = 1.5, effect = function(ctx)
              local p = ctx.player
              fx.patch(ctx, p.x, p.y, 30, 2.5, 7, nil, TOXIC)
          end } } },
        { id = "kin_myria_rhythm", tier = 3, name = "Leg Rhythm", desc = "A hundred legs in step: +10% attack speed.",
          stats = { attackSpeed = 10 } },
        { id = "kin_myria_armour", tier = 4, col = -1, name = "Armoured Rings", desc = "+3 armor and +5% max HP.",
          stats = { armor = 3 }, statsMult = { maxHp = 0.05 } },
        { id = "kin_myria_trail", tier = 4, col = 1, name = "Toxic Footprints", desc = "You leave a faint trail of poison wherever you walk.",
          procs = { { trigger = "onTick", cooldown = 0.45,
              condition = function(ctx) return ctx.player.moving end,
              effect = function(ctx)
                  local p = ctx.player
                  fx.patch(ctx, p.x, p.y, 14, 1.6, 4, nil, TOXIC)
              end } } },
    },
}
