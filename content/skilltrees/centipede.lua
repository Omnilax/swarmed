-- Centipede: the plague. Forked venom jabs, a tail whose poison leaps from ant to ant, and a
-- hundred legs that leave a toxic trail.
local fx = require("src.game.skills").fx

local TOXIC = { 0.75, 1, 0.3 }

return {
    character = "centipede",
    branches = {
        { name = "Venom Jabs", blurb = "A blur of venom jabs", color = { 1, 0.7, 0.35 }, nodes = {
            { id = "cp_fang", tier = 1, ranks = 3, name = "Forcipule Venom", desc = "+15% jab damage and +20% jab venom per rank.",
              attack = { damage = { mul = 0.15 }, ["poison.1"] = { mul = 0.2 } } },
            { id = "cp_reach", tier = 2, name = "Long Forcipules", desc = "Jabs reach further and hit a wider line.",
              attack = { reach = 8, width = 2 } },
            { id = "cp_fork", tier = 3, col = -1, name = "Forked Jabs", desc = "Every jab forks into two more beside it.",
              fan = { move = "attack", count = 2, spread = 0.35, mult = 0.5 } },
            { id = "cp_frenzy", tier = 3, col = 1, name = "Frenzy", desc = "Jab 25% faster.",
              attack = { cooldown = { mul = -0.25 } } },
            { id = "cp_buildup", tier = 4, name = "Toxic Build-up", desc = "Jabs sometimes leave a puddle of venom under the ant.",
              procs = { { trigger = "onHit", move = "attack", chance = 0.08, effect = function(ctx)
                  fx.patch(ctx, ctx.x, ctx.y, 14, 2.5, 4, nil, TOXIC)
              end } } },
            { id = "cp_plague", tier = 5, name = "Plague Bearer", desc = "Poisoned ants burst when they die, spraying venom at the ants around them.",
              procs = { { trigger = "onKill", chance = 0.5, effect = function(ctx)
                  if ctx.target.poisonT > 0 then fx.shards(ctx, ctx.x, ctx.y, 3, 4, TOXIC, { range = 60, poison = { 4, 3 } }) end
              end } } },
        } },
        { name = "Tail Hooks", blurb = "Hooked tail stabs behind you", color = { 0.75, 0.55, 1 }, nodes = {
            { id = "cp_hook", tier = 1, ranks = 3, name = "Barbed Hooks", desc = "+15% tail damage and +20% tail venom per rank.",
              secondary = { damage = { mul = 0.15 }, ["poison.1"] = { mul = 0.2 } } },
            { id = "cp_snap", tier = 2, name = "Quick Tail", desc = "Tail Stab recharges 30% faster.",
              secondary = { cooldown = { mul = -0.3 } } },
            { id = "cp_whip", tier = 3, col = -1, name = "Double Whip", desc = "The tail stabs a second time right after.",
              echo = { move = "secondary", delay = 0.18, mult = 0.7 } },
            { id = "cp_long", tier = 3, col = 1, name = "Long Hooks", desc = "The tail reaches much further and wider.",
              secondary = { range = 30, width = 3 } },
            { id = "cp_cloud", tier = 4, name = "Venom Cloud", desc = "Every tail stab leaves a slowing cloud of venom at its tip.",
              procs = { { trigger = "onSpecial", effect = function(ctx)
                  local p, s = ctx.player, ctx.player.tailStab
                  local x, y = p.x - ctx.ax * 40, p.y - ctx.ay * 40
                  local ch = p.chain
                  if s and ch and #ch > 0 then x, y = ch[#ch].x + s.dx * s.reach * 0.7, ch[#ch].y + s.dy * s.reach * 0.7 end
                  fx.patch(ctx, x, y, 24, 3, 6, 0.6, TOXIC)
              end } } },
            { id = "cp_scolo", tier = 5, name = "Scolopendra", desc = "Tail venom leaps from every ant it hits to three more.",
              procs = { { trigger = "onHit", move = "secondary", effect = function(ctx)
                  fx.chain(ctx, ctx.target, 3, 50, 8, TOXIC, { poison = { 6, 3 } })
              end } } },
        } },
        { name = "Hundred Legs", blurb = "A long body that batters", color = { 0.5, 0.85, 1 }, nodes = {
            { id = "cp_legs", tier = 1, ranks = 3, name = "More Legs", desc = "+6 speed and +6 max HP per rank.",
              stats = { moveSpeed = 6, maxHp = 6 } },
            { id = "cp_ram", tier = 2, name = "Battering Body", desc = "The flip hits 60% harder and throws ants further.",
              dash = { damage = { mul = 0.6 }, knockback = 80 } },
            { id = "cp_longbody", tier = 3, col = -1, name = "Long Body", desc = "The flip sweeps 14 wider and hops further.",
              dash = { radius = 14, distance = 25 } },
            { id = "cp_coil", tier = 3, col = 1, name = "Coil", desc = "Store a second flip.",
              dash = { charges = { add = 1, base = 1 } } },
            { id = "cp_trail", tier = 4, name = "Venom Trail", desc = "While your rear end is aimed, the tail drips a trail of venom.",
              procs = { { trigger = "onTick", cooldown = 0.12, condition = function(ctx) return ctx.player.reversed ~= nil end, effect = function(ctx)
                  local ch = ctx.player.chain
                  local s = ch and ch[#ch] or ctx.player
                  fx.patch(ctx, s.x, s.y, 12, 2.5, 5, nil, TOXIC)
              end } } },
            { id = "cp_ouro", tier = 5, name = "Ouroboros", desc = "Every flip ends coiled in a venomous whirl that poisons all around you. +3 armor.",
              stats = { armor = 3 },
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  fx.nova(ctx, ctx.player.x, ctx.player.y, 44, 12, TOXIC, { poison = { 8, 3 }, knockback = 140 })
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_centi_giant", name = "Giant Scolopendra", desc = "Every 20th jab, venom bursts out of every segment: a toxic ring around you.",
          procs = { { trigger = "onAttack", effect = function(ctx, rank, sk)
              if not fx.every(sk, "sig_centi", 20) then return end
              local p = ctx.player
              fx.nova(ctx, p.x, p.y, 64, 10, { 0.75, 1, 0.3 }, { knockback = 120 })
              fx.patch(ctx, p.x, p.y, 56, 3, 10, nil, { 0.75, 1, 0.3 })
              fx.say(ctx, "SCOLOPENDRA!", { 0.75, 1, 0.3 })
          end } } },
}
