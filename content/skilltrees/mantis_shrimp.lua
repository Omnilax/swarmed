-- Mantis Shrimp: the heavyweight. Rapid punches that land like bombs, flurries that never
-- stop, and a charged recoil punch that blows up wherever it lands.
local fx = require("src.game.skills").fx
local Combat = require("src.game.combat")

local CLUB = { 1, 0.5, 0.4 }
local WATER = { 0.8, 0.95, 1 }

return {
    character = "mantis_shrimp",
    branches = {
        { name = "Smashing Club", color = CLUB, nodes = {
            { id = "ms_club", tier = 1, ranks = 3, name = "Dense Club", desc = "+15% punch damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "ms_load", tier = 2, name = "Long Arm", desc = "Punches reach 6 further and throw ants further.",
              attack = { reach = 6, knockback = 80 } },
            { id = "ms_hay", tier = 3, col = -1, name = "Haymaker", desc = "Every 4th punch is a haymaker: 2.5x damage, wider and with a full-size bubble.",
              empower = { move = "attack", every = 4, text = "POW!", shake = 0.1,
                  mods = { damage = { mul = 1.5 }, reach = { mul = 0.4 }, radius = { mul = 0.5 } } } },
            { id = "ms_jab", tier = 3, col = 1, name = "Quick Jab", desc = "Punches recover 35% faster.",
              attack = { cooldown = { mul = -0.35 } } },
            { id = "ms_bubble", tier = 4, name = "Big Bubble", desc = "Cavitation bubbles are 10 wider and hit 50% harder.",
              attack = { bubble = 0.5, radius = 10 } },
            { id = "ms_sonic", tier = 5, name = "Sonic Club", desc = "Every punch also fires a cone of shock pellets that tear through the crowd.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  local p = ctx.player
                  fx.shards(ctx, p.x, p.y, 5, ctx.params.damage * 0.7, WATER, { angle = math.atan2(ctx.ay, ctx.ax), spread = 0.8, range = 110, pierce = 3, speed = 320 })
              end } } },
        } },
        { name = "Flurry", color = { 1, 0.7, 0.45 }, nodes = {
            { id = "ms_fl", tier = 1, ranks = 3, name = "Fast Hands", desc = "+15% flurry damage per rank.",
              secondary = { damage = { mul = 0.15 } } },
            { id = "ms_more", tier = 2, name = "Combo", desc = "4 more punches per flurry.",
              secondary = { punches = 4, time = 0.2 } },
            { id = "ms_upper", tier = 3, col = -1, name = "Uppercut", desc = "The finishing blow hits twice as hard again.",
              secondary = { finisher = 3 } },
            { id = "ms_encore", tier = 3, col = 1, name = "Encore", desc = "Every flurry is followed by a second, weaker one.",
              echo = { move = "secondary", delay = 0.8, mult = 0.6 } },
            { id = "ms_fcd", tier = 4, name = "Stamina", desc = "Flurry recharges 30% faster.",
              secondary = { cooldown = { mul = -0.3 } } },
            { id = "ms_barrage", tier = 5, name = "Bubble Barrage", desc = "Flurry punches leave cavitation bubbles that pop on the ants around them.",
              procs = { { trigger = "onHit", move = "secondary", chance = 0.35, effect = function(ctx)
                  fx.nova(ctx, ctx.target.x, ctx.target.y, 14, 4, WATER)
              end } } },
        } },
        { name = "Recoil", color = { 0.5, 0.85, 0.6 }, nodes = {
            { id = "ms_shell", tier = 1, ranks = 3, name = "Armoured Body", desc = "+10 max HP and +1 armor per rank.",
              stats = { maxHp = 10, armor = 1 } },
            { id = "ms_rp", tier = 2, name = "Spring Loaded", desc = "The recoil punch winds up 30% faster, does +12 damage and reaches 8 further.",
              dash = { damage = 12, reach = 8, charge = { mul = -0.3 } } },
            { id = "ms_double", tier = 3, col = -1, name = "Double Tap", desc = "Store a second recoil punch.",
              dash = { charges = { add = 1, base = 1 } } },
            { id = "ms_rocket", tier = 3, col = 1, name = "Rocket", desc = "The recoil launches you 60 further.",
              dash = { distance = 60 } },
            { id = "ms_counter", tier = 4, name = "Counterpuncher", desc = "After a recoil punch: +30% damage for 2.5 s.",
              procs = { { trigger = "onDash", effect = function(ctx) fx.buff(ctx, "ms_ctr", "damage", 30, 0, 2.5) end } } },
            { id = "ms_landing", tier = 5, name = "Shockwave Landing", desc = "Where the recoil drops you, the water bursts in a cavitation blast.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  fx.explode(ctx, ctx.player.x, ctx.player.y, 44, 20, WATER, { knockback = 220 })
              end } } },
        } },
    },
}
