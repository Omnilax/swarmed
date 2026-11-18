-- Crab: the butcher. Faster, wider snips, snipping several ants in a row with halves that
-- explode, and a sideways scuttle that becomes a weapon.
local fx = require("src.game.skills").fx

local SHELL = { 1, 0.6, 0.45 }

return {
    character = "crab",
    branches = {
        { name = "Snips", blurb = "Two claws, nonstop snipping", color = { 1, 0.6, 0.45 }, nodes = {
            { id = "cr_sharp", tier = 1, ranks = 3, name = "Sharp Claws", desc = "+12% snip damage per rank.",
              attack = { damage = { mul = 0.12 } } },
            { id = "cr_wide", tier = 2, name = "Big Claws", desc = "Claws snap over a much wider patch.",
              attack = { radius = 6, offset = 3 } },
            { id = "cr_frenzy", tier = 3, col = -1, name = "Snip Frenzy", desc = "Snips come 25% faster.",
              attack = { cooldown = { mul = -0.25 } } },
            { id = "cr_both", tier = 3, col = 1, name = "Double Snip", desc = "The other claw snips right after, every time.",
              echo = { move = "attack", delay = 0.08, mult = 0.8 } },
            { id = "cr_bleed", tier = 4, name = "Clean Cuts", desc = "Snipped ants bleed out (poison).",
              procs = { { trigger = "onHit", move = "attack", chance = 0.5, effect = function(ctx) fx.poison(ctx.target, 4, 2) end } } },
            { id = "cr_guillotine", tier = 5, name = "Guillotine", desc = "Any ant your claws leave under 15% health is snipped clean in two.",
              procs = { { trigger = "onHit", move = "attack", effect = function(ctx)
                  local e = ctx.target
                  if e.dead or e.def.boss or e.hp > e.maxHp * 0.15 then return end
                  require("src.game.combat").damage(ctx.world, e, e.hp * 10 + 10, { procDepth = 2, noCrit = true })
                  ctx.world:floatText(e.x, e.y, "SNIP", SHELL, false)
              end } } },
        } },
        { name = "Snip in Two", blurb = "Cut ants in half, fling the halves", color = { 1, 0.85, 0.6 }, nodes = {
            { id = "cr_halves", tier = 1, ranks = 3, name = "Heavy Halves", desc = "+20% half damage and they fly further per rank.",
              secondary = { damage = { mul = 0.2 }, halves = 20 } },
            { id = "cr_quick", tier = 2, name = "Practised", desc = "Snip in Two recharges 30% faster.",
              secondary = { cooldown = { mul = -0.3 } } },
            { id = "cr_two", tier = 3, col = -1, name = "Assembly Line", desc = "Each grab snips one more ant right after.",
              secondary = { targets = 1 } },
            { id = "cr_boom", tier = 3, col = 1, name = "Gut Bombs", desc = "The halves burst where they land.",
              secondary = { halfBurst = 14 } },
            { id = "cr_reach", tier = 4, name = "Long Reach", desc = "Seize ants from much further away, and crush bosses harder.",
              secondary = { reach = 22, bossDamage = { mul = 1 } } },
            { id = "cr_massacre", tier = 5, name = "Massacre", desc = "Every snip scatters a spray of carapace shards all around.",
              procs = { { trigger = "onKill", move = "secondary", effect = function(ctx)
                  fx.shards(ctx, ctx.x, ctx.y, 8, 8, SHELL, { speed = 260, range = 90, pierce = 2 })
              end } } },
        } },
        { name = "Shell", blurb = "A hard shell and sideways scuttles", color = { 0.6, 0.85, 1 }, nodes = {
            { id = "cr_armour", tier = 1, ranks = 3, name = "Thick Shell", desc = "+1.5 armor and +6 max HP per rank.",
              stats = { armor = 1.5, maxHp = 6 } },
            { id = "cr_scurry", tier = 2, name = "Scurry", desc = "Scuttle further and faster.",
              dash = { distance = 25, speed = 0.2 } },
            { id = "cr_three", tier = 3, col = -1, name = "Many Legs", desc = "A third scuttle charge.",
              dash = { charges = 1 } },
            { id = "cr_ram", tier = 3, col = 1, name = "Side Swipe", desc = "Scuttling clubs every ant you pass, hard.",
              dash = { ram = 12, knockback = 120 } },
            { id = "cr_tide", tier = 4, name = "Low Tide", desc = "+0.6 HP regen and +10% speed.",
              stats = { hpRegen = 0.6 }, statsMult = { moveSpeed = 0.1 } },
            { id = "cr_wave", tier = 5, name = "Crashing Wave", desc = "Ending a scuttle sends a wave crashing out both sides.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  local p = ctx.player
                  fx.line(ctx, p.x, p.y, -p.aimY, p.aimX, 70, 8, 14, { 0.6, 0.85, 1 }, { knockback = 200 })
                  fx.line(ctx, p.x, p.y, p.aimY, -p.aimX, 70, 8, 14, { 0.6, 0.85, 1 }, { knockback = 200 })
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_crab_carcin", name = "Carcinization", desc = "Everything becomes crab: every snip-in-two sprays shell shards ahead of you.",
          procs = { { trigger = "onSpecial", effect = function(ctx)
              local p = ctx.player
              fx.shards(ctx, p.x + ctx.ax * 30, p.y + ctx.ay * 30, 5, 7, { 1, 0.6, 0.45 },
                  { angle = math.atan2(ctx.ay, ctx.ax), spread = 1.4, range = 90 })
          end } } },
}
