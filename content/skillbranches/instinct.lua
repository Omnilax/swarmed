-- The fallback kin branch for a bug with no lineage tags: plain survival instinct.
local fx = require("src.game.skills").fx

return {
    name = "Instinct",
    blurb = "Plain, stubborn survival",
    color = { 0.9, 0.85, 0.7 },
    tags = {},
    priority = -100,
    nodes = {
        { id = "kin_any_tough", tier = 1, ranks = 2, name = "Tough", desc = "+10 max HP per rank.",
          stats = { maxHp = 10 } },
        { id = "kin_any_quick", tier = 2, col = -1, name = "Quick", desc = "+8% speed.",
          statsMult = { moveSpeed = 0.08 } },
        { id = "kin_any_fierce", tier = 2, col = 1, name = "Fierce", desc = "+8% damage.",
          stats = { damage = 8 } },
        { id = "kin_any_lucky", tier = 3, name = "Lucky", desc = "+15% luck.",
          stats = { luck = 15 } },
        { id = "kin_any_hardy", tier = 4, col = -1, name = "Hardy", desc = "+3 armor.",
          stats = { armor = 3 } },
        { id = "kin_any_hungry", tier = 4, col = 1, name = "Hungry", desc = "Kills have a 6% chance to heal 3 HP.",
          procs = { { trigger = "onKill", chance = 0.06, effect = function(ctx) fx.heal(ctx, 3) end } } },
    },
}
