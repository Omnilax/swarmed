-- Hissing Roach: the unkillable bully. Headbutts that bulldoze, a hiss that grows into a sonic
-- boom, and a body that just keeps going.
local fx = require("src.game.skills").fx
local Combat = require("src.game.combat")

local AIR = { 0.85, 0.95, 1 }

return {
    character = "hissing_roach",
    branches = {
        { name = "Headbutt", blurb = "Shove ants back with your head", color = { 1, 0.7, 0.4 }, nodes = {
            { id = "hr_head", tier = 1, ranks = 3, name = "Hard Head", desc = "+15% headbutt damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "hr_heavy", tier = 2, name = "Throw Your Weight", desc = "Every 3rd headbutt is a heavy one (was every 4th).",
              attack = { heavyEvery = { set = 3 } } },
            { id = "hr_dozer", tier = 3, col = -1, name = "Bulldozer", desc = "Headbutts hit a much wider arc and reach 8 further.",
              attack = { arc = 0.8, reach = 8 } },
            { id = "hr_bowl", tier = 3, col = 1, name = "Bowling Ball", desc = "Ants you headbutt have a 25% chance to be launched as missiles into the crowd.",
              procs = { { trigger = "onHit", move = "attack", chance = 0.25, effect = function(ctx)
                  local dx, dy = fx.dir(ctx, ctx.target.x, ctx.target.y)
                  fx.fling(ctx, ctx.target, dx, dy, 90, { damage = 8, landDamage = 10, radius = 22 })
              end } } },
            { id = "hr_plate", tier = 4, name = "Thick Pronotum", desc = "+2 armor and +30% knockback.",
              stats = { armor = 2, knockback = 30 } },
            { id = "hr_stampede", tier = 5, name = "Stampede", desc = "Every headbutt sends a shockwave rolling forward through the crowd.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  local p = ctx.player
                  fx.line(ctx, p.x, p.y, ctx.ax, ctx.ay, 110, 9, ctx.params.damage * 0.8, { 1, 0.75, 0.45 }, { knockback = 150 })
              end } } },
        } },
        { name = "Hiss", blurb = "Stun everything with a hiss", color = AIR, nodes = {
            { id = "hr_stun", tier = 1, ranks = 3, name = "Shock", desc = "A full hiss stuns 0.4 s longer per rank.",
              secondary = { maxStun = 0.4, stun = 0.15 } },
            { id = "hr_lungs", tier = 2, name = "Big Lungs", desc = "Draw a full breath 40% faster.",
              secondary = { charge = { mul = -0.4 } } },
            { id = "hr_deaf", tier = 3, col = -1, name = "Deafening", desc = "A full hiss reaches 40 further.",
              secondary = { maxRadius = 40 } },
            { id = "hr_shriek", tier = 3, col = 1, name = "Shriek", desc = "The hiss itself hurts: triple damage.",
              secondary = { damage = { mul = 2 } } },
            { id = "hr_hcd", tier = 4, name = "Short Fuse", desc = "Hiss recharges 30% faster.",
              secondary = { cooldown = { mul = -0.3 } } },
            { id = "hr_boom", tier = 5, name = "Sonic Boom", desc = "Ants stunned by your hiss are blown apart by a second wave a beat later.",
              procs = { { trigger = "onHit", move = "secondary", effect = function(ctx)
                  local e = ctx.target
                  if e.dead then return end
                  ctx.player:after(0.25, function(p, w)
                      if not e.dead then fx.nova(ctx, e.x, e.y, 16, 8, AIR, { knockback = 140 }) end
                  end)
              end } } },
        } },
        { name = "Survivor", blurb = "Shrug off anything, keep running", color = { 0.75, 0.55, 0.35 }, nodes = {
            { id = "hr_hp", tier = 1, ranks = 3, name = "Tough Exoskeleton", desc = "+12 max HP and +0.3 HP/s per rank.",
              stats = { maxHp = 12, hpRegen = 0.3 } },
            { id = "hr_scurry", tier = 2, name = "Scurry", desc = "One more dash charge.",
              dash = { charges = 1 } },
            { id = "hr_far", tier = 3, col = -1, name = "Long Legs", desc = "Scurries go 30 further and the speed burst after lasts longer.",
              dash = { distance = 30, burstTime = 0.4 } },
            { id = "hr_slip", tier = 3, col = 1, name = "Slippery", desc = "After a dash: +30% dodge for 2 s.",
              procs = { { trigger = "onDash", effect = function(ctx) fx.buff(ctx, "hr_slip", "dodge", 30, 0, 2) end } } },
            { id = "hr_regen", tier = 4, name = "Unkillable", desc = "+2 HP/s regeneration.",
              stats = { hpRegen = 2 } },
            { id = "hr_alarm", tier = 5, name = "Alarm Hiss", desc = "Getting bitten sometimes triggers a free reflex hiss that stuns everything nearby (every 3 s at most).",
              procs = { { trigger = "onHurt", chance = 0.35, cooldown = 3, effect = function(ctx)
                  local p = ctx.player
                  for _, e in ipairs(Combat.collect(ctx.world, p.x, p.y, 50)) do
                      Combat.damage(ctx.world, e, 2, { knockback = 120, kbx = e.x - p.x, kby = e.y - p.y, stun = 1.2, procDepth = (ctx.procDepth or 0) + 1 })
                  end
                  ctx.world:addFx({ kind = "ring", x = p.x, y = p.y, r = 50, life = 0.3, color = AIR })
                  fx.say(ctx, "hiss!", AIR)
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_roach_pride", name = "Madagascar's Pride", desc = "After every hiss, +40% damage and +20% speed for 3 s.",
          procs = { { trigger = "onSpecial", effect = function(ctx)
              fx.buff(ctx, "sig_roach_dmg", "damage", 40, 0, 3)
              fx.buff(ctx, "sig_roach_speed", "moveSpeed", 0, 0.2, 3)
          end } } },
}
