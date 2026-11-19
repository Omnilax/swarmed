-- Spiders: eight eyes, venom in the fangs, and a silk line for every emergency.
local fx = require("src.game.skills").fx

local SILK = { 0.85, 0.95, 1 }

return {
    name = "Spider Kin",
    blurb = "Eight eyes, venom and safety silk",
    color = { 0.7, 0.9, 0.85 },
    tags = { "spider" },
    priority = 30,
    nodes = {
        { id = "kin_spider_eyes", tier = 1, ranks = 2, name = "Eight Eyes", desc = "+4% crit chance and +10 pickup range per rank.",
          stats = { critChance = 4, pickupRange = 10 } },
        { id = "kin_spider_silk", tier = 2, col = -1, name = "Safety Silk", desc = "Getting hit spins a web around you that holds the ants back (every 5 s).",
          procs = { { trigger = "onHurt", cooldown = 5, effect = function(ctx)
              local p = ctx.player
              fx.web(ctx, p.x, p.y, 46, 3.5, 0.3)
          end } } },
        { id = "kin_spider_fangs", tier = 2, col = 1, name = "Venom Fangs", desc = "Hits have a 20% chance to poison the ant (5/s for 3 s).",
          procs = { { trigger = "onHit", chance = 0.2, effect = function(ctx)
              if ctx.target then fx.poison(ctx.target, 5, 3) end
          end } } },
        { id = "kin_spider_tremor", tier = 3, name = "Tremor Sense", desc = "Feel every footstep: +8% dodge and +5% attack speed.",
          stats = { dodge = 8, attackSpeed = 5 } },
        { id = "kin_spider_ambush", tier = 4, col = -1, name = "Ambusher", desc = "After a dash, +30% damage for 2 s.",
          procs = { { trigger = "onDashEnd", effect = function(ctx)
              fx.buff(ctx, "kin_spider_ambush", "damage", 30, 0, 2)
          end } } },
        { id = "kin_spider_wrap", tier = 4, col = 1, name = "Silk Wrap", desc = "Kills have a 15% chance to leave a sticky web where the ant fell.",
          procs = { { trigger = "onKill", chance = 0.15, effect = function(ctx)
              fx.web(ctx, ctx.x, ctx.y, 28, 2.5, 0.35)
          end } } },
    },
}
