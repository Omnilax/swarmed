-- Pistol Shrimp: the sniper. A water gun that turns into a ricochet storm, a snap shot that
-- blinds what it hits, and a cloak that leaves traps behind.
local fx = require("src.game.skills").fx
local Combat = require("src.game.combat")

local WATER = { 0.6, 0.85, 1 }
local FLASH = { 1, 1, 0.8 }

return {
    character = "pistol_shrimp",
    branches = {
        { name = "Water Jet", blurb = "Rapid water pellets", color = WATER, nodes = {
            { id = "ps_jet", tier = 1, ranks = 3, name = "Pressure", desc = "+15% water jet damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "ps_pop", tier = 2, name = "Bubbly", desc = "Every 3rd pellet pops (was every 6th).",
              attack = { popEvery = { set = 3 } } },
            { id = "ps_twin", tier = 3, col = -1, name = "Twin Barrel", desc = "Fires two more pellets in a narrow fan.",
              fan = { move = "attack", count = 2, spread = 0.2, mult = 0.6 } },
            { id = "ps_pierce", tier = 3, col = 1, name = "High Pressure", desc = "Pellets go 60 further and pierce one more ant.",
              attack = { range = 60, pierce = 1 } },
            { id = "ps_eye", tier = 4, name = "Steady Aim", desc = "+10% crit chance and +30% crit damage.",
              stats = { critChance = 10, critDamage = 30 } },
            { id = "ps_ricochet", tier = 5, name = "Ricochet", desc = "Pellets that hit sometimes splash on, jumping between 3 nearby ants.",
              procs = { { trigger = "onHit", move = "attack", chance = 0.12, effect = function(ctx)
                  fx.chain(ctx, ctx.target, 3, 50, ctx.params and ctx.params.damage * 2 or 6, WATER)
              end } } },
        } },
        { name = "Snap Shot", blurb = "One sniper snap through a line", color = FLASH, nodes = {
            { id = "ps_snap", tier = 1, ranks = 3, name = "Bigger Claw", desc = "+15% snap shot damage per rank.",
              secondary = { damage = { mul = 0.15 } } },
            { id = "ps_scd", tier = 2, name = "Hair Trigger", desc = "Snap shot recharges 25% faster.",
              secondary = { cooldown = { mul = -0.25 } } },
            { id = "ps_scatter", tier = 3, col = -1, name = "Scatter Snap", desc = "Two more jets fan out beside the main one.",
              fan = { move = "secondary", count = 2, spread = 0.25, mult = 0.6 } },
            { id = "ps_over", tier = 3, col = 1, name = "Overpressure", desc = "The flash at the end is 20 wider and the jet 4 thicker.",
              secondary = { radius = 20, width = 4 } },
            { id = "ps_ambush", tier = 4, name = "Assassin", desc = "Snap shots from the cloak hit 3x (was 2x).",
              secondary = { cloakMult = 1 } },
            { id = "ps_sono", tier = 5, name = "Sonoluminescence", desc = "The flash where the jet ends is blinding: every ant near it is stunned for 1.5 s.",
              procs = { { trigger = "onSpecial", effect = function(ctx)
                  local p = ctx.player
                  local range = (ctx.params.range or 300) * (1 + p.stats:get("area") / 200)
                  fx.nova(ctx, p.x + ctx.ax * range, p.y + ctx.ay * range, 50, 4, FLASH, { stun = 1.5 })
              end } } },
        } },
        { name = "Cloak", blurb = "Vanish and strike from nowhere", color = { 0.7, 0.8, 0.95 }, nodes = {
            { id = "ps_quick", tier = 1, ranks = 3, name = "Darting", desc = "+5% speed and +4% dodge per rank.",
              statsMult = { moveSpeed = 0.05 }, stats = { dodge = 4 } },
            { id = "ps_long", tier = 2, name = "Lingering Cloak", desc = "The cloak lasts 1 s longer.",
              dash = { time = 1 } },
            { id = "ps_ghost", tier = 3, col = -1, name = "Ghost", desc = "Store a second cloak.",
              dash = { charges = { add = 1, base = 1 } } },
            { id = "ps_shimmer", tier = 3, col = 1, name = "Shimmer", desc = "Cloaking gives +50% crit chance for 3 s.",
              procs = { { trigger = "onDash", effect = function(ctx) fx.buff(ctx, "ps_shim", "critChance", 50, 0, 3) end } } },
            { id = "ps_fast", tier = 4, name = "Slipstream", desc = "Move 30% faster again while cloaked.",
              dash = { speed = 0.3 } },
            { id = "ps_decoy", tier = 5, name = "Decoy Bubble", desc = "Cloaking leaves a bubble behind that sucks in nearby ants, then bursts.",
              procs = { { trigger = "onDash", effect = function(ctx)
                  local x, y = ctx.player.x, ctx.player.y
                  ctx.world:addFx({ kind = "ring", x = x, y = y, r = 30, life = 1, color = WATER })
                  ctx.player:after(0.5, function() fx.pull(ctx, x, y, 80, 260) end)
                  ctx.player:after(1, function() fx.explode(ctx, x, y, 46, 22, WATER) end)
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_pistol_sonic", name = "Sonic Snap", desc = "Every snap shot's shockwave also blasts the ants around you away.",
          procs = { { trigger = "onSpecial", effect = function(ctx)
              local p = ctx.player
              fx.nova(ctx, p.x, p.y, 50, 15, { 0.85, 0.95, 1 }, { knockback = 240 })
          end } } },
}
