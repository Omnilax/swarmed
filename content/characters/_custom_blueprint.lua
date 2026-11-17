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
--    * Only data comes out: functions in the table you return are ignored, and numbers are
--      kept in sane ranges (the Creator tells you what it changed).
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
    scale = 1.1,                -- drawn size, 0.7 (tiny) .. 1.6 (huge). The hitbox follows.
    -- radius = 8,              -- hitbox in pixels (4 .. 16) if you want to set it yourself
    -- Recolour, like a skin: hue turns colours round the wheel (degrees), saturation and
    -- brightness multiply, tint ("#rrggbb") is laid over the top.
    colors = { hue = 140, saturation = 1.2 },
    -- tank | brawler | speedster | ranged | control  (bug select sorting and filters)
    playstyle = "brawler",

    -- STATS: set any of these (they replace the defaults; leave one out for the default).
    --   maxHp 10..250 (50)        hpRegen 0..5 (0)          armor -5..15 (0)
    --   dodge 0..40 % (0)         moveSpeed 40..240 (100)   damage -50..60 % (0)
    --   attackSpeed -50..60 % (0) area -50..60 % (0)        knockback -50..120 % (0)
    --   critChance 0..40 % (5)    critDamage 100..300 % (150) luck -50..60 % (0)
    --   lifesteal 0..10 % (0)     pickupRange 10..150 (40)  dashCooldown 0.3..5 s (1.2)
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

    -- Borrow a built-in bug's item rule (dung_beetle, hermit_crab, orb_weaver, hissing_roach,
    -- scorpion ...) and skill tree (any built-in bug id). Leave out for none.
    -- rules = "dung_beetle",
    skillTree = "rhino_beetle",
    -- immune = true,           -- no debuffs (slow, poison...) like the hissing roach

    -- Up to four item ids to start with (docs/CUSTOM_BUGS.md, or the Item Catalogue).
    startingItems = {},
    -- Extra tags (beetle, arachnid, crustacean, myriapod, flyer, heavy ...) for item synergies.
    tags = { "beetle" },
}

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
