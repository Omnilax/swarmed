-- Ready-made skill trees for custom bugs (Bug Creator). A custom bug picks one with
-- skillTree = "preset:<id>", or gets the one matching its playstyle when it names none, so
-- every bug has a tree. Each preset is three branches of moves-agnostic upgrades (stats, echoes,
-- empowered hits, procs); the bug's kin branch (content/skillbranches) is added as a fourth.
-- PresetTrees.make(id, charDef) -> a fresh, validated tree.
local fx = require("src.game.skills").fx

local P = {}
local ORDER = { "brawler", "tank", "speedster", "ranged", "control" }

local RED, GOLD, BLUE, GREEN, VIOLET = { 1, 0.5, 0.4 }, { 1, 0.82, 0.4 }, { 0.5, 0.8, 1 }, { 0.55, 0.95, 0.5 }, { 0.8, 0.6, 1 }

-- branches shared by several presets
local function fury(id)
    return { name = "Fury", blurb = "Hit harder, hit again", color = RED, nodes = {
        { id = id .. "_power", tier = 1, ranks = 3, name = "Power", desc = "+8% damage per rank.", stats = { damage = 8 } },
        { id = id .. "_quick", tier = 2, ranks = 2, name = "Quick Hands", desc = "+8% attack speed per rank.", stats = { attackSpeed = 8 } },
        { id = id .. "_echo", tier = 3, col = -1, name = "Follow-through", desc = "Your attack strikes again a beat later at 50%.",
          echo = { move = "attack", delay = 0.16, mult = 0.5 } },
        { id = id .. "_third", tier = 3, col = 1, name = "Crushing Third", desc = "Every 3rd attack deals +80% damage and reaches further.",
          empower = { move = "attack", every = 3, mods = { damage = { mul = 0.8 }, radius = { mul = 0.3 }, range = { mul = 0.3 } }, text = "CRUSH!" } },
        { id = id .. "_burst", tier = 4, name = "Shockwave", desc = "Kills by your attack have a 30% chance to burst, hitting ants around.",
          procs = { { trigger = "onKill", move = "attack", chance = 0.3, effect = function(ctx)
              fx.nova(ctx, ctx.x, ctx.y, 26, 8, RED)
          end } } },
        { id = id .. "_frenzy", tier = 5, cost = 3, name = "Frenzy", desc = "Kills give +25% attack speed for 3 s.",
          procs = { { trigger = "onKill", cooldown = 1, effect = function(ctx)
              fx.buff(ctx, id .. "_frenzy", "attackSpeed", 25, 0, 3)
          end } } },
    } }
end

local function shell(id)
    return { name = "Shell", blurb = "Soak it up and push back", color = GOLD, nodes = {
        { id = id .. "_hide", tier = 1, ranks = 3, name = "Thick Hide", desc = "+12 max HP per rank.", stats = { maxHp = 12 } },
        { id = id .. "_plates", tier = 2, ranks = 2, name = "Plates", desc = "+1 armor per rank.", stats = { armor = 1 } },
        { id = id .. "_mend", tier = 3, col = -1, name = "Mend", desc = "+0.6 HP per second.", stats = { hpRegen = 0.6 } },
        { id = id .. "_thorns", tier = 3, col = 1, name = "Thorny", desc = "Getting hit hurts up to 5 ants around you.",
          procs = { { trigger = "onHurt", cooldown = 0.6, effect = function(ctx)
              local p = ctx.player
              fx.nova(ctx, p.x, p.y, 30, 10, GOLD)
          end } } },
        { id = id .. "_last", tier = 4, name = "Last Stand", desc = "Below 30% HP: +30% damage and +3 armor.",
          procs = { { trigger = "onHurt", cooldown = 4, condition = function(ctx)
              local p = ctx.player
              return p.hp < p.stats:get("maxHp") * 0.3
          end, effect = function(ctx)
              fx.buff(ctx, id .. "_last_d", "damage", 30, 0, 4)
              fx.buff(ctx, id .. "_last_a", "armor", 3, 0, 4)
              fx.say(ctx, "LAST STAND", GOLD)
          end } } },
        { id = id .. "_feast", tier = 5, cost = 3, name = "Feast", desc = "Kills heal 1 HP.",
          procs = { { trigger = "onKill", effect = function(ctx) fx.heal(ctx, 1) end } } },
    } }
end

local function stride(id)
    return { name = "Stride", blurb = "Faster feet, quicker dashes", color = GREEN, nodes = {
        { id = id .. "_legs", tier = 1, ranks = 3, name = "Long Legs", desc = "+6 move speed per rank.", stats = { moveSpeed = 6 } },
        { id = id .. "_wind", tier = 2, ranks = 2, name = "Second Wind", desc = "Dash recharges 0.15 s faster per rank.", stats = { dashCooldown = -0.15 } },
        { id = id .. "_slip", tier = 3, col = -1, name = "Slippery", desc = "+8% dodge.", stats = { dodge = 8 } },
        { id = id .. "_trail", tier = 3, col = 1, name = "Hot Trail", desc = "Dashing leaves a patch that burns ants.",
          procs = { { trigger = "onDash", effect = function(ctx)
              local p = ctx.player
              fx.patch(ctx, p.x, p.y, 22, 2.5, 6, 0.7, RED)
          end } } },
        { id = id .. "_rush", tier = 4, name = "Rush", desc = "After a dash: +40% speed for 1.5 s.",
          procs = { { trigger = "onDash", effect = function(ctx)
              fx.buff(ctx, id .. "_rush", "moveSpeed", 0, 0.4, 1.5)
          end } } },
        { id = id .. "_blur", tier = 5, cost = 3, name = "Blur", desc = "Dodging an attack blasts the ants around you.",
          procs = { { trigger = "onDodge", cooldown = 0.5, effect = function(ctx)
              local p = ctx.player
              fx.nova(ctx, p.x, p.y, 34, 12, GREEN)
          end } } },
    } }
