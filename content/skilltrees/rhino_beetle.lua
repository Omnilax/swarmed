-- Rhino Beetle: a walking battering ram. Sweeps that shake the ground, a horn that turns ants
-- into thrown missiles, and a charge nothing can stop.
local fx = require("src.game.skills").fx

local BLUE = { 0.6, 0.95, 1 }

return {
    character = "rhino_beetle",
    branches = {
        { name = "Horn Sweep", color = { 1, 0.7, 0.35 }, nodes = {
            { id = "rb_heft", tier = 1, ranks = 3, name = "Heavy Horn", desc = "+15% sweep damage and +10% knockback per rank.",
              attack = { damage = { mul = 0.15 }, knockback = { mul = 0.1 } } },
            { id = "rb_wide", tier = 2, name = "Wide Sweep", desc = "Sweeps reach further and cover a wider arc.",
              attack = { radius = 8, arc = 0.6 } },
            { id = "rb_quake", tier = 3, col = -1, name = "Seismic Sweep",
              desc = "Every 3rd sweep is a full circle, half again as big, at double damage.",
              empower = { move = "attack", every = 3, text = "QUAKE!", shake = 0.15,
                  mods = { radius = { mul = 0.5 }, damage = { mul = 1 }, arc = { set = 6.3 }, knockback = { mul = 0.5 } } } },
            { id = "rb_twin", tier = 3, col = 1, name = "Back-swing", desc = "Every sweep swings back the other way a beat later.",
              echo = { move = "attack", delay = 0.14, mult = 0.6, sameAim = true } },
            { id = "rb_shock", tier = 4, name = "Aftershock", desc = "Ants killed by a sweep burst into a small shockwave.",
              procs = { { trigger = "onKill", move = "attack", chance = 0.3,
                  effect = function(ctx) fx.nova(ctx, ctx.x, ctx.y, 22, 6, BLUE) end } } },
            { id = "rb_split", tier = 5, name = "Earthsplitter", desc = "Every sweep also splits the ground ahead: a long fissure that hits everything on it.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  local p = ctx.player
                  fx.line(ctx, p.x, p.y, ctx.ax, ctx.ay, 140, 8, ctx.params.damage, BLUE, { knockback = 160 })
                  ctx.world.particles:burst(p.x + ctx.ax * 70, p.y + ctx.ay * 70, 8, { { 0.6, 0.55, 0.5 } }, 80, 50, { grav = 260 })
              end } } },
        } },
        { name = "Horn Pierce", color = { 0.75, 0.55, 1 }, nodes = {
            { id = "rb_lance", tier = 1, ranks = 3, name = "Long Horn", desc = "+15% pierce damage and +10 reach per rank.",
              secondary = { damage = { mul = 0.15 }, range = 10 } },
            { id = "rb_quick", tier = 2, name = "Quick Thrust", desc = "Horn Pierce recharges 30% faster.",
              secondary = { cooldown = { mul = -0.3 } } },
            { id = "rb_trident", tier = 3, col = -1, name = "Trident", desc = "Two more thrusts fan out beside the main one.",
              fan = { move = "secondary", count = 2, spread = 0.3, mult = 0.7 } },
            { id = "rb_skewer", tier = 3, col = 1, name = "Skewer Blast", desc = "The tip of the thrust explodes.",
              procs = { { trigger = "onSpecial", effect = function(ctx)
                  local p, reach = ctx.player, (ctx.params.range or 95) * (1 + ctx.player.stats:get("area") / 100)
                  fx.explode(ctx, p.x + ctx.ax * reach, p.y + ctx.ay * reach, 34, ctx.params.damage * 0.8, BLUE)
              end } } },
            { id = "rb_double", tier = 4, name = "Double Gore", desc = "Thrusts again a moment later.",
              echo = { move = "secondary", delay = 0.25, mult = 0.8 } },
            { id = "rb_stampede", tier = 5, name = "Living Rams", desc = "Ants run through by the horn are hurled away like missiles, bowling over the crowd and crashing down.",
              procs = { { trigger = "onHit", move = "secondary", effect = function(ctx)
                  local p = ctx.player
                  fx.fling(ctx, ctx.target, p.aimX, p.aimY, 120, { damage = 10, landDamage = 14, radius = 26, color = BLUE })
              end } } },
        } },
        { name = "Charge", color = { 0.5, 0.85, 1 }, nodes = {
            { id = "rb_shell", tier = 1, ranks = 3, name = "Thick Shell", desc = "+10 max HP and +1 armor per rank.",
              stats = { maxHp = 10, armor = 1 } },
            { id = "rb_ram", tier = 2, name = "Battering Ram", desc = "Your charge hits harder, barges ants further and heaves the scooped ones down harder.",
              dash = { ram = 8, knockback = 80, tossDamage = 8 } },
            { id = "rb_long", tier = 3, col = -1, name = "Long Charge", desc = "Charge further, and store a second charge.",
              dash = { distance = 45, charges = 1 } },
            { id = "rb_landing", tier = 3, col = 1, name = "Thunder Landing", desc = "Every charge ends in an explosion.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  fx.explode(ctx, ctx.player.x, ctx.player.y, 40, 16, BLUE)
              end } } },
            { id = "rb_momentum", tier = 4, name = "Momentum", desc = "After a charge: +40% attack speed and +20% damage for 2 s.",
              procs = { { trigger = "onDash", effect = function(ctx)
                  fx.buff(ctx, "rb_mom_as", "attackSpeed", 40, 0, 2)
                  fx.buff(ctx, "rb_mom_dmg", "damage", 20, 0, 2)
              end } } },
            { id = "rb_juggernaut", tier = 5, name = "Juggernaut", desc = "Ants you charge into are flung aside as missiles. +3 armor.",
              stats = { armor = 3 },
              procs = { { trigger = "onHit", move = "dash", effect = function(ctx)
                  local p, e = ctx.player, ctx.target
                  local dx, dy = fx.dir(ctx, e.x, e.y)
                  fx.fling(ctx, e, dx, dy, 90, { damage = 10, landDamage = 12, radius = 24, color = BLUE })
              end } } },
        } },
    },
}
