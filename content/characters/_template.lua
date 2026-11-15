-- TEMPLATE. Copy to content/characters/my_bug.lua to add a playable arthropod.
return {
    name = "My Bug",
    description = "",
    sprite = "rhino_beetle",        -- id from content/sprites (flat top-down, used for icons)
    -- Optional 3D look in game: isometric legs + body parts (sprites with iso = true), body
    -- stacked `height` px thick and raised `lift` px. tools/make_bug_sprites.py makes these.
    model = { legs = "rhino_beetle_legs", body = "rhino_beetle_body", height = 5, lift = 2 },
    order = 99,                     -- position in character select
    playstyle = "brawler",          -- tank | brawler | speedster | ranged | control (src/config/playstyles.lua)
    -- Shown once, the first time the bug is played. {dash} / {secondary} / {attack} become the
    -- key, mouse button or controller button the player uses.
    tip = "",
    radius = 6,
    -- Overrides of base stats (see src/config/stats.lua for every stat and its default).
    stats = { maxHp = 50, moveSpeed = 100 },
    -- type = id from content/attacks; the other fields are that attack's params.
    attack = { type = "arc", damage = 8, cooldown = 0.8, radius = 40, arc = 2.4, knockback = 100 },
    -- Right click: a special with its own cooldown, aimed where you point (any attack type).
    secondary = { type = "pierce", damage = 25, cooldown = 2.5, range = 90 },
    -- Shift: the kind of dash (content/dashes) and its params.
    dash = { type = "dash", distance = 67 },
    startingItems = {},             -- item ids
    tags = {},
}
