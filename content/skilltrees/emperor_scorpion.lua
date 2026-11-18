-- Emperor scorpion: the crusher. Claws that crush both sides and execute the wounded, a grab
-- that holds more and stings harder, and armour that hits back.
local fx = require("src.game.skills").fx

local VENOM = { 0.75, 1, 0.4 }
local CLAW = { 0.6, 0.7, 1 }

return {
    character = "emperor_scorpion",
    branches = {
        { name = "Claws", blurb = "Crush and execute the wounded", color = { 0.6, 0.7, 1 }, nodes = {
            { id = "es_crush", tier = 1, ranks = 3, name = "Crushing Grip", desc = "+12% claw damage and bigger claws per rank.",
              attack = { damage = { mul = 0.12 }, radius = 2 } },
            { id = "es_execute", tier = 2, name = "Executioner", desc = "Wounded ants take far more from the claws.",
              attack = { execute = 0.8 } },
            { id = "es_both", tier = 3, col = -1, name = "Twin Crush", desc = "Both claws crush at once, every time.",
              attack = { both = true } },
            { id = "es_reach", tier = 3, col = 1, name = "Long Arms", desc = "Claws reach much further and knock ants flying.",
              attack = { offset = 12, knockback = 120 } },
            { id = "es_shatter", tier = 4, name = "Shatter", desc = "Ants crushed to death burst into shards of carapace.",
              procs = { { trigger = "onKill", move = "attack", chance = 0.4, effect = function(ctx)
                  fx.shards(ctx, ctx.x, ctx.y, 4, 6, CLAW, { speed = 220, range = 60 })
              end } } },
            { id = "es_quake", tier = 5, name = "Earthbreaker", desc = "Every 3rd crush slams the ground ahead in a shockwave.",
              procs = { { trigger = "onAttack", effect = function(ctx)
                  local p = ctx.player
                  p._esQuake = (p._esQuake or 0) + 1
                  if p._esQuake % 3 ~= 0 then return end
                  fx.explode(ctx, p.x + ctx.ax * 34, p.y + ctx.ay * 34, 40, ctx.params.damage * 1.5, CLAW, { knockback = 220 })
              end } } },
        } },
        { name = "Grab & Stab", blurb = "Grab two ants and sting them", color = { 0.75, 1, 0.4 }, nodes = {
            { id = "es_venom", tier = 1, ranks = 3, name = "Venom Sacs", desc = "+20% sting damage and venom per rank.",
              secondary = { damage = { mul = 0.2 }, ["poison.1"] = { mul = 0.2 } } },
            { id = "es_frenzy", tier = 2, name = "Sting Frenzy", desc = "Stings come 30% faster and you can keep stinging longer.",
              secondary = { stabTime = { mul = -0.3 }, stabs = 3 } },
            { id = "es_three", tier = 3, col = -1, name = "Full Hands", desc = "Grab four ants at once.",
              secondary = { grabs = 2, reach = 10 } },
            { id = "es_splash", tier = 3, col = 1, name = "Venom Burst", desc = "Each sting's venom splashes twice as far.",
              secondary = { splash = { mul = 1 } } },
            { id = "es_slam", tier = 4, name = "Body Slam", desc = "The final slam hits twice as hard.",
              secondary = { slam = { mul = 1 } } },
            { id = "es_paralyse", tier = 5, name = "Paralysis", desc = "Every sting paralyses the ants around the victim and the venom jumps on.",
              procs = { { trigger = "onHit", chance = 0.35, effect = function(ctx)
                  if not ctx.target.held then return end
                  fx.chain(ctx, ctx.target, 3, 50, 6, VENOM, { poison = { 8, 3 }, slow = { 0.05, 1.5 } })
              end } } },
        } },
        { name = "Carapace", blurb = "Brace, bulldoze, outlast", color = { 0.5, 0.55, 0.8 }, nodes = {
            { id = "es_plate", tier = 1, ranks = 3, name = "Plated", desc = "+2 armor and +8 max HP per rank.",
              stats = { armor = 2, maxHp = 8 } },
            { id = "es_regen", tier = 2, name = "Moult", desc = "+0.8 HP regen.",
              stats = { hpRegen = 0.8 } },
            { id = "es_charge", tier = 3, col = -1, name = "Bulldoze", desc = "Your claw wall shoves harder and hits harder, you walk faster behind it, and it lasts 1 s longer.",
              dash = { ram = 4, push = 80, speed = 0.15, stamina = 1 } },
            { id = "es_spines", tier = 3, col = 1, name = "Spined Plates", desc = "Ants that bite you get pricked by venomous spines.",
              procs = { { trigger = "onHurt", effect = function(ctx)
                  local s = ctx.source
                  if type(s) == "table" and s.def and not s.dead then require("src.game.combat").damage(ctx.world, s, 4, { procDepth = 1, poison = { 4, 2 } }) end
              end } } },
            { id = "es_bulk", tier = 4, name = "Emperor's Bulk", desc = "+25% max HP, +20% knockback.",
              statsMult = { maxHp = 0.25 }, stats = { knockback = 20 } },
            { id = "es_tyrant", tier = 5, name = "Tyrant", desc = "Getting hurt makes the tail lash out at the nearest ant with a huge sting (every 1.5 s).",
              procs = { { trigger = "onHurt", cooldown = 1.5, effect = function(ctx)
                  local p = ctx.player
                  local e = fx.near(ctx, p.x, p.y, 70)
                  if not e then return end
                  local dx, dy = fx.dir(ctx, e.x, e.y)
                  fx.line(ctx, p.x, p.y, dx, dy, 80, 6, 30, VENOM, { poison = { 10, 4 } })
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_emperor_black", name = "Black Emperor", desc = "Ants your claws crush burst into venom that poisons every ant around them.",
          procs = { { trigger = "onKill", move = "attack", chance = 0.35, effect = function(ctx)
              fx.patch(ctx, ctx.x, ctx.y, 28, 2.5, 8, nil, { 0.75, 1, 0.4 })
          end } } },
}
