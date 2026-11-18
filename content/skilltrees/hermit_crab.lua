-- Hermit crab: the fortress. A bigger crusher claw, a garden of anemones, and a shell that
-- punishes everything that bites it.
local fx = require("src.game.skills").fx

local ANEMONE = { 1, 0.5, 0.75 }

return {
    character = "hermit_crab",
    branches = {
        { name = "Pinches", blurb = "Small claw quick, big claw crushing", color = { 1, 0.6, 0.75 }, nodes = {
            { id = "hc_grip", tier = 1, ranks = 3, name = "Firm Grip", desc = "+12% pinch damage per rank.",
              attack = { damage = { mul = 0.12 } } },
            { id = "hc_crusher", tier = 2, name = "Crusher Claw", desc = "The big claw hits harder and wider.",
              attack = { bigMult = 0.8, bigRadius = 6 } },
            { id = "hc_quick", tier = 3, col = -1, name = "Nimble Claw", desc = "Pinches come 25% faster.",
              attack = { cooldown = { mul = -0.25 } } },
            { id = "hc_smash", tier = 3, col = 1, name = "Shell Smash", desc = "The big claw's crush shakes the ground around it.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  if (ctx.player.attack.combo or 0) ~= 3 then return end
                  local p = ctx.player
                  fx.nova(ctx, p.x + ctx.ax * 20, p.y + ctx.ay * 20, 34, ctx.params.damage, { 1, 0.85, 0.7 }, { knockback = 160 })
              end } } },
            { id = "hc_pin", tier = 4, name = "Pinned Down", desc = "Pinched ants are often held fast for a moment.",
              procs = { { trigger = "onHit", move = "attack", chance = 0.3, effect = function(ctx) fx.slow(ctx.target, 0.05, 1) end } } },
            { id = "hc_king", tier = 5, name = "King Crab", desc = "Every 4th pinch is a colossal crush that throws everything back.",
              empower = { move = "attack", every = 4, mods = { bigRadius = { mul = 1 }, radius = { mul = 1 }, damage = { mul = 1.5 } }, text = "CRUSH!", shake = 0.15 } },
        } },
        { name = "Anemones", blurb = "Plant stinging sea anemones", color = { 1, 0.5, 0.75 }, nodes = {
            { id = "hc_sting", tier = 1, ranks = 3, name = "Nematocysts", desc = "+20% anemone sting damage per rank.",
              secondary = { damage = { mul = 0.2 } } },
            { id = "hc_long", tier = 2, name = "Hardy Polyps", desc = "Anemones live 4 s longer.",
              secondary = { life = 4 } },
            { id = "hc_garden", tier = 3, col = -1, name = "Anemone Garden", desc = "Keep four anemones at once, and plant them faster.",
              secondary = { max = 2, cooldown = { mul = -0.25 } } },
            { id = "hc_giant", tier = 3, col = 1, name = "Giant Anemone", desc = "Anemones reach 60% further.",
              secondary = { radius = { mul = 0.6 } } },
            { id = "hc_rapid", tier = 4, name = "Lashing Tentacles", desc = "Anemones sting twice as often.",
              secondary = { rate = { mul = 1 } } },
            { id = "hc_bloom", tier = 5, name = "Toxic Bloom", desc = "Ants killed near an anemone burst into a cloud of stinging cells.",
              procs = { { trigger = "onKill", chance = 0.3, effect = function(ctx)
                  for _, z in ipairs(ctx.world.hazards.zones) do
                      if z.anemone and (z.x - ctx.x) ^ 2 + (z.y - ctx.y) ^ 2 < (z.r + 10) ^ 2 then
                          fx.nova(ctx, ctx.x, ctx.y, 26, 10, ANEMONE, { slow = { 0.3, 1 } })
                          return
                      end
                  end
              end } } },
        } },
        { name = "Shell", blurb = "Hide in a shell that fights back", color = { 0.95, 0.85, 0.6 }, nodes = {
            { id = "hc_thick", tier = 1, ranks = 3, name = "Bigger Shell", desc = "+2 armor and +8 max HP per rank.",
              stats = { armor = 2, maxHp = 8 } },
            { id = "hc_spiny", tier = 2, name = "Spiny Shell", desc = "Ants biting the shell take 3x the nip.",
              dash = { thorns = { mul = 2 } } },
            { id = "hc_stroll", tier = 3, col = -1, name = "Mobile Home", desc = "Walk at almost full speed inside the shell.",
              dash = { slow = 0.2 } },
            { id = "hc_carry", tier = 3, col = 1, name = "Hitchhiker", desc = "Pulling into the shell drops an anemone at your feet (every 4 s).",
              procs = { { trigger = "onBlock", cooldown = 4, effect = function(ctx)
                  local p = ctx.player
                  local sec = p.secondary
                  sec.type.fire(p, ctx.world, p.aimX, p.aimY, sec.params, p.x, p.y)
              end } } },
            { id = "hc_regen", tier = 4, name = "Tide Pool", desc = "+1 HP regen.",
              stats = { hpRegen = 1 } },
            { id = "hc_fortress", tier = 5, name = "Fortress", desc = "Blocked hits charge the shell; every 6th bursts out in a shockwave.",
              procs = { { trigger = "onBlock", effect = function(ctx)
                  local p = ctx.player
                  p._hcCharge = (p._hcCharge or 0) + 1
                  if p._hcCharge < 6 then return end
                  p._hcCharge = 0
                  fx.explode(ctx, p.x, p.y, 46, 20, { 0.95, 0.85, 0.6 }, { knockback = 260 })
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_hermit_fortress", name = "Coconut Fortress", desc = "Hits that land on you or your shell fire a ring of shell shards back (every 1 s).",
          procs = { { trigger = "onHurt", cooldown = 1, effect = function(ctx)
              local p = ctx.player
              fx.shards(ctx, p.x, p.y, 8, 8, { 0.95, 0.85, 0.6 }, { range = 70 })
          end }, { trigger = "onBlock", cooldown = 1, effect = function(ctx)
              local p = ctx.player
              fx.shards(ctx, p.x, p.y, 8, 8, { 0.95, 0.85, 0.6 }, { range = 70 })
          end } } },
}
