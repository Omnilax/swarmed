-- Assassin bug: the stalker. Stabs that drink deeper and skewer more, a shove that throws the
-- swarm back, and a cloak that lasts longer and hits harder.
local fx = require("src.game.skills").fx

local BLOOD = { 1, 0.3, 0.25 }

return {
    character = "assassin_bug",
    branches = {
        { name = "Rostrum", blurb = "Life-drinking beak stabs", color = { 1, 0.4, 0.35 }, nodes = {
            { id = "ab_sharp", tier = 1, ranks = 3, name = "Sharp Beak", desc = "+12% stab damage and a longer beak per rank.",
              attack = { damage = { mul = 0.12 }, reach = 4 } },
            { id = "ab_drink", tier = 2, name = "Deep Drinker", desc = "Stabs heal 15% more of the damage they deal.",
              attack = { leech = 0.15 } },
            { id = "ab_skewer", tier = 3, col = -1, name = "Skewer", desc = "Each stab runs through three more ants.",
              attack = { pierce = 3 } },
            { id = "ab_saliva", tier = 3, col = 1, name = "Toxic Saliva", desc = "Stabs inject saliva that keeps eating the ant from inside.",
              attack = { poison = { set = { 6, 3 } } } },
            { id = "ab_flurry", tier = 4, name = "Flurry", desc = "Every stab strikes again a heartbeat later.",
              echo = { move = "attack", delay = 0.1, mult = 0.6 } },
            { id = "ab_impale", tier = 5, name = "Impale", desc = "Every 4th stab is a huge thrust that pierces a whole line and drinks twice as deep.",
              empower = { move = "attack", every = 4, mods = { reach = { mul = 1.2 }, pierce = { add = 8 }, leech = { mul = 1 }, damage = { mul = 0.8 } }, text = "IMPALE!", shake = 0.12 } },
        } },
        { name = "Shove", blurb = "Clear space, stagger the crowd", color = { 0.95, 0.55, 0.3 }, nodes = {
            { id = "ab_gulp", tier = 1, ranks = 3, name = "Heavy Shove", desc = "+15% shove damage and harder knockback per rank.",
              secondary = { damage = { mul = 0.15 }, knockback = 40 } },
            { id = "ab_quick", tier = 2, name = "Quick Hands", desc = "Shove recharges 25% faster.",
              secondary = { cooldown = { mul = -0.25 } } },
            { id = "ab_chain", tier = 3, col = -1, name = "Wide Shove", desc = "Shove hits a much wider and longer cone.",
              secondary = { arc = 0.7, radius = 10 } },
            { id = "ab_bloat", tier = 3, col = 1, name = "Stagger", desc = "Shoved ants stay dazed much longer.",
              secondary = { stun = 0.5 } },
            { id = "ab_sanguine", tier = 4, name = "Sanguine Spray", desc = "Bursting husks spray blood droplets that fly through ants.",
              procs = { { trigger = "onKill", chance = 0.25, effect = function(ctx)
                  fx.shards(ctx, ctx.x, ctx.y, 5, 6, BLOOD, { speed = 240, range = 70, pierce = 2 })
              end } } },
            { id = "ab_feast", tier = 5, name = "Feeding Frenzy", desc = "Every kill you make heals 1 HP, and shoving makes you 30% faster for 3 s.",
              procs = { { trigger = "onKill", effect = function(ctx) fx.heal(ctx, 1) end },
                        { trigger = "onSpecial", effect = function(ctx) fx.buff(ctx, "ab_feast", "moveSpeed", 0, 0.3, 3) end } } },
        } },
        { name = "Ambush", blurb = "Strike from the shadows", color = { 0.6, 0.8, 1 }, nodes = {
            { id = "ab_lean", tier = 1, ranks = 3, name = "Lean Body", desc = "+6 max HP and +4% speed per rank.",
              stats = { maxHp = 6 }, statsMult = { moveSpeed = 0.04 } },
            { id = "ab_stalk", tier = 2, name = "Stalker", desc = "+8% crit chance and +30% crit damage.",
              stats = { critChance = 8, critDamage = 30 } },
            { id = "ab_ambush", tier = 3, col = -1, name = "Deep Shadows", desc = "Attacks from stealth hit even harder (x3.5 instead of x2.5).",
              dash = { bonus = 1 } },
            { id = "ab_vanish", tier = 3, col = 1, name = "Long Shadow", desc = "+1.5 s of stealth, and strikes from it cost less stamina.",
              dash = { stamina = 1.5, strikeCost = { mul = -0.5 } } },
            { id = "ab_thirst", tier = 4, name = "Bloodthirst", desc = "+6% life steal and +0.5 HP regen.",
              stats = { lifesteal = 6, hpRegen = 0.5 } },
            { id = "ab_reaper", tier = 5, name = "Red Reaper", desc = "After a dash, a ring of blood-red stabs lances out all around you.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  local p = ctx.player
                  for i = 0, 7 do
                      local a = i / 8 * math.pi * 2
                      fx.line(ctx, p.x, p.y, math.cos(a), math.sin(a), 55, 4, 10, BLOOD)
                  end
                  fx.heal(ctx, 3)
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_assassin_reaper", name = "Red Assassin", desc = "Every kill with your beak drinks deep: +1 HP and +20% damage for 3 s.",
          procs = { { trigger = "onKill", move = "attack", effect = function(ctx)
              fx.heal(ctx, 1)
              fx.buff(ctx, "sig_assassin_reaper", "damage", 20, 0, 3)
          end } } },
}
