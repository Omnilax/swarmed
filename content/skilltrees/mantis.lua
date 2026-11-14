-- Mantis: the reaper. Scythes that throw blades of wind, a snatch that hurls ants like bombs,
-- and an ambush stance that turns stillness into crits.
local fx = require("src.game.skills").fx

local LEAF = { 0.75, 1, 0.5 }

return {
    character = "mantis",
    branches = {
        { name = "Twin Scythes", color = { 1, 0.7, 0.35 }, nodes = {
            { id = "mt_edge", tier = 1, ranks = 3, name = "Honed Edge", desc = "+15% slash damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "mt_reach", tier = 2, name = "Long Scythes", desc = "Slashes reach further and wider.",
              attack = { radius = 8, arc = 0.3 } },
            { id = "mt_flurry", tier = 3, col = -1, name = "Flurry", desc = "Each pair of slashes is followed by a second pair.",
              echo = { move = "attack", delay = 0.18, mult = 0.6 } },
            { id = "mt_sever", tier = 3, col = 1, name = "Sever", desc = "+10% crit chance and +40% crit damage.",
              stats = { critChance = 10, critDamage = 40 } },
            { id = "mt_wind", tier = 4, name = "Wind Blades", desc = "Every slash throws three blades of wind that cut through the crowd.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  local p = ctx.player
                  fx.shards(ctx, p.x, p.y, 3, ctx.params.damage * 0.5, LEAF, { angle = math.atan2(ctx.ay, ctx.ax), spread = 0.5,
                      speed = 300, range = 120, pierce = 3 })
              end } } },
            { id = "mt_reaper", tier = 5, name = "Reaper", desc = "Every 4th attack is a full-circle reap, and kills carry the cut on to two more ants.",
              empower = { move = "attack", every = 4, text = "REAP!", color = LEAF, mods = { arc = { set = 6.3 }, radius = { mul = 0.3 } } },
              procs = { { trigger = "onKill", move = "attack", chance = 0.35, effect = function(ctx)
                  fx.chain(ctx, ctx.target, 2, 40, 8, LEAF)
              end } } },
        } },
        { name = "Snatch", color = { 0.75, 0.55, 1 }, nodes = {
            { id = "mt_grip", tier = 1, ranks = 3, name = "Raptorial Grip", desc = "Snatch one more ant and hit 10% harder per rank.",
              secondary = { grabs = 1, damage = { mul = 0.1 } } },
            { id = "mt_feast", tier = 2, name = "Feast", desc = "Munching heals 2 more and bites 3 harder.",
              secondary = { heal = 2, bite = 3 } },
            { id = "mt_hurl", tier = 3, col = -1, name = "Hurl", desc = "Flung ants land 60% harder in a 40% bigger crash.",
              throw = { landMul = 0.6, radiusMul = 0.4 } },
            { id = "mt_quick", tier = 3, col = 1, name = "Quick Snatch", desc = "Snatch recharges 35% faster and reaches further.",
              secondary = { cooldown = { mul = -0.35 }, reach = 12 } },
            { id = "mt_spikes", tier = 4, name = "Spiked Forelegs", desc = "Every snatch also rakes everything in front of you.",
              procs = { { trigger = "onSpecial", effect = function(ctx)
                  local p = ctx.player
                  fx.line(ctx, p.x, p.y, ctx.ax, ctx.ay, 60, 10, ctx.params.damage * 0.6, LEAF)
              end } } },
            { id = "mt_devour", tier = 5, name = "Living Bombs", desc = "Flung ants burst in a big blast when they land, and every landing heals you.",
              throw = { onLand = function(w, x, y)
                  local c = fx.ctx(w)
                  fx.explode(c, x, y, 40, 20, LEAF)
                  fx.heal(c, 2)
              end } },
        } },
        { name = "Ambush", color = { 0.5, 0.85, 1 }, nodes = {
            { id = "mt_legs", tier = 1, ranks = 3, name = "Light Step", desc = "+6 speed and +2% dodge per rank.",
              stats = { moveSpeed = 6, dodge = 2 } },
            { id = "mt_leap", tier = 2, name = "Wide Sway", desc = "Sways go further, and the sure crit lasts longer.",
              dash = { distance = 22, primed = 0.6 } },
            { id = "mt_third", tier = 3, col = -1, name = "Third Sway", desc = "Store a third sway.",
              dash = { charges = 1 } },
            { id = "mt_strike", tier = 3, col = 1, name = "Ambush Strike", desc = "Ending a sway slashes everything around you.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  fx.nova(ctx, ctx.player.x, ctx.player.y, 34, 12, LEAF, { knockback = 120 })
              end } } },
            { id = "mt_pray", tier = 4, name = "Praying Stance", desc = "Standing still for a moment readies a strike: +25% crit chance.",
              procs = { { trigger = "onTick", cooldown = 0.5, condition = function(ctx) return not ctx.player.moving end,
                  effect = function(ctx) fx.buff(ctx, "mt_pray", "critChance", 25, 0, 1) end } } },
            { id = "mt_orchid", tier = 5, name = "Orchid Mantis", desc = "Every leap makes you deadlier: +30% damage and attack speed for 2.5 s.",
              procs = { { trigger = "onDash", effect = function(ctx)
                  fx.buff(ctx, "mt_orchid_dmg", "damage", 30, 0, 2.5)
                  fx.buff(ctx, "mt_orchid_as", "attackSpeed", 30, 0, 2.5)
              end } } },
        } },
    },
}
