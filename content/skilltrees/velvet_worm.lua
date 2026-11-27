-- Velvet Worm: glue that holds the swarm, a soft body that poisons what bites it, and slowed
-- ants that burst when they die.
local fx = require("src.game.skills").fx

local GLUE = { 0.95, 0.88, 0.6 }

return {
    character = "velvet_worm",
    branches = {
        { name = "Slime", blurb = "Strings of glue that hold the swarm", color = GLUE, nodes = {
            { id = "vw_thick", tier = 1, ranks = 3, name = "Thick Slime", desc = "Slime strings slow ants 0.6 s longer per rank.",
              secondary = { ["slow.2"] = 0.6 } },
            { id = "vw_jets", tier = 2, name = "Third Jet", desc = "Squirt 3 strings instead of 2.",
              secondary = { jets = 1, gap = 0.04 } },
            { id = "vw_far", tier = 3, col = -1, name = "Long Strings", desc = "Strings fly 50% further.",
              secondary = { range = { mul = 0.5 } } },
            { id = "vw_quick", tier = 3, col = 1, name = "Quick Glands", desc = "Slime string recharges 30% faster.",
              secondary = { cooldown = { mul = -0.3 } } },
            { id = "vw_glue", tier = 4, name = "Superglue", desc = "Strings glue ants almost to a stop.",
              secondary = { ["slow.1"] = -0.2 } },
            { id = "vw_web", tier = 5, name = "Slime Net", desc = "Each string leaves a sticky puddle where it ends.",
              procs = { { trigger = "onSpecial", effect = function(ctx)
                  local p = ctx.player
                  local r = (ctx.params and ctx.params.range or 170) * 0.85
                  fx.web(ctx, p.x + ctx.ax * r, p.y + ctx.ay * r, 26, 4, 0.35)
              end } } },
        } },
        { name = "Soft Body", blurb = "Poison skin and a slow, steady mend", color = { 0.8, 0.45, 0.6 }, nodes = {
            { id = "vw_body", tier = 1, ranks = 3, name = "Velvet Skin", desc = "+12 max HP and +0.4 HP/s per rank.",
              stats = { maxHp = 12, hpRegen = 0.4 } },
            { id = "vw_toxic", tier = 2, name = "Toxic Slime", desc = "Ants that bite you take poison twice as strong.",
              procs = { { trigger = "onHurt", effect = function(ctx)
                  local p = ctx.player
                  for _, e in ipairs(require("src.game.combat").collect(ctx.world, p.x, p.y, 14)) do fx.poison(e, 8, 3) end
              end } } },
            { id = "vw_line", tier = 3, col = -1, name = "Long Line", desc = "The slime line reels you 30 further.",
              dash = { distance = 30 } },
            { id = "vw_mend", tier = 3, col = 1, name = "Mend", desc = "The slime line heals 4 more.",
              dash = { heal = 4 } },
            { id = "vw_spare", tier = 4, name = "Spare Gland", desc = "Store a second slime line.",
              dash = { charges = 1 } },
            { id = "vw_shed", tier = 5, name = "Slime Shed", desc = "Reeling back leaves a puddle of glue where you were.",
              procs = { { trigger = "onDash", effect = function(ctx)
                  local p = ctx.player
                  fx.web(ctx, p.x, p.y, 30, 4, 0.3)
              end } } },
        } },
        { name = "Burst", blurb = "Slowed ants pop", color = { 1, 0.6, 0.35 }, nodes = {
            { id = "vw_bite", tier = 1, ranks = 3, name = "Hidden Jaws", desc = "+15% bite damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "vw_pop", tier = 2, name = "Bigger Pop", desc = "Slowed ants burst for +8 damage.",
              procs = { { trigger = "onKill", effect = function(ctx)
                  local e = ctx.target
                  if e and (e.slowT or 0) > 0 then fx.nova(ctx, ctx.x, ctx.y, 30, 8, GLUE) end
              end } } },
            { id = "vw_sticky", tier = 3, col = -1, name = "Sticky Bite", desc = "Bites slow ants for 1.5 s.",
              procs = { { trigger = "onHit", move = "attack", effect = function(ctx)
                  if ctx.target then fx.slow(ctx.target, 0.6, 1.5) end
              end } } },
            { id = "vw_fast", tier = 3, col = 1, name = "Snappy", desc = "Bite 20% faster.",
              attack = { cooldown = { mul = -0.2 } } },
            { id = "vw_chain", tier = 4, name = "Gluey Splash", desc = "Bursts slow every ant they hit.",
              procs = { { trigger = "onKill", effect = function(ctx)
                  local e = ctx.target
                  if not (e and (e.slowT or 0) > 0) then return end
                  for _, o in ipairs(require("src.game.combat").collect(ctx.world, ctx.x, ctx.y, 32)) do fx.slow(o, 0.45, 2) end
              end } } },
            { id = "vw_feed", tier = 5, name = "Feast", desc = "Every slowed ant that bursts heals 1 HP.",
              procs = { { trigger = "onKill", effect = function(ctx)
                  local e = ctx.target
                  if e and (e.slowT or 0) > 0 then fx.heal(ctx, 1) end
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_velvet_ancient", name = "Living Fossil", desc = "Every 20 kills, a brief slime shell: 1.5 s untouchable.",
          procs = { { trigger = "onKill", effect = function(ctx, _, skills)
              if not fx.every(skills, "sig_velvet", 20) then return end
              local p = ctx.player
              p.iframes = math.max(p.iframes, 1.5)
              fx.say(ctx, "Slime shell!", GLUE)
          end } } },
}
