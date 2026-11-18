-- TEMPLATE. Copy to content/skilltrees/<character id>.lua to give a playable bug its skill tree.
-- Engine: src/game/skills.lua. Kills give XP and every level opens a level-up card pick; the
-- cards are stat boosts, and SKIPPING a pick banks one skill point (setting "Level-Ups: Skill
-- Points": every level is a point). Points are spent in the bag screen (Tab or the SKILLS tab).
-- A whole tree costs ~45 points and a run levels ~35 times (and you won't skip them all), and
-- forks are either/or, so no run gets everything: make each branch a different way to play.
--
-- Layout: 3 branches side by side (usually: main attack, special, dash/body), plus a 4th KIN
-- branch added for you: the shared branch of the bug's lineage (content/skillbranches, picked by
-- the character's tags), topped by this tree's `signature` node. Inside a branch nodes stack by
-- `tier` (1 at the top). Two or three nodes on the same tier are a FORK: buying one locks the
-- others (set fork = false on a node to opt out). Put them on col = -1 and col = 1 (col 0 = centred).
--
-- Branch fields: name, color, blurb (one short line under the name saying what the branch is
-- about), nodes.
--
-- Tree fields besides branches:
--   signature = { node }   the bug's own capstone at the top of the kin branch (one tier above
--                          the kin nodes, 3 points by default). Make it the bug's signature trick.
--   kin = "<id>" | false   pick a kin branch by id instead of by tags, or have none.
--
-- Node fields:
--   id, name, desc        unique id, short name, one line saying what it does
--   tier (1..5)           row; cost defaults to 1, 1, 2, 2, 3 by tier
--   cost, ranks           points per rank (default by tier), how many times it can be bought (1)
--   col                   -1 / 0 / 1 position inside the branch
--   requires              node ids, ANY of which must be owned. Default: any node one tier down
--                         in the same branch ({} = a root anywhere)
--   excludes              node ids that lock this one (forks fill this in for you)
--
-- What a node does (all multiplied by rank where it makes sense; mix freely):
--   stats = { maxHp = 10 }, statsMult = { moveSpeed = 0.1 }    like items (src/config/stats.lua)
--   attack / secondary / dash = { param = mod }   change that move's params (the character file's
--       attack/secondary/dash table). A mod is a number (added), true/"x" (set), or
--       { add = n, mul = 0.2, set = v, base = default if the param is missing }.
--       Nested numbers by path: ["poison.1"] = { mul = 0.5 } (first entry of params.poison).
--   echo = { move = "attack", delay = 0.15 | "dash" (after the move's own lunge), mult = 0.6,
--            times = 1, perRank, chance, sameAim, text }    the move fires again a beat later
--   fan = { move = "secondary", count = 2, spread = 0.4, mult = 0.6, perRank }
--            extra copies fired at once, fanned out (for moves that don't move the bug)
--   empower = { move = "attack", every = 3, mods = { radius = { mul = 0.5 } }, text = "QUAKE!", shake }
--            every Nth use fires with these extra mods
--   throw = { landMul, landDamage, radiusMul, bowlMul, onLand = function(world, x, y, rank, opts) }
--            ants this bug throws (Grab.fling) crash down harder
--   procs = { { trigger = "onKill", chance = 0.3 | function(rank), move = "attack", cooldown = 1,
--               condition = function(ctx, rank) -> bool (checked before the cooldown starts),
--               effect = function(ctx, rank, skills) ... end } }
--       triggers: onHit, onKill (ctx.target, ctx.x, ctx.y, ctx.damage), onHurt, onDodge, onDash,
--       onDashEnd, onBlock (ctx.source), onAttack, onSpecial (ctx.ax, ctx.ay, ctx.px, ctx.py,
--       ctx.params), onTick (ctx.dt), onWaveStart, onEat.
--       `move` limits a proc to hits made by that move ("attack" | "secondary" | "dash").
--       Helpers: local fx = require("src.game.skills").fx  ->  fx.explode, fx.nova, fx.line,
--       fx.chain, fx.shards, fx.patch, fx.web, fx.buff, fx.fling, fx.poison, fx.slow, fx.pull,
--       fx.heal, fx.near, fx.say, fx.dir, fx.ctx, fx.every (see src/game/skills.lua). Pass ctx through so
--       procs can't set each other off forever.
--
-- `--selftest --skills` buys every node of every tree and fights with it.
local fx = require("src.game.skills").fx

return {
    character = "my_bug",
    branches = {
        { name = "Sweep", blurb = "Wide sweeps that toss ants", color = { 1, 0.7, 0.35 }, nodes = {
            { id = "mb_power", tier = 1, ranks = 3, name = "Heavy Horn", desc = "+15% sweep damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "mb_wide", tier = 2, name = "Wide Sweep", desc = "Sweeps reach further and wider.",
              attack = { radius = 8, arc = 0.6 } },
            { id = "mb_quake", tier = 3, col = -1, name = "Quake", desc = "Every 3rd sweep is a huge full circle.",
              empower = { move = "attack", every = 3, mods = { radius = { mul = 0.5 }, arc = { set = 6.3 } }, text = "QUAKE!" } },
            { id = "mb_twin", tier = 3, col = 1, name = "Back-swing", desc = "Each sweep swings back a beat later.",
              echo = { move = "attack", delay = 0.14, mult = 0.6 } },
            { id = "mb_shock", tier = 4, name = "Aftershock", desc = "Ants your sweep kills burst into a small shockwave.",
              procs = { { trigger = "onKill", move = "attack", chance = 0.3,
                  effect = function(ctx) fx.nova(ctx, ctx.x, ctx.y, 22, 6, { 0.6, 0.95, 1 }) end } } },
            { id = "mb_split", tier = 5, name = "Earthsplitter", desc = "Every sweep also cracks the ground ahead.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  fx.line(ctx, ctx.player.x, ctx.player.y, ctx.ax, ctx.ay, 140, 8, ctx.params.damage, { 0.6, 0.95, 1 })
              end } } },
        } },
        -- { name = "Special", ... }, { name = "Body", ... }
    },
    -- the top of the kin branch: this bug's own trick
    signature = { id = "sig_my_bug", name = "Big Horn", desc = "Every 4th sweep is a quake around you.",
        procs = { { trigger = "onAttack", effect = function(ctx, rank, sk)
            if not fx.every(sk, "sig_my_bug", 4) then return end
            fx.nova(ctx, ctx.player.x, ctx.player.y, 60, 12, { 1, 0.8, 0.4 })
        end } } },
}
