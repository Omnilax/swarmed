-- Orb Weaver: the trapper. Webs that multiply, silk walls that turn into electric fences, and a
-- grapple that lands in a net.
local fx = require("src.game.skills").fx

local SILK = { 1, 1, 0.95 }
local SPARK = { 0.7, 0.9, 1 }

return {
    character = "orb_weaver",
    branches = {
        { name = "Web Shot", blurb = "Webs that slow the crowd", color = { 1, 0.7, 0.35 }, nodes = {
            { id = "ow_sticky", tier = 1, ranks = 3, name = "Sticky Silk", desc = "+15% web damage and bigger webs per rank.",
              attack = { damage = { mul = 0.15 }, radius = 3 } },
            { id = "ow_glue", tier = 2, name = "Gluey Silk", desc = "Webs hold ants much tighter and last 2 s longer.",
              attack = { slow = { mul = -0.4 }, duration = 2 } },
            { id = "ow_triple", tier = 3, col = -1, name = "Triple Shot", desc = "Fire two more webs fanned out beside the first.",
              fan = { move = "attack", count = 2, spread = 0.35, mult = 0.6 } },
            { id = "ow_bolas", tier = 3, col = 1, name = "Heavy Bolas", desc = "Webs fly much further and hit 30% harder.",
              attack = { range = 40, damage = { mul = 0.3 } } },
            { id = "ow_wrap", tier = 4, name = "Wrap", desc = "Ants you kill are often wrapped up, leaving a web where they fall.",
              procs = { { trigger = "onKill", chance = 0.2, effect = function(ctx) fx.web(ctx, ctx.x, ctx.y, 18, 3, 0.3) end } } },
            { id = "ow_storm", tier = 5, name = "Web Storm", desc = "Every web shot also fires webs at three more ants nearby.",
              procs = { { trigger = "onAttack", effect = function(ctx, rank, sk)
                  local p = ctx.player
                  local q = require("src.game.skills").scaled(ctx.params, 0.5)
                  sk.replaying = true
                  for _ = 1, 3 do
                      local e = fx.near(ctx, p.x, p.y, 120)
                      if e then
                          local dx, dy = fx.dir(ctx, e.x, e.y)
                          p.attack.type.fire(p, ctx.world, dx, dy, q)
                      end
                  end
                  sk.replaying = false
              end } } },
        } },
        { name = "Silk Walls", blurb = "Silk walls that hold them back", color = { 0.75, 0.55, 1 }, nodes = {
            { id = "ow_wall", tier = 1, ranks = 3, name = "Strong Strands", desc = "Walls catch 15 more ants and last 2 s longer per rank.",
              secondary = { strength = 15, duration = 2 } },
            { id = "ow_long", tier = 2, name = "Long Strands", desc = "Walls can be stretched much longer.",
              secondary = { length = 50 } },
            { id = "ow_maze", tier = 3, col = -1, name = "Web Maze", desc = "Two more walls at once, and they recharge 30% faster.",
              secondary = { max = 2, cooldown = { mul = -0.3 } } },
            { id = "ow_barbed", tier = 3, col = 1, name = "Barbed Silk", desc = "Walls cut every ant they catch and hold them longer.",
              secondary = { damage = 6, hold = 1 } },
            { id = "ow_hold", tier = 4, name = "Lasting Silk", desc = "Caught ants stay stuck 1.5 s longer.",
              secondary = { hold = 1.5 } },
            { id = "ow_electric", tier = 5, name = "Electric Silk", desc = "Your walls crackle with static: every second they shock every ant along them.",
              procs = { { trigger = "onTick", cooldown = 1, effect = function(ctx)
                  for _, w in ipairs(ctx.world.hazards.walls or {}) do
                      local dx, dy = w.x2 - w.x1, w.y2 - w.y1
                      local len = math.sqrt(dx * dx + dy * dy)
                      if len > 1 then fx.line(ctx, w.x1, w.y1, dx / len, dy / len, len, 6, 8, SPARK, { knockback = 0 }) end
                  end
              end } } },
        } },
        { name = "Grapple", blurb = "Swing around on a grapple line", color = { 0.5, 0.85, 1 }, nodes = {
            { id = "ow_legs", tier = 1, ranks = 3, name = "Long Legs", desc = "+6 speed and +6 max HP per rank.",
              stats = { moveSpeed = 6, maxHp = 6 } },
            { id = "ow_reel", tier = 2, name = "Strong Reel", desc = "The line pulls you in much harder and faster.",
              dash = { maxSpeed = { add = 120, base = 520 }, pull = { add = 500, base = 1700 } } },
            { id = "ow_ball", tier = 3, col = -1, name = "Wrecking Ball", desc = "Ants you fly into on the line take heavy damage.",
              dash = { ram = { add = 10, base = 6 } } },
            { id = "ow_reach", tier = 3, col = 1, name = "Long Line", desc = "The line reaches much further.",
              dash = { range = { add = 80, base = 170 } } },
            { id = "ow_impact", tier = 4, name = "Impact", desc = "Landing from the line slams down on the ants there.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  fx.explode(ctx, ctx.player.x, ctx.player.y, 34, 14, SILK, { knockback = 180 })
              end } } },
            { id = "ow_net", tier = 5, name = "Net Drop", desc = "Every landing drops a huge web that pins ants around you.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  fx.web(ctx, ctx.player.x, ctx.player.y, 50, 4, 0.15)
                  fx.nova(ctx, ctx.player.x, ctx.player.y, 50, 6, SILK, { slow = { 0.1, 1.5 }, knockback = 0 })
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_orb_golden", name = "Golden Orb", desc = "Every 4th web shot is a giant golden web, and ants dying in webs leave fresh ones.",
          empower = { move = "attack", every = 4, text = "GOLDEN ORB!", mods = { radius = { mul = 0.8 }, duration = { mul = 0.5 } } },
          procs = { { trigger = "onKill", chance = 0.25, effect = function(ctx)
              fx.web(ctx, ctx.x, ctx.y, 24, 2.5, 0.3)
          end } } },
}
