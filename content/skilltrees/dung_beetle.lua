-- Dung beetle: the bowler. A ball that grows faster and bigger, bashes that scatter dung,
-- throws that burst, split or come rolling back, and a body built for pushing.
local fx = require("src.game.skills").fx

local DUNG = { 0.75, 0.55, 0.3 }

return {
    character = "dung_beetle",
    branches = {
        { name = "Ball Bash", color = { 0.85, 0.65, 0.4 }, nodes = {
            { id = "db_heavy", tier = 1, ranks = 3, name = "Packed Dung", desc = "+12% bash damage per rank.",
              attack = { damage = { mul = 0.12 } } },
            { id = "db_sticky", tier = 2, name = "Sticky Ball", desc = "Squashed ants make the ball grow twice as fast.",
              attack = { killGrow = { mul = 1 } } },
            { id = "db_quick", tier = 3, col = -1, name = "Quick Shoves", desc = "Bash 25% faster.",
              attack = { cooldown = { mul = -0.25 } } },
            { id = "db_weight", tier = 3, col = 1, name = "Dead Weight", desc = "Big balls hit much harder (damage grows faster with size).",
              attack = { perSize = 0.15 } },
            { id = "db_spatter", tier = 4, name = "Spatter", desc = "Bashes fling clods of dung that slow ants.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  local p = ctx.player
                  fx.shards(ctx, p.x + ctx.ax * 20, p.y + ctx.ay * 20, 3, 4, DUNG, { angle = math.atan2(ctx.ay, ctx.ax), spread = 1, speed = 200, range = 60, slow = { 0.5, 1.5 } })
              end } } },
            { id = "db_avalanche", tier = 5, name = "Avalanche", desc = "Every 3rd bash slams the ball down in a shockwave as wide as the ball is big.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  local p = ctx.player
                  p._dbAv = (p._dbAv or 0) + 1
                  if p._dbAv % 3 ~= 0 or not p.dung then return end
                  local r = p.dung.r
                  fx.explode(ctx, p.x + ctx.ax * (r + 16), p.y + ctx.ay * (r + 16), 18 + r * 3, ctx.params.damage * (1 + r / 6), DUNG, { knockback = 200 })
              end } } },
        } },
        { name = "Ball Hurl", color = { 0.7, 0.5, 0.25 }, nodes = {
            { id = "db_roll", tier = 1, ranks = 3, name = "Roller", desc = "+15% hurl damage and the ball grows 25% faster as you roll it, per rank.",
              secondary = { damage = { mul = 0.15 }, grow = { mul = 0.25 } } },
            { id = "db_huge", tier = 2, name = "Huge Ball", desc = "The ball can grow 30% bigger.",
              secondary = { maxSize = 6 } },
            { id = "db_burst", tier = 3, col = -1, name = "Dung Bomb", desc = "Even a medium ball bursts where it stops.",
              secondary = { burstSize = -4 } },
            { id = "db_fast", tier = 3, col = 1, name = "Kickoff", desc = "The ball flies 40% faster and recharges faster.",
              secondary = { speed = { mul = 0.4 }, cooldown = { mul = -0.25 } } },
            { id = "db_head", tier = 4, name = "Head Start", desc = "A fresh ball starts out bigger.",
              secondary = { minSize = 2 } },
            { id = "db_scatter", tier = 5, name = "Scatter Shot", desc = "Thrown balls shed chunks of dung that fly off and bowl ants over too.",
              procs = { { trigger = "onSpecial", effect = function(ctx)
                  local p = ctx.player
                  local a = math.atan2(ctx.ay, ctx.ax)
                  fx.shards(ctx, p.x, p.y, 4, ctx.params.damage * 0.5, DUNG, { angle = a, spread = 0.8, speed = 280, range = 150, pierce = 4, knockback = 140 })
              end } } },
        } },
        { name = "Strong Back", color = { 0.6, 0.75, 1 }, nodes = {
            { id = "db_tough", tier = 1, ranks = 3, name = "Tough Shell", desc = "+1.5 armor and +8 max HP per rank.",
              stats = { armor = 1.5, maxHp = 8 } },
            { id = "db_push", tier = 2, name = "Strongest Insect", desc = "+30% knockback, and a big ball slows you down a third less.",
              stats = { knockback = 30 }, secondary = { slowMax = { mul = -0.33 } } },
            { id = "db_star", tier = 3, col = -1, name = "Star Navigator", desc = "Ride 1.5 s longer, and climb on with a smaller ball.",
              dash = { stamina = 1.5, minBall = -3 } },
            { id = "db_bowl", tier = 3, col = 1, name = "Bowling Ride", desc = "Riding hits ants twice as hard and throws them further.",
              dash = { damage = { mul = 1 }, knockback = 80 } },
            { id = "db_regen", tier = 4, name = "Nourished", desc = "+0.8 HP regen.",
              stats = { hpRegen = 0.8 } },
            { id = "db_stampede", tier = 5, name = "Stampede", desc = "Riding grows the ball faster and leaves a trail of slowing dung behind you.",
              procs = { { trigger = "onTick", cooldown = 0.15, effect = function(ctx)
                  local p = ctx.player
                  if not (p.dung and p.dung.ride) then return end
                  p.dung.r = math.min(p.dung.r + 0.08, 26)
                  fx.patch(ctx, p.x, p.y, 16, 2.5, 4, 0.5, DUNG)
              end } } },
        } },
    },
}
