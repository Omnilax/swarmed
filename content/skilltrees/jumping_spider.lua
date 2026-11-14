-- Jumping Spider: the acrobat. Pounces that chain from ant to ant, silk lines that bind, and
-- reflexes that turn every dodge into a counter.
local fx = require("src.game.skills").fx

local SILK = { 0.6, 1, 0.9 }

return {
    character = "jumping_spider",
    branches = {
        { name = "Pounce", color = { 1, 0.7, 0.35 }, nodes = {
            { id = "js_leap", tier = 1, ranks = 3, name = "Strong Leap", desc = "+15% pounce damage and a bigger landing per rank.",
              attack = { damage = { mul = 0.15 }, radius = 3 } },
            { id = "js_far", tier = 2, name = "Long Jump", desc = "Pounce on ants from much further away.",
              attack = { distance = 25 } },
            { id = "js_chain", tier = 3, col = -1, name = "Chain Pounce", desc = "Every pounce springs straight into a second one onto the next ant.",
              echo = { move = "attack", delay = "dash", mult = 0.7 } },
            { id = "js_precise", tier = 3, col = 1, name = "Precision", desc = "+12% crit chance and +30% crit damage.",
              stats = { critChance = 12, critDamage = 30 } },
            { id = "js_shrapnel", tier = 4, name = "Silk Shrapnel", desc = "Landings throw out a ring of sticky silk that slows ants.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  local dmg = ctx.params.damage * 0.4
                  ctx.player:after(ctx.player.dashT + 0.01, function(p, w)
                      fx.shards(fx.ctx(w), p.x, p.y, 6, dmg, SILK, { range = 60, slow = { 0.4, 1.5 } })
                  end)
              end } } },
            { id = "js_triple", tier = 5, name = "Ricochet", desc = "Two more bounces after every pounce: hop across the whole crowd.",
              echo = { move = "attack", delay = "dash", times = 2, mult = 0.6 } },
        } },
        { name = "Dragline", color = { 0.75, 0.55, 1 }, nodes = {
            { id = "js_silk", tier = 1, ranks = 3, name = "Strong Silk", desc = "+15% yank damage per rank.",
              secondary = { damage = { mul = 0.15 } } },
            { id = "js_range", tier = 2, name = "Long Line", desc = "Yank ants from much further away.",
              secondary = { range = 40 } },
            { id = "js_reel", tier = 3, col = -1, name = "Quick Reel", desc = "Dragline recharges 35% faster.",
              secondary = { cooldown = { mul = -0.35 } } },
            { id = "js_fangs", tier = 3, col = 1, name = "Venom Fangs", desc = "The bite at the end pumps in 60% more venom.",
              secondary = { ["poison.1"] = { mul = 0.6 } } },
            { id = "js_double", tier = 4, name = "Double Line", desc = "Fire a second line once the first ant is reeled in.",
              echo = { move = "secondary", delay = 0.6, mult = 0.8 } },
            { id = "js_bola", tier = 5, name = "Silk Bolas", desc = "Every line also flings a fan of silk bolas that pin ants in place.",
              procs = { { trigger = "onSpecial", effect = function(ctx)
                  local p = ctx.player
                  fx.shards(ctx, p.x, p.y, 5, ctx.params.damage * 0.4, SILK, { angle = math.atan2(ctx.ay, ctx.ax), spread = 0.8,
                      range = 130, speed = 260, pierce = 2, slow = { 0.05, 2 } })
              end } } },
        } },
        { name = "Agility", color = { 0.5, 0.85, 1 }, nodes = {
            { id = "js_eyes", tier = 1, ranks = 3, name = "Big Eyes", desc = "+4% crit chance and +2% dodge per rank.",
              stats = { critChance = 4, dodge = 2 } },
            { id = "js_spring", tier = 2, name = "Spring Legs", desc = "Jumps go further and higher, and the safety line holds 1 s longer.",
              dash = { distance = 25, hop = 6, line = 1 } },
            { id = "js_double_jump", tier = 3, col = -1, name = "Double Jump", desc = "Store a second jump.",
              dash = { charges = 1 } },
            { id = "js_drop", tier = 3, col = 1, name = "Drop Strike", desc = "Jumps land with a hit on everything below.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  fx.nova(ctx, ctx.player.x, ctx.player.y, 30, 12, SILK, { knockback = 140 })
              end } } },
            { id = "js_focus", tier = 4, name = "Hunter's Focus", desc = "After a jump: +30% crit chance for 1.5 s.",
              procs = { { trigger = "onDash", effect = function(ctx) fx.buff(ctx, "js_focus", "critChance", 30, 0, 1.5) end } } },
            { id = "js_sense", tier = 5, name = "Spider-Sense", desc = "+10% dodge, and every dodge counters with a burst around you.",
              stats = { dodge = 10 },
              procs = { { trigger = "onDodge", cooldown = 0.5, effect = function(ctx)
                  fx.nova(ctx, ctx.player.x, ctx.player.y, 34, 16, SILK, { knockback = 180 })
                  fx.say(ctx, "COUNTER", SILK)
              end } } },
        } },
    },
}
