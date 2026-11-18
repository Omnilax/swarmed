-- Beetles: wing cases like armour plates, stubborn strength, and wings folded away for later.
local fx = require("src.game.skills").fx

local BRONZE = { 0.95, 0.75, 0.4 }

return {
    name = "Beetle Kin",
    blurb = "Armoured wing cases and brute strength",
    color = BRONZE,
    tags = { "beetle" },
    priority = 30,
    nodes = {
        { id = "kin_beetle_elytra", tier = 1, ranks = 2, name = "Elytra Plates", desc = "+10 max HP and +1 armor per rank.",
          stats = { maxHp = 10, armor = 1 } },
        { id = "kin_beetle_shove", tier = 2, col = -1, name = "Pushy", desc = "+25% knockback and +5% damage.",
          stats = { knockback = 25, damage = 5 } },
        { id = "kin_beetle_wings", tier = 2, col = 1, name = "Hind Wings", desc = "Your dash recharges 0.15 s faster.",
          stats = { dashCooldown = -0.15 } },
        { id = "kin_beetle_shock", tier = 3, name = "Shell Shock", desc = "Taking a hit slams the ants around you away (every 3 s).",
          procs = { { trigger = "onHurt", cooldown = 3, effect = function(ctx)
              local p = ctx.player
              fx.nova(ctx, p.x, p.y, 44, 10, BRONZE, { knockback = 200 })
          end } } },
        { id = "kin_beetle_iron", tier = 4, col = -1, name = "Ironclad", desc = "+3 armor and +10% max HP.",
          stats = { armor = 3 }, statsMult = { maxHp = 0.1 } },
        { id = "kin_beetle_grub", tier = 4, col = 1, name = "Grub Feast", desc = "Kills have a 6% chance to heal 3 HP.",
          procs = { { trigger = "onKill", chance = 0.06, effect = function(ctx) fx.heal(ctx, 3) end } } },
    },
}
