-- Dragonfly: the hunter. Strafes that seize more ants, longer flights and a deadlier landing,
-- bombs that hit harder, and a wing gust that holds the ground while it rests.
local fx = require("src.game.skills").fx

local SKY = { 0.5, 0.85, 1 }

return {
    character = "dragonfly",
    branches = {
        { name = "Strikes", blurb = "Diving strikes from the air", color = { 0.5, 0.85, 1 }, nodes = {
            { id = "df_spines", tier = 1, ranks = 3, name = "Spiny Legs", desc = "+12% strike damage per rank.",
              attack = { damage = { mul = 0.12 } } },
            { id = "df_basket", tier = 2, name = "Long Dive", desc = "Diving lunges go 30% further.",
              attack = { reach = { mul = 0.3 } } },
            { id = "df_gale", tier = 3, col = -1, name = "Gale Wings", desc = "The ground sweep reaches further and hits much harder.",
              attack = { gust = 16, gustMult = 0.4, knockback = 40 } },
            { id = "df_hawk", tier = 3, col = 1, name = "Hawker", desc = "Diving lunges are 30% faster.",
              attack = { lungeSpeed = { mul = 0.3 } } },
            { id = "df_quick", tier = 4, name = "Quick Wings", desc = "Strike 20% faster.",
              attack = { cooldown = { mul = -0.2 } } },
            { id = "df_dive", tier = 5, name = "Death From Above", desc = "In the air, every strike ends in a dive that blasts the ants below.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  local p = ctx.player
                  if not p.airborne then return end
                  fx.nova(ctx, p.x + ctx.ax * 26, p.y + ctx.ay * 26, 26, ctx.params.damage, SKY, { knockback = 140 })
              end } } },
        } },
        { name = "Flight", blurb = "Stay up longer, fly faster", color = { 0.75, 0.95, 1 }, nodes = {
            { id = "df_long", tier = 1, ranks = 3, name = "Endurance", desc = "+1 s of flight per rank.",
              dash = { stamina = 1 } },
            { id = "df_rest", tier = 2, name = "Quick Rest", desc = "Flight recharges 50% faster on the ground.",
              dash = { regen = 0.5 } },
            { id = "df_draft", tier = 3, col = -1, name = "Downdraft", desc = "Landing blasts much harder and wider.",
              dash = { downdraft = 14, radius = 20 } },
            { id = "df_glide", tier = 3, col = 1, name = "Glider", desc = "+20% speed.",
              statsMult = { moveSpeed = 0.2 } },
            { id = "df_takeoff", tier = 4, name = "Updraft", desc = "Taking off throws the ants around you back.",
              procs = { { trigger = "onDash", effect = function(ctx)
                  local p = ctx.player
                  fx.nova(ctx, p.x, p.y, 36, 6, SKY, { knockback = 200 })
              end } } },
            { id = "df_storm", tier = 5, name = "Swarm Storm", desc = "While flying, a cyclone of wind blades whirls around you.",
              procs = { { trigger = "onTick", effect = function(ctx)
                  local p = ctx.player
                  if not p.airborne then return end
                  p._dfStorm = (p._dfStorm or 0) + ctx.dt
                  if p._dfStorm < 0.35 then return end
                  p._dfStorm = 0
                  local a = ctx.world.time * 5
                  fx.shards(ctx, p.x, p.y, 2, 5, SKY, { angle = a, spread = math.pi, speed = 200, range = 50, pierce = 2 })
              end } } },
        } },
        { name = "Compound Eyes", blurb = "Eyes that see every ant", color = { 0.4, 0.8, 0.5 }, nodes = {
            { id = "df_eyes", tier = 1, ranks = 3, name = "Compound Eyes", desc = "+4% crit chance and +4% dodge per rank.",
              stats = { critChance = 4, dodge = 4 } },
            { id = "df_body", tier = 2, name = "Sturdy Thorax", desc = "+15 max HP.",
              stats = { maxHp = 15 } },
            { id = "df_dart", tier = 3, col = -1, name = "Bombardier", desc = "Dropped ants blast 60% harder and wider.",
              secondary = { bomb = { mul = 0.6 }, radius = 10 } },
            { id = "df_razor", tier = 3, col = 1, name = "Quick Talons", desc = "Snatch again 40% sooner, from further away.",
              secondary = { cooldown = { mul = -0.4 }, reach = 10 } },
            { id = "df_focus", tier = 4, name = "Hunter's Focus", desc = "+40% crit damage.",
              stats = { critDamage = 40 } },
            { id = "df_mirage", tier = 5, name = "Mirage", desc = "Dodging leaves a blur that bursts into wind blades.",
              procs = { { trigger = "onDodge", effect = function(ctx)
                  local p = ctx.player
                  fx.shards(ctx, p.x, p.y, 8, 10, SKY, { speed = 240, range = 80, pierce = 2 })
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_dragon_apex", name = "Apex Hawker", desc = "Every 5th diving strike drops a downdraft that blasts the ants below.",
          procs = { { trigger = "onAttack", effect = function(ctx, rank, sk)
              if not fx.every(sk, "sig_dragon", 5) then return end
              ctx.player:after(0.2, function(pl, w)
                  fx.explode(fx.ctx(w), pl.x, pl.y, 52, 24, { 0.5, 0.85, 1 })
              end)
          end } } },
}
