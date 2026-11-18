-- Insects (mantises, roaches, true bugs, dragonflies...): six quick legs, compound eyes, wings.
local fx = require("src.game.skills").fx

local LEAF = { 0.65, 0.95, 0.45 }

return {
    name = "Insect Kin",
    blurb = "Six legs, compound eyes and quick wings",
    color = LEAF,
    tags = { "insect" },
    priority = 10,
    nodes = {
        { id = "kin_insect_chitin", tier = 1, ranks = 2, name = "Chitin", desc = "+8 max HP and +1 armor per rank.",
          stats = { maxHp = 8, armor = 1 } },
        { id = "kin_insect_wings", tier = 2, col = -1, name = "Quick Wings", desc = "Your dash recharges 0.15 s faster.",
          stats = { dashCooldown = -0.15 } },
        { id = "kin_insect_jaws", tier = 2, col = 1, name = "Strong Mouthparts", desc = "+8% damage.",
          stats = { damage = 8 } },
        { id = "kin_insect_eyes", tier = 3, name = "Compound Eyes", desc = "+5% crit chance and +5% dodge.",
          stats = { critChance = 5, dodge = 5 } },
        { id = "kin_insect_adrenal", tier = 4, col = -1, name = "Startle Reflex", desc = "Getting hit gives +30% speed for 3 s (every 5 s).",
          procs = { { trigger = "onHurt", cooldown = 5, effect = function(ctx)
              fx.buff(ctx, "kin_insect_adrenal", "moveSpeed", 0, 0.3, 3)
          end } } },
        { id = "kin_insect_scavenge", tier = 4, col = 1, name = "Scavenger", desc = "Kills have a 6% chance to heal 3 HP.",
          procs = { { trigger = "onKill", chance = 0.06, effect = function(ctx) fx.heal(ctx, 3) end } } },
    },
}
