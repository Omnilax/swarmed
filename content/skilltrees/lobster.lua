-- Lobster: the fortress. Crushing claw snaps, a whirlpool tail that drags the swarm in, and a shell
-- that hits back harder than it gets hit.
local fx = require("src.game.skills").fx

local SEA = { 1, 0.6, 0.45 }
local WATER = { 0.55, 0.85, 1 }

return {
    character = "lobster",
    branches = {
        { name = "Crusher Claw", color = { 1, 0.7, 0.35 }, nodes = {
            { id = "lb_crush", tier = 1, ranks = 3, name = "Crusher", desc = "+15% snap damage and +10% knockback per rank.",
              attack = { damage = { mul = 0.15 }, knockback = { mul = 0.1 } } },
            { id = "lb_big", tier = 2, name = "Big Claw", desc = "The claw opens wider: a bigger bite at every hold.",
              attack = { radius = 4, maxRadius = 10 } },
            { id = "lb_double", tier = 3, col = -1, name = "Quick Hands", desc = "The claw opens 35% faster.",
              attack = { charge = { mul = -0.35 } } },
            { id = "lb_wave", tier = 3, col = 1, name = "Shockwave", desc = "Each snap sends a shockwave rolling forward.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  local p = ctx.player
                  fx.line(ctx, p.x, p.y, ctx.ax, ctx.ay, 110, 10, ctx.params.damage * 0.6, SEA, { knockback = 180 })
              end } } },
            { id = "lb_pop", tier = 4, name = "Cavitation", desc = "Snaps often pop a cavitation bubble: an extra blast where the claw shuts.",
              procs = { { trigger = "onAttack", chance = 0.3, effect = function(ctx)
                  local p, off = ctx.player, (ctx.params.offset or 30)
                  fx.explode(ctx, p.x + ctx.ax * off, p.y + ctx.ay * off, 30, 10, WATER)
              end } } },
            { id = "lb_tidal", tier = 5, name = "Tidal Snap", desc = "Every 3rd snap is a gigantic tidal crash at 2.5x damage.",
              empower = { move = "attack", every = 3, text = "TIDAL!", shake = 0.3, color = WATER,
                  mods = { radius = { mul = 0.8 }, damage = { mul = 1.5 }, knockback = { mul = 1 } } } },
        } },
        { name = "Tail Spin", color = { 0.75, 0.55, 1 }, nodes = {
            { id = "lb_spin", tier = 1, ranks = 3, name = "Powerful Tail", desc = "+15% spin damage per rank.",
              secondary = { damage = { mul = 0.15 } } },
            { id = "lb_turns", tier = 2, name = "Whirlpool", desc = "Two more turns per spin.",
              secondary = { turns = 2 } },
            { id = "lb_undertow", tier = 3, col = -1, name = "Undertow", desc = "Spinning drags ants from all around into the blades.",
              procs = { { trigger = "onSpecial", effect = function(ctx)
                  fx.pull(ctx, ctx.player.x, ctx.player.y, 100, 260)
              end } } },
            { id = "lb_wide", tier = 3, col = 1, name = "Wide Tail", desc = "The spin covers a much bigger circle.",
              secondary = { radius = 15 } },
            { id = "lb_tireless", tier = 4, name = "Tireless Tail", desc = "Tail Spin recharges 30% faster.",
              secondary = { cooldown = { mul = -0.3 } } },
            { id = "lb_maelstrom", tier = 5, name = "Maelstrom", desc = "Every turn of the spin throws out a ring of water shards.",
              procs = { { trigger = "onSpecial", effect = function(ctx)
                  local prm = ctx.params
                  for k = 0, (prm.turns or 3) - 1 do
                      ctx.player:after(k * (prm.turnTime or 0.12) + 0.01, function(p, w)
                          fx.shards(fx.ctx(w), p.x, p.y, 7, prm.damage * 0.5, WATER, { range = 90, pierce = 2 })
                      end)
                  end
              end } } },
        } },
        { name = "Shell", color = { 0.5, 0.85, 1 }, nodes = {
            { id = "lb_shell", tier = 1, ranks = 3, name = "Thick Shell", desc = "+12 max HP and +1 armor per rank.",
              stats = { maxHp = 12, armor = 1 } },
            { id = "lb_molt", tier = 2, name = "Molting", desc = "+0.6 HP regeneration per second.",
              stats = { hpRegen = 0.6 } },
            { id = "lb_spiked", tier = 3, col = -1, name = "Spiked Shell", desc = "Ants that bite your guard get spiked.",
              procs = { { trigger = "onBlock", cooldown = 0.25, effect = function(ctx)
                  local e = ctx.source
                  if type(e) == "table" and e.hp and not e.dead then
                      require("src.game.combat").damage(ctx.world, e, 8, { knockback = 120, procDepth = 1,
                          kbx = e.x - ctx.player.x, kby = e.y - ctx.player.y })
                  end
              end } } },
            { id = "lb_stride", tier = 3, col = 1, name = "Brace & Stride", desc = "Walk at double speed while blocking.",
              dash = { slow = { mul = 1 } } },
            { id = "lb_counter", tier = 4, name = "Counter Claw", desc = "Blocking a hit snaps back with a claw strike where it came from.",
              procs = { { trigger = "onBlock", cooldown = 1.2, effect = function(ctx)
                  local e, p = ctx.source, ctx.player
                  local x, y = p.x + p.aimX * 24, p.y + p.aimY * 24
                  if type(e) == "table" and e.x then x, y = e.x, e.y end
                  fx.nova(ctx, x, y, 26, 14, SEA, { knockback = 220 })
              end } } },
            { id = "lb_fortress", tier = 5, name = "Fortress", desc = "Blocking builds pressure that bursts out in a huge shockwave. +3 armor.",
              stats = { armor = 3 },
              procs = { { trigger = "onBlock", cooldown = 2, effect = function(ctx)
                  fx.explode(ctx, ctx.player.x, ctx.player.y, 50, 20, WATER, { knockback = 260 })
                  fx.say(ctx, "SHELL SHOCK", WATER)
              end } } },
        } },
    },
}
