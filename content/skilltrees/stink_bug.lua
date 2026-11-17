-- Stink bug: the alchemist. Bigger, longer clouds, acid pools that spread and rot, and a
-- shield that drives the swarm away.
local fx = require("src.game.skills").fx

local STINK = { 0.7, 0.85, 0.25 }

return {
    character = "stink_bug",
    branches = {
        { name = "Stink Clouds", blurb = "Clouds that poison and weaken", color = { 0.7, 0.85, 0.25 }, nodes = {
            { id = "sb_reek", tier = 1, ranks = 3, name = "Reek", desc = "+20% cloud poison per rank.",
              attack = { damage = { mul = 0.2 } } },
            { id = "sb_big", tier = 2, name = "Billowing", desc = "Clouds are 30% bigger and linger 1 s longer.",
              attack = { radius = { mul = 0.3 }, life = 1 } },
            { id = "sb_fog", tier = 3, col = -1, name = "Fog Bank", desc = "Keep twice as many clouds, puffed out 25% faster.",
              attack = { max = 6, cooldown = { mul = -0.25 } } },
            { id = "sb_fan", tier = 3, col = 1, name = "Triple Puff", desc = "Puff two more clouds out to the sides.",
              fan = { move = "attack", count = 2, spread = 0.9, mult = 0.8 } },
            { id = "sb_choke", tier = 4, name = "Choking Gas", desc = "Ants in the clouds stagger along at half speed.",
              procs = { { trigger = "onTick", effect = function(ctx)
                  local p = ctx.player
                  p._sbT = (p._sbT or 0) + ctx.dt
                  if p._sbT < 0.4 then return end
                  p._sbT = 0
                  local Combat = require("src.game.combat")
                  for _, z in ipairs(ctx.world.hazards.zones) do
                      if z.stink then
                          for _, e in ipairs(Combat.collect(ctx.world, z.x, z.y, z.r)) do fx.slow(e, 0.5, 0.5) end
                      end
                  end
              end } } },
            { id = "sb_ignite", tier = 5, name = "Volatile Fumes", desc = "Ants that die in your stink explode and set off the cloud.",
              procs = { { trigger = "onKill", chance = 0.35, effect = function(ctx)
                  if (ctx.target.poisonT or 0) <= 0 then return end
                  fx.explode(ctx, ctx.x, ctx.y, 26, 12, { 1, 0.85, 0.3 }, { knockback = 120 })
              end } } },
        } },
        { name = "Acid", blurb = "Acid pools that burn and wall", color = { 0.5, 1, 0.3 }, nodes = {
            { id = "sb_caustic", tier = 1, ranks = 3, name = "Caustic", desc = "+20% acid damage per rank.",
              secondary = { damage = { mul = 0.2 } } },
            { id = "sb_wide", tier = 2, name = "Wide Splash", desc = "Pools are 30% wider.",
              secondary = { radius = { mul = 0.3 } } },
            { id = "sb_lasting", tier = 3, col = -1, name = "Slow Evaporation", desc = "Pools last 5 s longer and you can keep four.",
              secondary = { life = 5, max = 1 } },
            { id = "sb_spit", tier = 3, col = 1, name = "Rapid Squirt", desc = "Squirt acid 35% more often, from further away.",
              secondary = { cooldown = { mul = -0.35 }, range = 40 } },
            { id = "sb_corrode", tier = 4, name = "Corrosion", desc = "Acid burns keep eating the ants for 3 s after they leave the pool.",
              procs = { { trigger = "onHit", move = "secondary", effect = function(ctx) fx.poison(ctx.target, 6, 3) end } } },
            { id = "sb_rain", tier = 5, name = "Acid Rain", desc = "Every squirt splits into three pools.",
              procs = { { trigger = "onSpecial", effect = function(ctx)
                  local p = ctx.player
                  local px, py = ctx.px or (p.x + ctx.ax * 80), ctx.py or (p.y + ctx.ay * 80)
                  local sec = p.secondary
                  for s = -1, 1, 2 do
                      sec.type.fire(p, ctx.world, ctx.ax, ctx.ay, sec.params, px - ctx.ay * 45 * s, py + ctx.ax * 45 * s)
                  end
              end } } },
        } },
        { name = "Shield", blurb = "Hunker under a stinking shield", color = { 0.6, 0.55, 0.4 }, nodes = {
            { id = "sb_plates", tier = 1, ranks = 3, name = "Shield Plates", desc = "+1.5 armor and +6 max HP per rank.",
              stats = { armor = 1.5, maxHp = 6 } },
            { id = "sb_hold", tier = 2, name = "Hunker", desc = "The stink shield lasts 0.8 s longer.",
              dash = { time = 0.8 } },
            { id = "sb_ring", tier = 3, col = -1, name = "Wide Stench", desc = "The shield's ring is 50% wider.",
              dash = { radius = { mul = 0.5 } } },
            { id = "sb_twice", tier = 3, col = 1, name = "Second Gland", desc = "Store a second shield.",
              dash = { charges = 1 } },
            { id = "sb_burn", tier = 4, name = "Noxious Blast", desc = "The shield's blast hits three times harder.",
              dash = { damage = { mul = 2 } } },
            { id = "sb_aura", tier = 5, name = "Stench Aura", desc = "While shielded, you leak a stink cloud every half second.",
              procs = { { trigger = "onTick", effect = function(ctx)
                  local p = ctx.player
                  if (p.stinkShieldT or 0) <= 0 then return end
                  p._sbAura = (p._sbAura or 0) + ctx.dt
                  if p._sbAura < 0.5 then return end
                  p._sbAura = 0
                  local a = p.attack
                  a.type.fire(p, ctx.world, math.cos(ctx.world.time * 3), math.sin(ctx.world.time * 3), a.params)
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_stink_marmorated", name = "Lingering Stench", desc = "Kills have a 20% chance to leave a reeking puddle that poisons and slows.",
          procs = { { trigger = "onKill", chance = 0.2, effect = function(ctx)
              fx.patch(ctx, ctx.x, ctx.y, 26, 3, 6, 0.5, { 0.7, 0.85, 0.25 })
          end } } },
}