end

local function aim(id)
    return { name = "Aim", blurb = "Sharper, further, more", color = BLUE, nodes = {
        { id = id .. "_eye", tier = 1, ranks = 3, name = "Keen Eye", desc = "+4% crit chance per rank.", stats = { critChance = 4 } },
        { id = id .. "_reach", tier = 2, ranks = 2, name = "Reach", desc = "+10% area per rank.", stats = { area = 10 } },
        { id = id .. "_fan", tier = 3, col = -1, name = "Twin Special", desc = "Your special fires twice, fanned out, at 60%.",
          fan = { move = "secondary", count = 2, spread = 0.35, mult = 0.6 } },
        { id = id .. "_crit", tier = 3, col = 1, name = "Deadly", desc = "+40% crit damage.", stats = { critDamage = 40 } },
        { id = id .. "_arc", tier = 4, name = "Arc Spark", desc = "Crits jump to 2 more ants.",
          procs = { { trigger = "onHit", cooldown = 0.25, condition = function(ctx) return ctx.crit end, effect = function(ctx)
              if ctx.target then fx.chain(ctx, ctx.target, 2, 60, 6, BLUE) end
          end } } },
        { id = id .. "_volley", tier = 5, cost = 3, name = "Volley", desc = "Every 4th special throws a ring of shards.",
          procs = { { trigger = "onSpecial", effect = function(ctx, rank, sk)
              if fx.every(sk, id .. "_volley", 4) then
                  local p = ctx.player
                  fx.shards(ctx, p.x, p.y, 10, 8, BLUE)
              end
          end } } },
    } }
end

local function snare(id)
    return { name = "Snare", blurb = "Slow them, gather them, pick them off", color = VIOLET, nodes = {
        { id = id .. "_luck", tier = 1, ranks = 3, name = "Lucky", desc = "+6% luck per rank (better procs and drops).", stats = { luck = 6 } },
        { id = id .. "_long", tier = 2, ranks = 2, name = "Longer Reach", desc = "+10% area per rank.", stats = { area = 10 } },
        { id = id .. "_web", tier = 3, col = -1, name = "Sticky Ends", desc = "Ants you kill leave a web that slows.",
          procs = { { trigger = "onKill", chance = 0.35, effect = function(ctx)
              fx.web(ctx, ctx.x, ctx.y, 22, 3, 0.45)
          end } } },
        { id = id .. "_pull", tier = 3, col = 1, name = "Undertow", desc = "Your special drags ants towards where you aim.",
          procs = { { trigger = "onSpecial", effect = function(ctx)
              local p = ctx.player
              fx.pull(ctx, p.x + (ctx.ax or 0) * 50, p.y + (ctx.ay or 0) * 50, 70, 260)
          end } } },
        { id = id .. "_venom", tier = 4, name = "Venom", desc = "Hits have a 25% chance to poison (4/s for 3 s).",
          procs = { { trigger = "onHit", chance = 0.25, effect = function(ctx)
              if ctx.target then fx.poison(ctx.target, 4, 3) end
          end } } },
        { id = id .. "_storm", tier = 5, cost = 3, name = "Storm", desc = "Every 10th kill calls lightning on 5 ants.",
          procs = { { trigger = "onKill", effect = function(ctx, rank, sk)
              if fx.every(sk, id .. "_storm", 10) and ctx.target then fx.chain(ctx, ctx.target, 5, 90, 14, VIOLET) end
          end } } },
    } }
end

P.list = {
    brawler = { name = "Brawler", desc = "Hit harder and more often, shrug off hits.", make = function(id) return { fury(id), shell(id), stride(id) } end },
    tank = { name = "Tank", desc = "Huge health, armor and payback.", make = function(id) return { shell(id), fury(id), snare(id) } end },
    speedster = { name = "Speedster", desc = "Fast feet, quick dashes, dodges that hurt.", make = function(id) return { stride(id), fury(id), aim(id) } end },
    ranged = { name = "Sharpshooter", desc = "Crits, area and a stronger special.", make = function(id) return { aim(id), stride(id), snare(id) } end },
    control = { name = "Trapper", desc = "Webs, pulls, poison and lightning.", make = function(id) return { snare(id), aim(id), shell(id) } end },
}
P.order = ORDER

-- A fresh tree for a custom bug (own node tables, its kin branch attached, validated).
function P.make(presetId, charDef)
    local Skills = require("src.game.skills")
    local pr = P.list[presetId] or P.list.brawler
    local tree = { id = (charDef and charDef.id or "custom") .. "_preset", character = charDef and charDef.id, preset = presetId,
        custom = true, branches = pr.make("pre_" .. presetId) }
    Skills.attachKin(tree, charDef)
    local ok, err = Skills.validateTree(tree)
    assert(ok, "preset tree " .. tostring(presetId) .. ": " .. tostring(err))
    return tree
end

-- Which preset suits a playstyle.
function P.forPlaystyle(ps)
    return P.list[ps] and ps or "brawler"
end

return P
