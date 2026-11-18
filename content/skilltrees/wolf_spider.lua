-- Wolf Spider: the pack mother. Snapping bursts that summon more young, a brood that grows into
-- a venomous swarm, and a hunter's frenzy.
local fx = require("src.game.skills").fx

local MOSS = { 0.65, 1, 0.5 }

-- Shake a few spiderlings off her back (uses the wolf spider's own special).
local function brood(ctx, n)
    local p = ctx.player
    local sec = p.secondary
    if not sec or not sec.type.update then return end
    local q = require("src.game.skills").scaled(sec.params, 1)
    q.count = n
    sec.type.fire(p, ctx.world, p.aimX, p.aimY, q)
end

return {
    character = "wolf_spider",
    branches = {
        { name = "Snapping Burst", blurb = "Venom bursts all around", color = { 1, 0.7, 0.35 }, nodes = {
            { id = "ws_fangs", tier = 1, ranks = 3, name = "Sharp Fangs", desc = "+15% burst damage per rank.",
              attack = { damage = { mul = 0.15 } } },
            { id = "ws_quick", tier = 2, name = "Quick Snaps", desc = "Bursts come 15% faster.",
              attack = { cooldown = { mul = -0.15 } } },
            { id = "ws_pack", tier = 3, col = -1, name = "Hunting Pack", desc = "Ants your bursts kill sometimes shake two spiderlings off your back.",
              procs = { { trigger = "onKill", move = "attack", chance = 0.2, effect = function(ctx) brood(ctx, 2) end } } },
            { id = "ws_wide", tier = 3, col = 1, name = "Wide Pounce", desc = "Much bigger bursts that throw ants further.",
              attack = { radius = 10, knockback = 40 } },
            { id = "ws_venom", tier = 4, name = "Venom Bite", desc = "Bursts often leave ants poisoned.",
              procs = { { trigger = "onHit", move = "attack", chance = 0.3, effect = function(ctx) fx.poison(ctx.target, 5, 3) end } } },
            { id = "ws_alpha", tier = 5, name = "Alpha Howl", desc = "Every 4th burst is a huge howl at 2.5x damage that calls three spiderlings.",
              empower = { move = "attack", every = 4, text = "HOWL!", shake = 0.15,
                  mods = { radius = { mul = 1 }, damage = { mul = 1.5 }, knockback = { mul = 0.5 } } },
              procs = { { trigger = "onAttack", effect = function(ctx, rank, sk)
                  if (sk.counters.attack or 0) % 4 == 0 then brood(ctx, 3) end
              end } } },
        } },
        { name = "Brood", blurb = "Spiderlings that hunt for you", color = { 0.75, 0.55, 1 }, nodes = {
            { id = "ws_brood", tier = 1, ranks = 3, name = "Bigger Clutch", desc = "+2 spiderlings per swarm per rank.",
              secondary = { count = 2 } },
            { id = "ws_bite", tier = 2, name = "Sharp Brood", desc = "Spiderlings bite 30% harder and once more each.",
              secondary = { damage = { mul = 0.3 }, bites = 1 } },
            { id = "ws_long", tier = 3, col = -1, name = "Long-lived", desc = "Spiderlings live 3 s longer and run faster.",
              secondary = { life = 3, speed = 40 } },
            { id = "ws_mother", tier = 3, col = 1, name = "Devoted Mother", desc = "Spiderling Swarm recharges 30% faster.",
              secondary = { cooldown = { mul = -0.3 } } },
            { id = "ws_toxic", tier = 4, name = "Venomous Brood", desc = "Spiderling venom is 80% stronger.",
              secondary = { ["poison.1"] = { mul = 0.8 } } },
            { id = "ws_endless", tier = 5, name = "Endless Brood", desc = "Any kill can hatch a new spiderling, and the swarm hits 30% harder.",
              secondary = { damage = { mul = 0.3 } },
              procs = { { trigger = "onKill", chance = 0.08, effect = function(ctx) brood(ctx, 1) end } } },
        } },
        { name = "Hunter", blurb = "Dart off and vanish", color = { 0.5, 0.85, 1 }, nodes = {
            { id = "ws_legs", tier = 1, ranks = 3, name = "Running Legs", desc = "+6 speed and +3% crit chance per rank.",
              stats = { moveSpeed = 6, critChance = 3 } },
            { id = "ws_sprint", tier = 2, name = "Leaf Litter", desc = "Dash further and stay hidden 0.8 s longer.",
              dash = { distance = 25, hide = 0.8 } },
            { id = "ws_twin", tier = 3, col = -1, name = "Double Dash", desc = "Store a second dash.",
              dash = { charges = 1 } },
            { id = "ws_ambush", tier = 3, col = 1, name = "Ambush", desc = "After a dash: +35% damage for 2 s.",
              procs = { { trigger = "onDashEnd", effect = function(ctx) fx.buff(ctx, "ws_ambush", "damage", 35, 0, 2) end } } },
            { id = "ws_eyes", tier = 4, name = "Eight Eyes", desc = "+8% crit chance and +30% crit damage.",
              stats = { critChance = 8, critDamage = 30 } },
            { id = "ws_frenzy", tier = 5, name = "Blood Frenzy", desc = "Kills whip you into a frenzy: +30% attack speed and speed for 3 s.",
              procs = { { trigger = "onKill", chance = 0.2, effect = function(ctx)
                  fx.buff(ctx, "ws_frenzy_as", "attackSpeed", 30, 0, 3)
                  fx.buff(ctx, "ws_frenzy_ms", "moveSpeed", 0, 0.15, 3)
              end } } },
        } },
    },
    -- the top of the kin branch (content/skillbranches): this bug's own trick
    signature = { id = "sig_wolf_howl", name = "Mother Wolf", desc = "Every 5th venom burst is a howl: twice as wide and twice as hard.",
          empower = { move = "attack", every = 5, text = "HOWL!", shake = 0.1, mods = { radius = { mul = 1 }, damage = { mul = 1 } } } },
}
