-- ===========================================================================================
--  CUSTOM BUG BLUEPRINT
--  A playable bug for Swarmed, written as a Lua script. Open it in the game's Bug Creator
--  (main menu > Bug Creator > Write a Script), change what you like, press Save.
--  Full guide with every attack, dash, stat and item id: docs/CUSTOM_BUGS.md
--
--  Rules of the sandbox:
--    * The script must end with `return { ... }`: a table describing the bug.
--    * Plain Lua 5.1: math, string, table, pairs, ipairs, print and friends work. Files, `love`,
--      `require`, `load`, `os` and `io` do not exist here.
--    * Helpers: bug("scorpion") gives a copy of a built-in bug's data to start from;
--      bugs, attacks, dashes, items, statIds are lists of every id.
--    * Only data comes out, plus the functions of the bug's own code (moves, hooks, skill
--      tree procs), which run in the same sandbox. Numbers are kept in sane ranges (the Creator says what
--      it changed).
--    * Want a completely new bug? See "A BRAND-NEW BUG" at the bottom: own pixel art and legs,
--      moves written as code.
--    * Every field except `name` is optional. Leave one out and it comes from the `look` bug.
-- ===========================================================================================

return {
    -- The name shown everywhere (28 letters at most). It also makes the bug's id:
    -- "Spike Beetle" -> custom_spike_beetle (and the file custom_bugs/custom_spike_beetle.lua).
    name = "Spike Beetle",
    description = "A made-up beetle: mantis blades in front, a wolf spider's leap, and a scorpion's sting.",
    lore = "Nobody has ever seen one. That's what makes it special.",
    -- Shown once, the first time the bug is played. {attack} {secondary} {dash} become the
    -- player's own buttons.
    tip = "Slash with {attack}, sting a line with {secondary}, leap with {dash}.",

    -- LOOK: the body (model, animations and size) of a built-in bug.
    -- Ids: rhino_beetle stag_beetle tiger_beetle dung_beetle bombardier_beetle mantis
    --      jumping_spider wolf_spider tarantula orb_weaver camel_spider scorpion
    --      emperor_scorpion whip_scorpion vinegaroon centipede millipede crab hermit_crab
    --      lobster mantis_shrimp pistol_shrimp dragonfly assassin_bug hissing_roach stink_bug
    look = "rhino_beetle",
    scale = 1.1,                -- drawn size, 0.5 (tiny) .. 2 (huge). The hitbox follows.
    -- radius = 8,              -- hitbox in pixels (3 .. 22) if you want to set it yourself
    -- Recolour, like a skin: hue turns colours round the wheel (degrees), saturation and
    -- brightness multiply, tint ("#rrggbb") is laid over the top.
    colors = { hue = 140, saturation = 1.2 },
    -- tank | brawler | speedster | ranged | control  (bug select sorting and filters)
    playstyle = "brawler",

    -- STATS: set any of these (they replace the defaults; leave one out for the default).
    --   maxHp 5..500 (50)         hpRegen 0..10 (0)         armor -10..30 (0)
    --   dodge 0..60 % (0)         moveSpeed 30..300 (100)   damage -80..150 % (0)
    --   attackSpeed -60..150 % (0) area -60..150 % (0)      knockback -80..200 % (0)
    --   critChance 0..80 % (5)    critDamage 100..400 % (150) luck -80..150 % (0)
    --   lifesteal 0..25 % (0)     pickupRange 5..250 (40)   dashCooldown 0.2..8 s (1.2)
    stats = { maxHp = 70, armor = 3, moveSpeed = 110, critChance = 10 },

    -- MOVES. Each one can be:
    --   "mantis"                               copy that bug's move exactly
    --   { from = "mantis", damage = 20 }       copy it, then change some of its numbers
    --   { type = "arc", damage = 8, ... }      build it yourself from a move type
    --                                          (docs/CUSTOM_BUGS.md lists types and params)
    -- attack = left click / main button (it can't be turned off)
    attack = { from = "mantis", damage = 12 },
    -- secondary = right click: a slower special (false = none)
    secondary = { type = "venomsting", damage = 16, cooldown = 2, range = 80, width = 6, poison = { 8, 4 },
        color = { 0.8, 1, 0.4 } },
    -- dash = Shift: the movement move (false = a plain dash)
    dash = "wolf_spider",

    -- PASSIVES, LOOKS, MOVEMENT, MUSIC (no code needed; every option in docs/CUSTOM_BUGS.md)
    passives = { thorns = { damage = 8 } },     -- camo, regen, aura, thorns, venom, shell, spawn...
    effects = { glow = { color = "#80ff70", radius = 50 } },   -- glow, trail, sparkle, shimmer
    -- movement = { slide = 0.4, hover = 8, sprint = { after = 1, speed = 1.4 } },
    -- music = "chug",                         -- creep, chug, bubble, rattle, flute, kalimba

    -- Borrow a built-in bug's item rule (dung_beetle, hermit_crab, orb_weaver, hissing_roach,
    -- scorpion ...). Skill tree: a built-in bug's id, a preset ("preset:tank", also brawler,
    -- speedster, ranged, control) or a whole tree of its own. Leave out for the preset that
    -- fits the playstyle.
    -- rules = "dung_beetle",
    skillTree = "rhino_beetle",
    -- immune = true,           -- no debuffs (slow, poison...) like the hissing roach

    -- Up to four item ids to start with (docs/CUSTOM_BUGS.md, or the Item Catalogue).
    startingItems = {},
    -- Extra tags (beetle, arachnid, crustacean, myriapod, flyer, heavy ...) for item synergies.
    tags = { "beetle" },
}

