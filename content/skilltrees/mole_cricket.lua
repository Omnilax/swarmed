-- Mole Cricket: shovel claws that dig through the crowd, sand thrown like buckshot, and a
-- burrow that turns every surfacing into an ambush.
local fx = require("src.game.skills").fx
local Combat = require("src.game.combat")

local SOIL = { 0.62, 0.48, 0.32 }
local SAND = { 0.9, 0.8, 0.58 }

return {
    character = "mole_cricket",
    branches = {
        { name = "Shovel Claws", blurb = "Huge swipes that plough the swarm", color = { 0.85, 0.6, 0.38 }, nodes = {
            { id = "mc_claws", tier = 1, ranks = 3, name = "Shovel Claws", desc = "+15% slash damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "mc_wide", tier = 2, name = "Wide Sweep", desc = "The slash reaches 10 further.",
              attack = { radius = 10 } },
            { id = "mc_heavy", tier = 3, col = -1, name = "Heavy Paws", desc = "The slash knocks ants 50% further.",
              attack = { knockback = { mul = 0.5 } } },
            { id = "mc_quick", tier = 3, col = 1, name = "Restless Digger", desc = "Slash 15% faster.",
              attack = { cooldown = { mul = -0.15 } } },
            { id = "mc_clods", tier = 4, name = "Dirt Clods", desc = "Every 4th slash flings 4 clods of earth ahead.",
              procs = { { trigger = "onAttack", effect = function(ctx, _, skills)
                  if not fx.every(skills, "mc_clods", 4) then return end
                  local p = ctx.player
                  fx.shards(ctx, p.x, p.y, 4, ctx.params.damage * 0.6, SOIL, { angle = math.atan2(ctx.ay, ctx.ax), spread = 0.8, range = 110, pierce = 1 })
              end } } },
            { id = "mc_cavein", tier = 5, name = "Cave-In", desc = "Ants your slash kills crumble and hurt everything around them.",
              procs = { { trigger = "onKill", move = "attack", effect = function(ctx)
                  fx.explode(ctx, ctx.x, ctx.y, 26, 10, SOIL)
              end } } },
        } },
        { name = "Sand Toss", blurb = "Grit thrown like buckshot", color = SAND, nodes = {
            { id = "mc_grit", tier = 1, ranks = 3, name = "Sharp Grit", desc = "+15% sand damage per rank.",
              secondary = { damage = { mul = 0.15 } } },
            { id = "mc_handful", tier = 2, name = "Big Handfuls", desc = "Each toss throws 5 more grains.",
              secondary = { grains = 5 } },
            { id = "mc_far", tier = 3, col = -1, name = "Long Throw", desc = "Sand flies 40% further and keeps more of its bite.",
              secondary = { range = { mul = 0.4 }, falloff = -0.2 } },
            { id = "mc_quickhands", tier = 3, col = 1, name = "Quick Hands", desc = "Sand toss recharges 30% faster.",
              secondary = { cooldown = { mul = -0.3 } } },
            { id = "mc_buckshot", tier = 4, name = "Buckshot", desc = "Every grain goes through 1 more ant.",
              secondary = { pierce = 1 } },
            { id = "mc_dune", tier = 5, name = "Dune Storm", desc = "Every toss leaves a patch of loose sand ahead that slows and stings ants for 3 s.",
              procs = { { trigger = "onSpecial", effect = function(ctx)
                  local p = ctx.player
                  fx.patch(ctx, p.x + ctx.ax * 60, p.y + ctx.ay * 60, 36, 3, 5, 0.5, SAND)
              end } } },
        } },
        { name = "Burrow", blurb = "Dig in, burst out", color = { 0.7, 0.55, 0.4 }, nodes = {
            { id = "mc_lungs", tier = 1, ranks = 3, name = "Deep Lungs", desc = "Stay underground 0.6 s longer per rank.",
              dash = { stamina = 0.6 } },
            { id = "mc_habit", tier = 2, name = "Burrow Habit", desc = "Digging recharges 25% faster.",
              dash = { regen = { mul = 0.25 } } },
            { id = "mc_rising", tier = 3, col = -1, name = "Rising Claws", desc = "The uppercut does +12 damage over a 12 wider area.",
              dash = { strike = 12, strikeRadius = 12 } },
            { id = "mc_tremor", tier = 3, col = 1, name = "Tremor", desc = "The earthquake is 25 wider and stuns 0.5 s longer.",
              dash = { quakeRadius = 25, quakeStun = 0.5 } },
            { id = "mc_tunnel", tier = 4, name = "Fast Tunnels", desc = "Tunnel 25% faster.",
              dash = { speed = 0.5 } },
            { id = "mc_ambush", tier = 5, name = "Ambush Predator", desc = "Bursting out with an uppercut or earthquake: +40% damage and +30% attack speed for 3 s.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  if not ctx.player.moleLast then return end
                  fx.buff(ctx, "mc_amb_d", "damage", 40, 0, 3)
                  fx.buff(ctx, "mc_amb_s", "attackSpeed", 30, 0, 3)
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_mole_song", name = "Burrow Song", desc = "Underground you sing through your burrow: ants close above you are slowed.",
          procs = { { trigger = "onTick", effect = function(ctx)
              local p = ctx.player
              if not (p.holdMode and p.digId) then return end
              p._mcSong = (p._mcSong or 0) + ctx.dt
              if p._mcSong < 0.4 then return end
              p._mcSong = 0
              for _, e in ipairs(Combat.collect(ctx.world, p.x, p.y, 55)) do fx.slow(e, 0.5, 0.6) end
          end } } },
}
