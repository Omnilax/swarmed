-- Stag Beetle: the wrestler. Jaws that snip and toss, thrown ants that land like meteors,
-- and a body that only gets angrier when hit.
local fx = require("src.game.skills").fx

local AMBER = { 1, 0.8, 0.55 }

return {
    character = "stag_beetle",
    branches = {
        { name = "Mandibles", color = { 1, 0.7, 0.35 }, nodes = {
            { id = "sb_crush", tier = 1, ranks = 3, name = "Crushing Jaws", desc = "+15% bite damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "sb_reach", tier = 2, name = "Long Jaws", desc = "Bites reach further.",
              attack = { radius = 8, arc = 0.2 } },
            { id = "sb_scissor", tier = 3, col = -1, name = "Scissor Snap", desc = "The jaws snap shut a second time right after each bite.",
              echo = { move = "attack", delay = 0.12, mult = 0.7, sameAim = true } },
            { id = "sb_guillotine", tier = 3, col = 1, name = "Guillotine", desc = "Every 3rd bite is a wide, brutal clamp at 2.5x damage.",
              empower = { move = "attack", every = 3, text = "SNIP!", shake = 0.12,
                  mods = { damage = { mul = 1.5 }, arc = { set = 3.4 }, radius = { mul = 0.2 } } } },
            { id = "sb_shards", tier = 4, name = "Shell Shards", desc = "Ants crushed by your jaws burst into flying shell shards.",
              procs = { { trigger = "onKill", move = "attack", chance = 0.35, effect = function(ctx)
                  fx.shards(ctx, ctx.x, ctx.y, 4, 6, AMBER)
              end } } },
            { id = "sb_titan", tier = 5, name = "Titan Jaws", desc = "Bigger, heavier bites, and every bite tosses the nearest ant it caught over your head into the crowd.",
              attack = { radius = { mul = 0.2 }, knockback = { mul = 0.5 } },
              procs = { { trigger = "onAttack", effect = function(ctx)
                  local p = ctx.player
                  local e = fx.near(ctx, p.x + ctx.ax * 20, p.y + ctx.ay * 20, 26)
                  if e then fx.fling(ctx, e, ctx.ax, ctx.ay, 110, { damage = 10, landDamage = ctx.params.damage, radius = 28, height = 22, color = AMBER }) end
              end } } },
        } },
        { name = "Swing & Hurl", color = { 0.75, 0.55, 1 }, nodes = {
            { id = "sb_arm", tier = 1, ranks = 3, name = "Strong Neck", desc = "+15% swing and throw damage per rank.",
              secondary = { damage = { mul = 0.15 } } },
            { id = "sb_fast", tier = 2, name = "Restless", desc = "Swing & Hurl recharges 30% faster.",
              secondary = { cooldown = { mul = -0.3 } } },
            { id = "sb_cluster", tier = 3, col = -1, name = "Shrapnel Landing", desc = "Thrown ants shatter on landing, spraying shell shards all around.",
              throw = { onLand = function(w, x, y, rank) fx.shards(fx.ctx(w), x, y, 7, 7, AMBER, { range = 70 }) end } },
            { id = "sb_big", tier = 3, col = 1, name = "Heavy Landing", desc = "Thrown ants land with a 50% bigger, 50% harder crash.",
              throw = { radiusMul = 0.5, landMul = 0.5 } },
            { id = "sb_crash", tier = 4, name = "Seismic Crash", desc = "Landings stun every ant nearby for a moment.",
              throw = { onLand = function(w, x, y, rank, o)
                  fx.nova(fx.ctx(w), x, y, (o.radius or 30) * 1.2, 4, AMBER, { slow = { 0.05, 1.2 }, knockback = 40 })
              end } },
            { id = "sb_meteor", tier = 5, name = "Meteor", desc = "Throws go far further and land as huge fiery explosions.",
              secondary = { distance = 60 },
              throw = { landMul = 1, radiusMul = 0.5, onLand = function(w, x, y)
                  fx.explode(fx.ctx(w), x, y, 50, 30, { 1, 0.55, 0.2 })
                  w.particles:burst(x, y, 14, { { 1, 0.7, 0.3 }, { 1, 0.4, 0.1 } }, 140, 90, { glow = true, grav = -20 })
              end } },
        } },
        { name = "Armour", color = { 0.5, 0.85, 1 }, nodes = {
            { id = "sb_plate", tier = 1, ranks = 3, name = "Plated", desc = "+12 max HP and +1 armor per rank.",
              stats = { maxHp = 12, armor = 1 } },
            { id = "sb_hop", tier = 2, name = "Strong Wings", desc = "Flights go further and higher.",
              dash = { distance = 25, hop = 8 } },
            { id = "sb_stomp", tier = 3, col = -1, name = "Stomp", desc = "Every flight lands with a stomp that throws ants back.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  fx.nova(ctx, ctx.player.x, ctx.player.y, 36, 14, AMBER, { knockback = 200 })
              end } } },
            { id = "sb_twin", tier = 3, col = 1, name = "Second Wind", desc = "Store a second flight.",
              dash = { charges = 1 } },
            { id = "sb_rut", tier = 4, name = "Rut", desc = "Getting hurt makes you furious: +25% damage for 4 s.",
              procs = { { trigger = "onHurt", cooldown = 4, effect = function(ctx)
                  fx.buff(ctx, "sb_rut", "damage", 25, 0, 4)
                  fx.say(ctx, "RUT!", { 1, 0.5, 0.3 })
              end } } },
            { id = "sb_king", tier = 5, name = "King of the Log", desc = "Flights land with a quake that hurls every ant around you away like thrown clubs. +60% knockback.",
              stats = { knockback = 60 },
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  local p = ctx.player
                  local Combat = require("src.game.combat")
                  local n = 0
                  for _, e in ipairs(Combat.collect(ctx.world, p.x, p.y, 40)) do
                      if n >= 6 then break end
                      local dx, dy = fx.dir(ctx, e.x, e.y)
                      fx.fling(ctx, e, dx, dy, 80, { damage = 8, landDamage = 10, radius = 22, color = AMBER })
                      n = n + 1
                  end
              end } } },
        } },
    },
}
