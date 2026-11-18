-- Whip Scorpion: reach and control. A left palp that becomes a cage of spines, a right palp
-- whose tip hits like a hammer, and feelers that never let the swarm close in.
local fx = require("src.game.skills").fx
local Combat = require("src.game.combat")

local SPINE = { 1, 0.85, 0.6 }

return {
    character = "whip_scorpion",
    branches = {
        { name = "Left Palp", blurb = "Long raking palp arcs", color = SPINE, nodes = {
            { id = "ws_left", tier = 1, ranks = 3, name = "Spined Palp", desc = "+15% rake damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "ws_reach", tier = 2, name = "Long Reach", desc = "The rake reaches 18 further.",
              attack = { reach = 18 } },
            { id = "ws_wide", tier = 3, col = -1, name = "Wide Rake", desc = "The rake sweeps a much wider arc.",
              attack = { arc = 0.9 } },
            { id = "ws_double", tier = 3, col = 1, name = "Double Lash", desc = "Every rake lashes back a beat later.",
              echo = { move = "attack", delay = 0.18, mult = 0.7, sameAim = true } },
            { id = "ws_barbs", tier = 4, name = "Barbed Spines", desc = "Both palps leave ants bleeding.",
              attack = { poison = { set = { 4, 3 } } }, secondary = { poison = { set = { 4, 3 } } } },
            { id = "ws_cage", tier = 5, name = "Cage of Spines", desc = "Every 3rd rake swings all the way round you at double damage.",
              empower = { move = "attack", every = 3, text = "CAGE!", shake = 0.08,
                  mods = { arc = { set = 6.3 }, damage = { mul = 1 } } } },
        } },
        { name = "Right Palp", blurb = "A heavy palp slam from afar", color = { 1, 0.65, 0.45 }, nodes = {
            { id = "ws_right", tier = 1, ranks = 3, name = "Raptorial Palp", desc = "+15% tip slam damage per rank.",
              secondary = { damage = { mul = 0.15 } } },
            { id = "ws_grab", tier = 2, name = "Heavy Tip", desc = "The tip's blast is bigger and splashes harder.",
              secondary = { radius = 6, splash = 0.25 } },
            { id = "ws_spear", tier = 3, col = -1, name = "Long Palp", desc = "The palp reaches 40 further.",
              secondary = { reach = 40 } },
            { id = "ws_twin", tier = 3, col = 1, name = "Twin Palps", desc = "Two more slams land beside the first.",
              fan = { move = "secondary", count = 2, spread = 0.35, mult = 0.6 } },
            { id = "ws_quick", tier = 4, name = "Snap Reflex", desc = "Tip slam recharges 30% faster and dazes 0.5 s longer.",
              secondary = { cooldown = { mul = -0.3 }, stun = 0.5 } },
            { id = "ws_toss", tier = 5, name = "Overhead Toss", desc = "Ants the tip lands on are hurled over your head and crash down behind you.",
              procs = { { trigger = "onHit", move = "secondary", effect = function(ctx)
                  local p = ctx.player
                  fx.fling(ctx, ctx.target, -p.aimX, -p.aimY, 70, { damage = 10, landDamage = 16, radius = 26, height = 22, color = SPINE })
              end } } },
        } },
        { name = "Feelers", blurb = "Feelers that pull you in", color = { 0.7, 0.55, 0.45 }, nodes = {
            { id = "ws_sense", tier = 1, ranks = 3, name = "Feeler Sense", desc = "+5% crit chance and +4 max HP per rank.",
              stats = { critChance = 5, maxHp = 4 } },
            { id = "ws_step", tier = 2, name = "Many Feelers", desc = "One more antenna whip charge.",
              dash = { charges = 1 } },
            { id = "ws_dodge", tier = 3, col = -1, name = "Untouchable", desc = "+15% dodge.",
              stats = { dodge = 15 } },
            { id = "ws_stride", tier = 3, col = 1, name = "Long Feelers", desc = "Antenna whips reach 40 further.",
              dash = { range = 40 } },
            { id = "ws_counter", tier = 4, name = "Counter-strike", desc = "After a feeler pull: +60% attack speed for 2 s.",
              procs = { { trigger = "onDash", effect = function(ctx) fx.buff(ctx, "ws_ctr", "attackSpeed", 60, 0, 2) end } } },
            { id = "ws_whiplash", tier = 5, name = "Whiplash", desc = "Every feeler pull cracks both feelers like whips, cutting a long line ahead of you.",
              procs = { { trigger = "onDash", effect = function(ctx)
                  local p = ctx.player
                  for s = -1, 1, 2 do
                      local a = math.atan2(p.aimY, p.aimX) + s * 0.25
                      fx.line(ctx, p.x, p.y, math.cos(a), math.sin(a), 130, 5, 14, { 0.85, 0.7, 0.55 })
                  end
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_whip_amblypygi", name = "Amblypygi", desc = "Your left palp lashes a second time 35% of the time, harder than the first.",
          echo = { move = "attack", delay = 0.18, mult = 1.1, chance = 0.35, sameAim = true, text = "LASH!" } },
}
