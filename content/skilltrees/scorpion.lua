-- Scorpion: the venom duelist. Faster stings, paralysing toxins that spread between ants, and
-- an armoured body that strikes back.
local fx = require("src.game.skills").fx

local VENOM = { 0.8, 1, 0.4 }

return {
    character = "scorpion",
    branches = {
        { name = "Pincers", color = { 1, 0.7, 0.35 }, nodes = {
            { id = "sc_claw", tier = 1, ranks = 3, name = "Strong Claws", desc = "+12% pinch and sting damage and longer pincers per rank.",
              attack = { damage = { mul = 0.12 }, radius = 2 } },
            { id = "sc_quick", tier = 2, name = "Quick Snips", desc = "Pinches come 15% faster.",
              attack = { cooldown = { mul = -0.15 } } },
            { id = "sc_trigger", tier = 3, col = -1, name = "Hair Trigger", desc = "The sting comes after every pinch instead of every second.",
              attack = { combo = { set = 2 } } },
            { id = "sc_crushing", tier = 3, col = 1, name = "Crushing Sting", desc = "The sting hits 1x harder and throws ants back.",
              attack = { stingMult = 1, knockback = 40 } },
            { id = "sc_grip", tier = 4, name = "Pinned", desc = "Pincers often pin ants in place for a second.",
              procs = { { trigger = "onHit", move = "attack", chance = 0.2, effect = function(ctx) fx.slow(ctx.target, 0.05, 1) end } } },
            { id = "sc_deathstalker", tier = 5, name = "Deathstalker", desc = "Every sting also fires three venom bolts down the line.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  local p = ctx.player
                  if p.attack.combo ~= math.max(2, ctx.params.combo or 3) then return end
                  fx.shards(ctx, p.x, p.y, 3, ctx.params.damage, VENOM, { angle = math.atan2(ctx.ay, ctx.ax), spread = 0.5,
                      speed = 300, range = 150, pierce = 3, poison = { 8, 3 } })
              end } } },
        } },
        { name = "Venom", color = { 0.75, 0.55, 1 }, nodes = {
            { id = "sc_potent", tier = 1, ranks = 3, name = "Potent Venom", desc = "+25% venom strength and +10% strike damage per rank.",
              secondary = { ["poison.1"] = { mul = 0.25 }, damage = { mul = 0.1 } } },
            { id = "sc_glands", tier = 2, name = "Big Glands", desc = "Venom Strike recharges 30% faster.",
              secondary = { cooldown = { mul = -0.3 } } },
            { id = "sc_spray", tier = 3, col = -1, name = "Venom Fan", desc = "Two more strikes fan out beside the main one.",
              fan = { move = "secondary", count = 2, spread = 0.35, mult = 0.7 } },
            { id = "sc_tail", tier = 3, col = 1, name = "Long Tail", desc = "Venom Strike reaches much further and wider.",
              secondary = { range = 40, width = 3 } },
            { id = "sc_rupture", tier = 4, name = "Toxic Rupture", desc = "Poisoned ants burst into venom puddles when they die.",
              procs = { { trigger = "onKill", chance = 0.35, effect = function(ctx)
                  if ctx.target.poisonT > 0 then fx.patch(ctx, ctx.x, ctx.y, 20, 3, 6, nil, VENOM) end
              end } } },
            { id = "sc_neuro", tier = 5, name = "Neurotoxin", desc = "Venom Strike paralyses ants for 2 s and the venom jumps to two more ants.",
              procs = { { trigger = "onHit", move = "secondary", effect = function(ctx)
                  fx.slow(ctx.target, 0.05, 2)
                  fx.chain(ctx, ctx.target, 2, 50, 6, VENOM, { poison = { 8, 3 } })
              end } } },
        } },
        { name = "Exoskeleton", color = { 0.5, 0.85, 1 }, nodes = {
            { id = "sc_carapace", tier = 1, ranks = 3, name = "Carapace", desc = "+1.5 armor and +6 max HP per rank.",
              stats = { armor = 1.5, maxHp = 6 } },
            { id = "sc_glow", tier = 2, name = "UV Glow", desc = "+6% crit chance and +25% crit damage.",
              stats = { critChance = 6, critDamage = 25 } },
            { id = "sc_sand", tier = 3, col = -1, name = "Sand Swim", desc = "Store a second tail flick, and spring further.",
              dash = { charges = 1, distance = 15 } },
            { id = "sc_riposte", tier = 3, col = 1, name = "Riposte", desc = "Getting hurt makes your tail lash out along your aim.",
              procs = { { trigger = "onHurt", cooldown = 1.5, effect = function(ctx)
                  local p = ctx.player
                  fx.line(ctx, p.x, p.y, p.aimX, p.aimY, 90, 6, 20, VENOM, { poison = { 8, 3 } })
              end } } },
            { id = "sc_predator", tier = 4, name = "Predator", desc = "+8% life steal.",
              stats = { lifesteal = 8 } },
            { id = "sc_lord", tier = 5, name = "Armoured Lord", desc = "Taking a hit releases a venom shockwave all around you. +4 armor.",
              stats = { armor = 4 },
              procs = { { trigger = "onHurt", cooldown = 3, effect = function(ctx)
                  local p = ctx.player
                  fx.nova(ctx, p.x, p.y, 44, 15, VENOM, { poison = { 8, 3 }, knockback = 160 })
              end } } },
        } },
    },
}
