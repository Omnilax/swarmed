-- Millipede: the toxic fortress. Glands that drench everything touching it, a coil that turns
-- into a bomb, and a ball roll that leaves poison behind.
local fx = require("src.game.skills").fx
local Combat = require("src.game.combat")

local TOXIN = { 0.95, 0.85, 0.35 }

return {
    character = "millipede",
    branches = {
        { name = "Stink Glands", blurb = "Poison every ant that touches you", color = TOXIN, nodes = {
            { id = "mp_glands", tier = 1, ranks = 3, name = "Potent Glands", desc = "+15% gland damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "mp_all", tier = 2, name = "Every Ring", desc = "Every ring of the body puffs toxin, not every other one.",
              attack = { every = { set = 1 } } },
            { id = "mp_caustic", tier = 3, col = -1, name = "Benzoquinone", desc = "The poison burns twice as fast.",
              attack = { ["poison.1"] = { mul = 1 } } },
            { id = "mp_wide", tier = 3, col = 1, name = "Wide Puffs", desc = "Each gland reaches 6 further.",
              attack = { radius = 6 } },
            { id = "mp_fast", tier = 4, name = "Leaky", desc = "Glands puff 25% more often.",
              attack = { cooldown = { mul = -0.25 } } },
            { id = "mp_cyanide", tier = 5, name = "Cyanide", desc = "Ants killed by your glands leave a cloud of cyanide that poisons ants walking through.",
              procs = { { trigger = "onKill", move = "attack", chance = 0.35, effect = function(ctx)
                  fx.patch(ctx, ctx.x, ctx.y, 22, 3, 8, 0.7, TOXIN)
              end } } },
        } },
        { name = "Coil", blurb = "Coil up, then burst out", color = { 0.8, 0.45, 0.35 }, nodes = {
            { id = "mp_burst", tier = 1, ranks = 3, name = "Stored Toxin", desc = "+15% uncoil burst damage per rank.",
              secondary = { damage = { mul = 0.15 } } },
            { id = "mp_armor", tier = 2, name = "Tight Coil", desc = "Coiled you take 93% less damage and ooze twice as hard.",
              secondary = { guard = -0.08, ooze = 3 } },
            { id = "mp_spring", tier = 3, col = -1, name = "Spring Uncoil", desc = "The burst reaches 40 further.",
              secondary = { radius = 40 } },
            { id = "mp_quick", tier = 3, col = 1, name = "Quick Curl", desc = "The burst is at full power after 1 s of coiling (was 2).",
              secondary = { time = -1 } },
            { id = "mp_ccd", tier = 4, name = "Restless", desc = "Coil recharges 30% faster.",
              secondary = { cooldown = { mul = -0.3 } } },
            { id = "mp_thorns", tier = 5, name = "Toxic Shell", desc = "While coiled, every bite you take squirts toxin back over the biter and everything near it.",
              procs = { { trigger = "onHurt", cooldown = 0.25, effect = function(ctx)
                  local p = ctx.player
                  if not p.coil then return end
                  fx.nova(ctx, p.x, p.y, 26, 6, TOXIN, { poison = { 6, 3 } })
              end } } },
        } },
        { name = "Ball Roll", blurb = "Roll through them as a ball", color = { 0.6, 0.45, 0.4 }, nodes = {
            { id = "mp_shell", tier = 1, ranks = 3, name = "Chitin Rings", desc = "+15 max HP and +1 armor per rank.",
              stats = { maxHp = 15, armor = 1 } },
            { id = "mp_heavy", tier = 2, name = "Heavy Ball", desc = "Bumping into ants does +6 damage.",
              dash = { damage = 6 } },
            { id = "mp_long", tier = 3, col = -1, name = "Long Roll", desc = "Roll 1.5 s longer before you need a breather.",
              dash = { stamina = 1.5 } },
            { id = "mp_double", tier = 3, col = 1, name = "Downhill", desc = "Roll 20% faster and get your breath back 30% sooner.",
              dash = { speed = 0.3, regen = { mul = 0.3 } } },
            { id = "mp_brace", tier = 4, name = "Momentum", desc = "Curling up gives +5 armor for 2.5 s.",
              procs = { { trigger = "onDash", effect = function(ctx) fx.buff(ctx, "mp_brace", "armor", 5, 0, 2.5) end } } },
            { id = "mp_trail", tier = 5, name = "Toxic Trail", desc = "Rolling leaves a trail of toxic slime behind you.",
              procs = { { trigger = "onTick", cooldown = 0.08, effect = function(ctx)
                  local p = ctx.player
                  if not p.holdMode then return end
                  fx.patch(ctx, p.x, p.y, 14, 2.5, 6, 0.6, TOXIN)
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_milli_arthro", name = "Arthropleura", desc = "Grow like the giant of old: +20% max HP, +3 armor, and ants that hit you get spiked.",
          stats = { armor = 3 }, statsMult = { maxHp = 0.2 },
          procs = { { trigger = "onHurt", cooldown = 0.5, effect = function(ctx)
              local p = ctx.player
              fx.nova(ctx, p.x, p.y, 28, 12, { 0.8, 0.45, 0.35 }, { knockback = 120 })
          end } } },
}