-- ===========================================================================================
--  A BRAND-NEW BUG: own art and moves written in code
--
--  Instead of `look`, give it art (pixel rows, facing right, letters = palette colours):
--      art = {
--          palette = { o = "#1c140ab0", a = "#4a3a1e", b = "#94784a" },
--          body = { ".oooo..", "oabbbo.", ".oooo.." },
--          legs = { { 4, -1, 8, -6, 12, -9 }, { 0, -1, 0, -7, -2, -11 } },  -- one side, mirrored
--          legColor = "#7a6438", height = 2, lift = 3,
--      },
--
--  And a move as code (type = "scripted"); `me` is the move toolkit:
--      attack = { type = "scripted", name = "Stick Whip", cooldown = 0.5, range = 50,
--          fire = function(me) me.hitArc({ radius = 50, arc = 1.6, damage = 8 }) end },
--      dash = { type = "scripted", name = "Vault", start = function(me) me.lunge(80) end },
--
--  More that a script can hold (all in docs/CUSTOM_BUGS.md):
--      art.limbs = { ... }        claws, tails, stingers, feelers drawn in 3D
--      art.chain = { ... }        a segmented body (head + trailing segments)
--      anims = { attack = { time = 0.3, keys = { { 0 }, { 0.3, lunge = 4 }, { 1 } } } }
--      sounds = { zap = { wave = "square", freq = 600, to = 200, duration = 0.15 } }
--      hooks = { onKill = function(me, ev) ... end, onHurt = ..., onTick = ... }
--      skillTree = { branches = { { name = "...", nodes = { ... } } } }   its own tree
--      attack = { release = function(me, charge) ... end }   hold to charge
--      dash = { mode = true, enter = ..., tick = ..., exit = ... }    a stamina mode
--      me.hit({ shape = "box", length = 70, width = 30, windup = 0.25, damage = 30,
--          hitstop = 0.06, shake = 0.2, sweet = { from = 0.7, mult = 1.5 } })   hitbox + feel
--      attack = { blocks = { { "lunge", distance = 40 }, { "arc", radius = 50, damage = 10 } } }
--      attack = { combo = { window = 0.7, { ...blocks }, { ...blocks }, function(me) end } }
--      forms = { { name, attack, stats, look, art } }      hold Shift: form 2
--      molt = { wave = 10, name, stats, art, scale }       changes for good mid-run
--      pets = { { preset = "mite", count = 2 } }           mite, guard, moth, spitter
--      statuses = { burn = { preset = "burn", onHit = 0.25 } }   burn, frost, toxic, daze, charm, weaken
--      ultimate = { name, color, blocks = { ... }, buff = { stats = { ... }, time = 6 } }
--      hitFx = { number = "#80ff80", sparks = { color = "#80ff80", count = 3 } }
--      soundPack = { attack = "swing", hurt = "zap", death = "boom" }
--      poses = { idle = ..., death = ..., victory = ... }
--      card = { motto = "...", color = "#ffd070", frame = "gold" }
--      challenges = { { goal = "nohit" }, { goal = "kills", n = 2000 } }
--      art.wings = { size = 5, flap = 30 }, art.antennae = { length = 5 }
--
--  Worked examples (Bug Creator > Examples):
--      content/characters/_example_stick_insect.lua   own art + three moves in code
--      content/characters/_example_velvet_worm.lua    everything else
--      content/bugtemplates/*.lua                     ten more (Bug Creator > Template Gallery)
-- ===========================================================================================

-- ===========================================================================================
--  MORE IDEAS
--
--  Start from a built-in bug and tweak it:
--      local b = bug("tarantula")
--      b.name = "Glass Tarantula"
--      b.stats.maxHp = 30
--      b.stats.damage = 40
--      b.colors = { hue = 200, saturation = 0.3, brightness = 1.4 }
--      return b
--
--  Code is fine too, as long as it ends with a table:
--      local moves = { "mantis", "scorpion", "crab" }
--      return { name = "Lucky Bug", look = "crab", attack = moves[math.random(#moves)] }
-- ===========================================================================================
