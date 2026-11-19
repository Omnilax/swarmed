-- Item tags (the `tags` list in content/items). Item choice cards and the bag show them as
-- little chips; a chip lights up when items already in your bag share the tag (a synergy hint).
-- A tag that isn't listed here still works: it gets its own name and a grey chip.
--
-- `set`: a tag set bonus. Three items with the tag, all touching in the bag (one connected
-- group), give `stats` / `statsMult`; five or more give them twice (thresholds in
-- src/config/molting.lua). The bag draws the group's seams in the tag's colour.
return {
    offense = { label = "Offense", color = "#ff7a5c", set = { name = "Warpath", stats = { damage = 8 } } },
    defense = { label = "Defense", color = "#8fb4d8", set = { name = "Bulwark", stats = { armor = 5 } } },
    healing = { label = "Healing", color = "#7fe08a", set = { name = "Mending", stats = { hpRegen = 0.8 } } },
    utility = { label = "Utility", color = "#d9c98a", set = { name = "Toolkit", stats = { area = 10 } } },
    mobility = { label = "Mobility", color = "#7fe0d8", set = { name = "Tailwind", stats = { moveSpeed = 10, dodge = 2 } } },
    proc = { label = "Proc", color = "#e7a3ff", set = { name = "Chain Reaction", stats = { luck = 10 } } },
    poison = { label = "Poison", color = "#a6e04f", set = { name = "Venom Gland", stats = { damage = 5, critChance = 2 } } },
    fire = { label = "Fire", color = "#ff9a3a", set = { name = "Wildfire", stats = { damage = 4, area = 6 } } },
    explosive = { label = "Explosive", color = "#ffc35a", set = { name = "Powder Keg", stats = { area = 8, knockback = 10 } } },
    lightning = { label = "Lightning", color = "#9fd0ff", set = { name = "Live Wire", stats = { critChance = 5 } } },
    plant = { label = "Plant", color = "#6fc35a", set = { name = "Overgrowth", stats = { maxHp = 12 } } },
    microbe = { label = "Microbe", color = "#c3e07f", set = { name = "Colony", stats = { hpRegen = 0.5, maxHp = 6 } } },
    fungus = { label = "Fungus", color = "#d8a77f", set = { name = "Fairy Ring", stats = { area = 6, maxHp = 8 } } },
    bug = { label = "Bug", color = "#e0b46f", set = { name = "Exoskeleton", stats = { attackSpeed = 8 } } },
    orbital = { label = "Orbital", color = "#b8a6ff", set = { name = "Swarm Cloud", stats = { attackSpeed = 5, area = 5 } } },
    -- beach finds (src/game/shore.lua): more common on the beach and for crustaceans
    shore = { label = "Shore", color = "#f2c98a", set = { name = "Tide Pool", stats = { armor = 3, hpRegen = 0.5 } } },
    cursed = { label = "Cursed", color = "#c071ff" },   -- no set bonus: curses are their own reward
}
