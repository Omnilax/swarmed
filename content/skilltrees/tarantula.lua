-- Tarantula: the heavyweight. Streams of itching hairs, stomps that crack the ground in six
-- directions, leaps that flatten the swarm, and a body that molts back to health.
local fx = require("src.game.skills").fx

local HAIR = { 1, 0.6, 0.3 }

return {
    character = "tarantula",
    branches = {
        { name = "Hair Flick", color = { 1, 0.7, 0.35 }, nodes = {
            { id = "ta_hairs", tier = 1, ranks = 3, name = "Thick Hairs", desc = "+20% hair damage per rank.",
              secondary = { damage = { mul = 0.2 } } },
            { id = "ta_itch", tier = 2, name = "Itching Hairs", desc = "Hairs slow ants much harder and for longer.",
              secondary = { ["slow.1"] = { mul = -0.35 }, ["slow.2"] = 1 } },
            { id = "ta_cloud", tier = 3, col = -1, name = "Hair Cloud", desc = "Hairs now and then leave a drifting cloud that hurts and slows.",
              procs = { { trigger = "onSpecial", chance = 0.04, effect = function(ctx)
                  local p = ctx.player
                  fx.patch(ctx, p.x + ctx.ax * 60, p.y + ctx.ay * 60, 34, 2, 3, 0.6, HAIR)
              end } } },
            { id = "ta_flick", tier = 3, col = 1, name = "Double Flick", desc = "Kick two hairs at a time.",
              fan = { move = "secondary", count = 1, spread = 0.12, mult = 1 } },
            { id = "ta_barbs", tier = 4, name = "Barbed Hairs", desc = "Hairs pierce through one more ant and fly further.",
              secondary = { pierce = 1, range = 30 } },
            { id = "ta_storm", tier = 5, name = "Hair Storm", desc = "Hairs come 40% faster, and ants they kill burst in more hairs.",
              secondary = { rate = { mul = -0.4 } },
              procs = { { trigger = "onKill", move = "secondary", chance = 0.25, effect = function(ctx)
                  fx.shards(ctx, ctx.x, ctx.y, 3, 4, HAIR, { range = 50 })
              end } } },
        } },
        { name = "Stomp", color = { 0.75, 0.55, 1 }, nodes = {
            { id = "ta_fang", tier = 1, ranks = 3, name = "Huge Fangs", desc = "+15% stomp damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "ta_rear", tier = 2, name = "Quick Rear", desc = "Rear up 40% faster and recharge 20% faster.",
              attack = { windup = { mul = -0.4, base = 0.22 }, cooldown = { mul = -0.2 } } },
            { id = "ta_quake", tier = 3, col = -1, name = "Earthquake", desc = "A much bigger stomp that stuns for longer.",
              attack = { radius = 16, stun = 0.6 } },
            { id = "ta_venom", tier = 3, col = 1, name = "Venom Fangs", desc = "Stomps pump heavy venom into every ant they hit.",
              procs = { { trigger = "onHit", move = "attack", effect = function(ctx) fx.poison(ctx.target, 10, 4) end } } },
            { id = "ta_after", tier = 4, name = "Aftershock", desc = "Stomp a second time a moment later.",
              echo = { move = "attack", delay = 0.55, mult = 0.6 } },
            { id = "ta_goliath", tier = 5, name = "Goliath", desc = "Stomps crack the ground in six directions, hitting everything along the cracks.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  local prm = ctx.params
                  ctx.player:after((prm.windup or 0.28) + 0.01, function(p, w)
                      local cx, cy = p.x + p.aimX * (prm.offset or 18), p.y + p.aimY * (prm.offset or 18)
                      for i = 1, 6 do
                          local a = i / 6 * math.pi * 2
                          fx.line(fx.ctx(w), cx, cy, math.cos(a), math.sin(a), 110, 8, prm.damage * 0.6, HAIR, { slow = { 0.1, 1 } })
                      end
                  end)
              end } } },
        } },
        { name = "Bulk", color = { 0.5, 0.85, 1 }, nodes = {
            { id = "ta_bulk", tier = 1, ranks = 3, name = "Bulk", desc = "+14 max HP and +0.2 HP regen per rank.",
              stats = { maxHp = 14, hpRegen = 0.2 } },
            { id = "ta_ram", tier = 2, name = "Heavy Landing", desc = "Leap slams hit harder over a wider area.",
              dash = { damage = 8, radius = 8 } },
            { id = "ta_ambush", tier = 3, col = -1, name = "Long Leap", desc = "Leap 35 further and daze ants 0.5 s longer.",
              dash = { distance = 35, stun = 0.5 } },
            { id = "ta_silk", tier = 3, col = 1, name = "Silk-Lined Burrow", desc = "+4 armor.",
              stats = { armor = 4 } },
            { id = "ta_molt", tier = 4, name = "Molt", desc = "Once in a while, dropping under 30% HP sheds your skin and heals 30%.",
              procs = { { trigger = "onHurt", cooldown = 20,
                  condition = function(ctx) return ctx.player.hp < ctx.player.stats:get("maxHp") * 0.3 end,
                  effect = function(ctx)
                  ctx.player:heal(ctx.player.stats:get("maxHp") * 0.3)
                  fx.say(ctx, "MOLT!", { 0.6, 1, 0.6 })
              end } } },
            { id = "ta_goliath_body", tier = 5, name = "Bird-Eater", desc = "+6% life steal, +15% damage, and kills sometimes heal you.",
              stats = { lifesteal = 6, damage = 15 },
              procs = { { trigger = "onKill", chance = 0.1, effect = function(ctx) fx.heal(ctx, 1) end } } },
        } },
    },
}
