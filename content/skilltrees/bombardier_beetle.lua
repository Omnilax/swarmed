-- Bombardier Beetle: the chemist. Scalding jets, grenades that turn into cluster bombs and
-- mortar barrages, and a blast-off that rains boiling droplets.
local fx = require("src.game.skills").fx

local HOT = { 1, 0.75, 0.3 }

return {
    character = "bombardier_beetle",
    branches = {
        { name = "Boiling Spray", blurb = "A scalding cone that pierces lines", color = { 1, 0.7, 0.35 }, nodes = {
            { id = "bb_hot", tier = 1, ranks = 3, name = "Hotter Mix", desc = "+15% spray damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "bb_more", tier = 2, name = "Pressurised", desc = "Two more droplets per burst and a longer jet.",
              attack = { drops = 2, range = 15 } },
            { id = "bb_burn", tier = 3, col = -1, name = "Scalding", desc = "Chemical hits often leave ants burning (poison).",
              procs = { { trigger = "onHit", chance = 0.35, effect = function(ctx) fx.poison(ctx.target, 6, 3) end } } },
            { id = "bb_jet", tier = 3, col = 1, name = "Jet Stream", desc = "A tight jet: droplets punch through 2 more ants and hit 20% harder.",
              attack = { pierce = 2, spread = { mul = -0.4 }, damage = { mul = 0.2 } } },
            { id = "bb_pump", tier = 4, name = "Double Pump", desc = "Every burst is followed by a second one.",
              echo = { move = "attack", delay = 0.12, mult = 0.6 } },
            { id = "bb_flood", tier = 5, name = "Caustic Flood", desc = "Ants you kill burst into boiling puddles that burn everything standing in them.",
              procs = { { trigger = "onKill", chance = 0.25, effect = function(ctx)
                  fx.patch(ctx, ctx.x, ctx.y, 18, 3, 6, nil, HOT)
              end } } },
        } },
        { name = "Grenades", blurb = "Lobbed bombs, clusters and fire", color = { 0.75, 0.55, 1 }, nodes = {
            { id = "bb_charge", tier = 1, ranks = 3, name = "Bigger Charge", desc = "+15% grenade damage and a bigger blast per rank.",
              secondary = { damage = { mul = 0.15 }, radius = 4 } },
            { id = "bb_cool", tier = 2, name = "Quick Mix", desc = "Grenades recharge 30% faster.",
              secondary = { cooldown = { mul = -0.3 } } },
            { id = "bb_cluster", tier = 3, col = -1, name = "Cluster Bomb", desc = "The blast scatters 4 bomblets that pop around it.",
              secondary = { cluster = 4 } },
            { id = "bb_napalm", tier = 3, col = 1, name = "Napalm", desc = "Grenades leave a pool of boiling chemicals.",
              secondary = { burn = { set = { 8, 4 } } } },
            { id = "bb_pair", tier = 4, name = "Two-Chamber Throw", desc = "Lob a second grenade beside the first.",
              fan = { move = "secondary", count = 1, spread = 0.45, mult = 0.8 } },
            { id = "bb_mortar", tier = 5, name = "Mortar Barrage", desc = "After every grenade, three more shells rain down around the target.",
              procs = { { trigger = "onSpecial", effect = function(ctx)
                  local p = ctx.player
                  local tx, ty = ctx.px or p.x + ctx.ax * 100, ctx.py or p.y + ctx.ay * 100
                  local dmg, r = ctx.params.damage * 0.6, (ctx.params.radius or 42) * 0.8
                  for k = 1, 3 do
                      p:after(0.5 + k * 0.22, function(pl, w)
                          local a, d = love.math.random() * math.pi * 2, 20 + love.math.random() * 40
                          fx.explode(fx.ctx(w), tx + math.cos(a) * d, ty + math.sin(a) * d, r, dmg, HOT)
                      end)
                  end
              end } } },
        } },
        { name = "Blast-off", blurb = "Blast yourself through the swarm", color = { 0.5, 0.85, 1 }, nodes = {
            { id = "bb_shell", tier = 1, ranks = 3, name = "Heat Shield", desc = "+8 max HP and +1 armor per rank.",
              stats = { maxHp = 8, armor = 1 } },
            { id = "bb_boom", tier = 2, name = "Bigger Bang", desc = "Blast-off hits harder and wider.",
              dash = { damage = 10, radius = 10 } },
            { id = "bb_twin", tier = 3, col = -1, name = "Twin Chambers", desc = "Store a second blast-off.",
              dash = { charges = 1 } },
            { id = "bb_rocket", tier = 3, col = 1, name = "Rocket Jump", desc = "Fly much further and explode again where you land.",
              dash = { distance = 50 },
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  fx.explode(ctx, ctx.player.x, ctx.player.y, 30, 12, HOT)
              end } } },
            { id = "bb_reactor", tier = 4, name = "Fast Reactor", desc = "Blast-off recharges 0.3 s faster.",
              stats = { dashCooldown = -0.3 } },
            { id = "bb_chain", tier = 5, name = "Chain Reaction", desc = "Blast-off sprays a ring of boiling droplets and supercharges you: +30% attack speed for 2.5 s.",
              procs = { { trigger = "onDash", effect = function(ctx)
                  fx.shards(ctx, ctx.player.x, ctx.player.y, 10, 8, HOT, { range = 100, pierce = 2 })
                  fx.buff(ctx, "bb_chain", "attackSpeed", 30, 0, 2.5)
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_bombardier_boil", name = "Boiling Point", desc = "Every 4th spray erupts at 100 degrees: double damage, wider and longer.",
          empower = { move = "attack", every = 4, text = "BOIL!", shake = 0.1,
              mods = { damage = { mul = 1 }, spread = { mul = 0.5 }, range = { mul = 0.3 } } } },
}
