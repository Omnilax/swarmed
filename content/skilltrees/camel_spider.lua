-- Camel Spider: speed and blood. Jaws that pierce deeper, a frenzy that chains further and
-- feeds you, and a burrow that turns into a sandworm ambush.
local fx = require("src.game.skills").fx
local Combat = require("src.game.combat")

local SAND = { 1, 0.85, 0.55 }

return {
    character = "camel_spider",
    branches = {
        { name = "Piercing Jaws", color = { 1, 0.75, 0.4 }, nodes = {
            { id = "cs_jaws", tier = 1, ranks = 3, name = "Sharp Jaws", desc = "+15% jaw damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "cs_serrated", tier = 2, name = "Serrated Edge", desc = "Jaw bites make ants bleed twice as fast.",
              attack = { ["bleed.1"] = { mul = 1 } } },
            { id = "cs_quick", tier = 3, col = -1, name = "Triple Thrust", desc = "The jaws drive in a third time.",
              attack = { thrusts = 1 } },
            { id = "cs_gorge", tier = 3, col = 1, name = "Gorge", desc = "Every ant your jaws kill heals 1 HP.",
              procs = { { trigger = "onKill", move = "attack", effect = function(ctx) fx.heal(ctx, 1) end } } },
            { id = "cs_rend", tier = 4, name = "Rending Thrust", desc = "Thrusts reach 14 further and the last one hits 60% harder.",
              attack = { reach = 14, finalMult = 0.6 } },
            { id = "cs_storm", tier = 5, name = "Sandstorm Rake", desc = "Every attack flicks a fan of stinging sand ahead that pierces the crowd.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  local p = ctx.player
                  fx.shards(ctx, p.x, p.y, 5, ctx.params.damage * 0.6, SAND, { angle = math.atan2(ctx.ay, ctx.ax), spread = 1.1, range = 90, pierce = 2 })
              end } } },
        } },
        { name = "Frenzy", color = { 1, 0.45, 0.35 }, nodes = {
            { id = "cs_fdmg", tier = 1, ranks = 3, name = "Bloodlust", desc = "+15% frenzy damage per rank.",
              secondary = { damage = { mul = 0.15 } } },
            { id = "cs_hops", tier = 2, name = "Relentless", desc = "Frenzy darts to 2 more ants.",
              secondary = { hops = 2 } },
            { id = "cs_long", tier = 3, col = -1, name = "Long Darts", desc = "Each dart can reach ants 40 further away.",
              secondary = { range = 40 } },
            { id = "cs_feed", tier = 3, col = 1, name = "Blood Frenzy", desc = "Every frenzy bite heals 1 HP.",
              procs = { { trigger = "onHit", move = "secondary", effect = function(ctx) fx.heal(ctx, 1) end } } },
            { id = "cs_fcd", tier = 4, name = "Hair Trigger", desc = "Frenzy recharges 30% faster.",
              secondary = { cooldown = { mul = -0.3 } } },
            { id = "cs_carnage", tier = 5, name = "Carnage", desc = "Ants killed during a frenzy burst apart and hurt everything around them.",
              procs = { { trigger = "onKill", move = "secondary", effect = function(ctx)
                  fx.explode(ctx, ctx.x, ctx.y, 30, ctx.params and ctx.params.damage or 12, { 1, 0.4, 0.3 })
              end } } },
        } },
        { name = "Burrow", color = { 0.9, 0.8, 0.55 }, nodes = {
            { id = "cs_legs", tier = 1, ranks = 3, name = "Desert Legs", desc = "+8 max HP and +5% speed per rank.",
              stats = { maxHp = 8 }, statsMult = { moveSpeed = 0.05 } },
            { id = "cs_erupt", tier = 2, name = "Violent Eruption", desc = "Bursting out does +10 damage over a 12 wider area.",
              dash = { damage = 10, radius = 12 } },
            { id = "cs_deep", tier = 3, col = -1, name = "Deep Tunnels", desc = "Stay underground 1.5 s longer and tunnel 15% faster.",
              dash = { stamina = 1.5, speed = 0.2 } },
            { id = "cs_quicksand", tier = 3, col = 1, name = "Quicksand", desc = "The eruption leaves a sinkhole that slows and hurts ants for 3 s.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  fx.patch(ctx, ctx.player.x, ctx.player.y, 38, 3, 6, 0.35, { 0.8, 0.7, 0.45 })
              end } } },
            { id = "cs_ambush", tier = 4, name = "Ambush", desc = "After surfacing: +50% damage and +30% attack speed for 2.5 s.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  fx.buff(ctx, "cs_amb_d", "damage", 50, 0, 2.5)
                  fx.buff(ctx, "cs_amb_s", "attackSpeed", 30, 0, 2.5)
              end } } },
            { id = "cs_worm", tier = 5, name = "Sandworm", desc = "You erupt like a sandworm: ants above are thrown away as missiles and sand sprays out all round.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  local p = ctx.player
                  for _, e in ipairs(Combat.collect(ctx.world, p.x, p.y, 36)) do
                      local dx, dy = fx.dir(ctx, e.x, e.y)
                      fx.fling(ctx, e, dx, dy, 80, { damage = 10, landDamage = 12, radius = 24, color = SAND })
                  end
                  fx.shards(ctx, p.x, p.y, 10, 8, SAND, { range = 90, pierce = 2 })
              end } } },
        } },
    },
}
