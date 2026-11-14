-- Vinegaroon: everything melts. Squirts that drench, acid bombs that flood the ground, and a
-- double dash that leaves vinegar everywhere it lands.
local fx = require("src.game.skills").fx
local Combat = require("src.game.combat")

local ACID = { 0.8, 1, 0.45 }

-- a burst of acid that corrodes what it splashes
local function splash(ctx, x, y, r, dmg)
    fx.nova(ctx, x, y, r, dmg, ACID, { corrode = { 1.4, 3 } })
    ctx.world.particles:burst(x, y, 6, { ACID }, 70, 30, { glow = true, grav = 120 })
end

return {
    character = "vinegaroon",
    branches = {
        { name = "Acid Squirt", color = ACID, nodes = {
            { id = "vg_acid", tier = 1, ranks = 3, name = "Strong Vinegar", desc = "+15% squirt damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "vg_drops", tier = 2, name = "Wide Nozzle", desc = "Each squirt sprays 2 more droplets.",
              attack = { drops = 2, spread = 0.12 } },
            { id = "vg_press", tier = 3, col = -1, name = "Pressurised", desc = "Squirts reach 50 further.",
              attack = { range = 50 } },
            { id = "vg_caustic", tier = 3, col = 1, name = "Caustic", desc = "Corroded ants take 20% more again from every hit.",
              attack = { ["corrode.1"] = 0.2 }, secondary = { ["corrode.1"] = 0.2 }, dash = { ["corrode.1"] = 0.2 } },
            { id = "vg_cloud", tier = 4, name = "Stinging Mist", desc = "A cloud forms every 3rd squirt (was 5th), 10 wider.",
              attack = { cloudEvery = { set = 3 }, cloudRadius = 10 } },
            { id = "vg_douse", tier = 5, name = "Douse", desc = "Every 4th squirt is a drenching wave: 8 more droplets across a wide fan.",
              empower = { move = "attack", every = 4, text = "DOUSE!", mods = { drops = 8, spread = 1 } } },
        } },
        { name = "Acid Bomb", color = { 0.6, 0.9, 0.3 }, nodes = {
            { id = "vg_bomb", tier = 1, ranks = 3, name = "Heavy Bomb", desc = "+15% acid bomb damage per rank.",
              secondary = { damage = { mul = 0.15 } } },
            { id = "vg_pool", tier = 2, name = "Flood", desc = "Acid pools are 15 wider and last 2 s longer.",
              secondary = { pool = 15, poolLife = 2 } },
            { id = "vg_payload", tier = 3, col = -1, name = "Heavy Payload", desc = "Thrown ants crash down 60% harder over a wider area.",
              throw = { landMul = 0.6, radiusMul = 0.3 } },
            { id = "vg_quick", tier = 3, col = 1, name = "Quick Grab", desc = "Acid Bomb recharges 40% faster.",
              secondary = { cooldown = { mul = -0.4 } } },
            { id = "vg_soak", tier = 4, name = "Fast Soak", desc = "Ants soak up acid 2x faster (full-size pools sooner).",
              secondary = { soak = { mul = -0.5 } } },
            { id = "vg_chain", tier = 5, name = "Chain Reaction", desc = "Ants that die while corroded burst in a splash of acid that corrodes their neighbours.",
              procs = { { trigger = "onKill", chance = 0.5, effect = function(ctx)
                  local e = ctx.target
                  if e and e.corrodeT and e.corrodeT > 0 then splash(ctx, ctx.x, ctx.y, 22, 6) end
              end } } },
        } },
        { name = "Acid Skip", color = { 0.55, 0.45, 0.4 }, nodes = {
            { id = "vg_shell", tier = 1, ranks = 3, name = "Plated Back", desc = "+10 max HP and +1 armor per rank.",
              stats = { maxHp = 10, armor = 1 } },
            { id = "vg_counter", tier = 2, name = "Spit Back", desc = "Vinegar puffs do +6 damage and spread 10 wider.",
              dash = { damage = 6, radius = 10 } },
            { id = "vg_turtle", tier = 3, col = -1, name = "Long Legs", desc = "Each skip goes 30 further and you get longer to take the second.",
              dash = { distance = 30, window = 0.3 } },
            { id = "vg_spines", tier = 3, col = 1, name = "Retaliate", desc = "Every push-off also fires acid in all directions.",
              procs = { { trigger = "onDash", cooldown = 0.1, effect = function(ctx)
                  local p = ctx.player
                  fx.shards(ctx, p.x, p.y, 6, 6, ACID, { range = 70 })
              end } } },
            { id = "vg_skin", tier = 4, name = "Acid Skin", desc = "+1.5 HP/s regeneration.",
              stats = { hpRegen = 1.5 } },
            { id = "vg_fountain", tier = 5, name = "Vinegar Fountain", desc = "Wherever a skip lands, the tail sprays a big ring of acid around you.",
              procs = { { trigger = "onDashEnd", effect = function(ctx)
                  local p = ctx.player
                  splash(ctx, p.x, p.y, 40, 8)
              end } } },
        } },
    },
}
