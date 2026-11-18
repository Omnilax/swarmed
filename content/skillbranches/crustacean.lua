-- Crustaceans: shells that grow back stronger, limbs that regrow, and the tide on their side.
local fx = require("src.game.skills").fx

local SEA = { 0.45, 0.8, 1 }

return {
    name = "Tidepool Kin",
    blurb = "Hard shells, regrown limbs and the tide",
    color = SEA,
    tags = { "crustacean" },
    priority = 30,
    nodes = {
        { id = "kin_crust_shell", tier = 1, ranks = 2, name = "Hard Shell", desc = "+2 armor and +6 max HP per rank.",
          stats = { armor = 2, maxHp = 6 } },
        { id = "kin_crust_regrow", tier = 2, col = -1, name = "Regrow Limbs", desc = "+0.6 HP regen.",
          stats = { hpRegen = 0.6 } },
        { id = "kin_crust_brine", tier = 2, col = 1, name = "Brine Spray", desc = "Every dash sprays salt water shards all around you.",
          procs = { { trigger = "onDash", effect = function(ctx)
              local p = ctx.player
              fx.shards(ctx, p.x, p.y, 6, 6, SEA, { range = 60 })
          end } } },
        { id = "kin_crust_molt", tier = 3, name = "Fresh Molt", desc = "Every wave starts with a fresh shell: heal 15% of your max HP.",
          procs = { { trigger = "onWaveStart", effect = function(ctx)
              local p = ctx.player
              fx.heal(ctx, p.stats:get("maxHp") * 0.15)
          end } } },
        { id = "kin_crust_bubbles", tier = 4, col = -1, name = "Bubble Net", desc = "Kills have a 12% chance to burst into bubbles that slow the ants around.",
          procs = { { trigger = "onKill", chance = 0.12, effect = function(ctx)
              fx.nova(ctx, ctx.x, ctx.y, 30, 4, SEA, { slow = { 0.4, 1.5 }, knockback = 20 })
          end } } },
        { id = "kin_crust_pinch", tier = 4, col = 1, name = "Counter Pinch", desc = "Getting hit snaps back at every ant touching you (every 2 s).",
          procs = { { trigger = "onHurt", cooldown = 2, effect = function(ctx)
              local p = ctx.player
              fx.nova(ctx, p.x, p.y, 32, 16, { 1, 0.6, 0.45 }, { knockback = 120 })
          end } } },
    },
}
