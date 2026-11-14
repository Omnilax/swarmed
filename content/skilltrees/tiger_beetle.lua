-- Tiger Beetle: pure speed. A charge dash that chains through the swarm, sprint strikes that
-- leave cuts in the air, and a run that never runs out.
local fx = require("src.game.skills").fx

local GREEN = { 0.6, 1, 0.7 }

return {
    character = "tiger_beetle",
    branches = {
        { name = "Charge Dash", color = { 1, 0.7, 0.35 }, nodes = {
            { id = "tb_edge", tier = 1, ranks = 3, name = "Sharp Mandibles", desc = "+15% charge dash damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "tb_stride", tier = 2, name = "Long Stride", desc = "Charge dashes go further and cut a wider path.",
              attack = { maxDistance = 30, width = 3 } },
            { id = "tb_quickcharge", tier = 3, col = -1, name = "Hair Trigger", desc = "Wind up 35% faster.",
              attack = { charge = { mul = -0.35 } } },
            { id = "tb_venom", tier = 3, col = 1, name = "Digestive Spit", desc = "Charge dashes leave ants poisoned.",
              attack = { poison = { set = { 6, 3 } } } },
            { id = "tb_wake", tier = 4, name = "Wake Slash", desc = "The air behind you cuts the same path again a moment later.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  local x, y, ax, ay = ctx.player.x, ctx.player.y, ctx.ax, ctx.ay
                  local len, dmg = (ctx.params.maxDistance or 150) * 0.7, ctx.params.damage * 0.8
                  ctx.player:after(0.14, function(p, w) fx.line(fx.ctx(w), x, y, ax, ay, len, 10, dmg, GREEN) end)
              end } } },
            { id = "tb_blitz", tier = 5, name = "Blitz", desc = "Every kill with a charge dash refunds its cooldown: chain through the whole swarm.",
              procs = { { trigger = "onKill", move = "attack", effect = function(ctx)
                  local a = ctx.player.attack
                  a.timer = math.min(a.timer, 0.05)
              end } } },
        } },
        { name = "Sprint Strike", color = { 0.75, 0.55, 1 }, nodes = {
            { id = "tb_rage", tier = 1, ranks = 3, name = "Bloodlust", desc = "+15% sprint strike damage per rank.",
              secondary = { damage = { mul = 0.15 } } },
            { id = "tb_frenzy", tier = 2, name = "Restless Legs", desc = "Sprint strike recharges 30% faster.",
              secondary = { cooldown = { mul = -0.3 } } },
            { id = "tb_after", tier = 3, col = -1, name = "Afterimage", desc = "Every sprint strike is followed by a second one from where you land.",
              echo = { move = "secondary", delay = "dash", mult = 0.6 } },
            { id = "tb_range", tier = 3, col = 1, name = "Hunting Range", desc = "Sprint strikes reach much further and cut wider.",
              secondary = { distance = 35, width = 4 } },
            { id = "tb_bleed", tier = 4, name = "Bleeding Cuts", desc = "Sprint strikes leave ants bleeding (poison).",
              procs = { { trigger = "onHit", move = "secondary", effect = function(ctx) fx.poison(ctx.target, 8, 3) end } } },
            { id = "tb_cyclone", tier = 5, name = "Cyclone", desc = "Every sprint strike that connects whips up a slashing whirlwind around you.",
              procs = { { trigger = "onHit", move = "secondary", cooldown = 0.15, effect = function(ctx)
                  local p = ctx.player
                  fx.nova(ctx, p.x, p.y, 34, p.secondary.params.damage * 0.7, GREEN, { knockback = 120 })
              end } } },
        } },
        { name = "Run", color = { 0.5, 0.85, 1 }, nodes = {
            { id = "tb_legs", tier = 1, ranks = 3, name = "Long Legs", desc = "+8 speed and +2% dodge per rank.",
              stats = { moveSpeed = 8, dodge = 2 } },
            { id = "tb_burner", tier = 2, name = "Second Wind", desc = "+1 s of running and it refills 30% faster.",
              dash = { stamina = 1, regen = 0.3 } },
            { id = "tb_twin", tier = 3, col = -1, name = "Sprinter", desc = "Run 20% faster.",
              dash = { speed = 0.3 } },
            { id = "tb_ghost", tier = 3, col = 1, name = "Razor Legs", desc = "Ants you clip while running take 4x damage.",
              dash = { ram = 9 } },
            { id = "tb_hunter", tier = 4, name = "Hunter's Rush", desc = "After a run: +30% damage and +15% crit chance for 2 s.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  fx.buff(ctx, "tb_hunt_dmg", "damage", 30, 0, 2)
                  fx.buff(ctx, "tb_hunt_crit", "critChance", 15, 0, 2)
              end } } },
            { id = "tb_sonic", tier = 5, name = "Sonic Boom", desc = "Stopping a run breaks the sound barrier: a shockwave where you stop.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  fx.explode(ctx, ctx.player.x, ctx.player.y, 36, 18, GREEN, { knockback = 220 })
              end } } },
        } },
    },
}
